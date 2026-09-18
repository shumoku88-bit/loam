import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.ScheduledReview
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledContinuationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled continuation session

This session starts only after one Scheduled completion has already been
published. It first reloads current-open Scheduled evidence and surfaces a later
plan with the same positive Locus set when one exists.

That match is presentation guidance only. It does not assert recurrence,
continuation provenance, contract identity, or series identity. The user chooses
whether to keep the existing plan, add another independent Scheduled occurrence,
or inspect the candidate.

Only the Add path opens the existing Scheduled creation editor and only a
successful creation reaches the existing routing-inheritance boundary.
-/

private def completedNotice (record : Loam.Tui.Main.ScheduledRecord) : String :=
  "Completed " ++ record.id.token ++ "."

private def routingNotice
    (root : System.FilePath) (record : Loam.Tui.Main.ScheduledRecord)
    (created : Loam.Core.ScheduledId) (effectiveOn : String) : IO String := do
  match ← Loam.HouseholdCommand.inheritScheduledRouting
      root record.id created effectiveOn with
  | .error err =>
      return s!" (routing inheritance failed: {err})"
  | .ok report =>
      let notices := report.formatOutcomes
      return if notices.isEmpty then "" else " (" ++ String.intercalate ", " notices ++ ")"

inductive PromptMode where
  | choice
  | review
  deriving Repr, DecidableEq, BEq

inductive PromptAction where
  | keep
  | add
  | done
  deriving Repr, DecidableEq, BEq

structure PromptState where
  candidate : Option Loam.ScheduledReview.Record
  additionalCount : Nat := 0
  mode : PromptMode := .choice
  choice : Nat := 0

structure PromptStep where
  state : PromptState
  action : Option PromptAction := none

def initialPrompt (candidates : List Loam.ScheduledReview.Record) : PromptState :=
  match candidates with
  | [] => {}
  | first :: rest => { candidate := some first, additionalCount := rest.length }

private def optionCount (state : PromptState) : Nat :=
  if state.candidate.isSome then 3 else 2

private def moveChoice (state : PromptState) (back : Bool) : PromptState :=
  let count := optionCount state
  let next :=
    if back then (state.choice + count - 1) % count
    else (state.choice + 1) % count
  { state with choice := next }

def updatePrompt (state : PromptState) (key : Loam.Tui.Terminal.Key) : PromptStep :=
  match state.mode with
  | .review =>
      match key with
      | .enter | .escape =>
          { state := { state with mode := .choice } }
      | _ => { state }
  | .choice =>
      match key with
      | .escape =>
          if state.candidate.isSome then { state, action := some .keep }
          else { state, action := some .done }
      | .tab | .right | .down =>
          { state := moveChoice state false }
      | .shiftTab | .left | .up =>
          { state := moveChoice state true }
      | .enter =>
          match state.candidate with
          | some _ =>
              match state.choice % 3 with
              | 0 => { state, action := some .keep }
              | 1 => { state, action := some .add }
              | _ => { state := { state with mode := .review } }
          | none =>
              if state.choice % 2 = 0 then { state, action := some .done }
              else { state, action := some .add }
      | _ => { state }

private def line (text : String) : Widget := .row [span text]

private def choiceSpan (selected : Bool) (text : String) : Span :=
  span ("[" ++ text ++ "] ") (if selected then .selected else .normal)

private def candidateChoiceView
    (state : PromptState) (candidate : Loam.ScheduledReview.Record) : Widget :=
  .column <|
    [ line "Scheduled / Completion / Existing Plan"
    , line ("Later Scheduled: " ++ candidate.id.token)
    , line ("Due: " ++ candidate.scheduledOn)
    , line ("Expected: " ++ Loam.ScheduledReview.summary candidate)
    ] ++
    (if state.additionalCount = 0 then [] else
      [line ("Also found " ++ toString state.additionalCount ++
        " more similar later Scheduled occurrence(s).")]) ++
    [ line ""
    , line "Match basis: same positive Locus set and a later explicit date."
    , line "LOAM does not claim this is the same series or contract."
    , line "Keep the existing plan, add another independent Scheduled, or review it."
    , .row
        [ choiceSpan (state.choice % 3 = 0) "Keep as is"
        , choiceSpan (state.choice % 3 = 1) "Add another"
        , choiceSpan (state.choice % 3 = 2) "Review"
        ]
    , line "Tab / arrows select   Enter confirm   Esc keep as is"
    ]

private def noCandidateView (state : PromptState) : Widget :=
  .column
    [ line "Scheduled / Completion / Next Plan"
    , line "No similar later current-open Scheduled was found."
    , line "Nothing will be inferred or created automatically."
    , .row
        [ choiceSpan (state.choice % 2 = 0) "Done"
        , choiceSpan (state.choice % 2 = 1) "Add next"
        ]
    , line "Tab / arrows select   Enter confirm   Esc done"
    ]

private def candidateReviewView (candidate : Loam.ScheduledReview.Record) : Widget :=
  .column <|
    [ line "Scheduled / Completion / Existing Plan / Review"
    , line ("Identity: " ++ candidate.id.token)
    , line ("Due: " ++ candidate.scheduledOn)
    , line ("Summary: " ++ Loam.ScheduledReview.summary candidate)
    , line "Expected effects:"
    ] ++
    (candidate.movement.changes.map fun change =>
      line ("  " ++ change.coordinate.token ++ "  " ++
        toString change.quantity.quanta ++ " " ++ candidate.measure.token)) ++
    [ line ""
    , line "This is an explicit existing Scheduled occurrence, not a same-series claim."
    , line "Enter / Esc back"
    ]

def promptView (state : PromptState) : Widget :=
  match state.mode, state.candidate with
  | .review, some candidate => candidateReviewView candidate
  | .review, none => noCandidateView { state with mode := .choice }
  | .choice, some candidate => candidateChoiceView state candidate
  | .choice, none => noCandidateView state

partial def runPrompt
    (bounds : Bounds) (state : PromptState) (frame : CompiledWidget) :
    IO PromptAction := do
  let step := updatePrompt state (← Loam.Tui.Terminal.readKey)
  match step.action with
  | some action => return action
  | none =>
      let nextFrame := compileWidget (promptView step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runPrompt bounds step.state nextFrame

private def addNext
    (bounds : Bounds) (root : System.FilePath)
    (known : List String) (record : Loam.Tui.Main.ScheduledRecord)
    (effectiveOn : String) (loadCatalog : IO Loam.LocusCatalog.Catalog) : IO String := do
  match Loam.Tui.ScheduledCreation.initialFromScheduled? record with
  | .error message =>
      return "Next Scheduled editor unavailable: " ++ message
  | .ok editor =>
      let catalog ← loadCatalog
      let editor := Loam.Tui.ScheduledCreation.withCatalog editor catalog
      let frame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
      Loam.Tui.Terminal.redrawFromBlank bounds frame
      let (created?, creationNotice) ← Loam.Tui.ScheduledCreationSession.runWithScheduledId
        bounds root known editor frame
      match created? with
      | none =>
          return "No additional Scheduled created."
      | some created =>
          let routeNotice ← routingNotice root record created effectiveOn
          return creationNotice ++ routeNotice

/--
Run post-completion awareness after completion has already published.

The canonical Scheduled image is reloaded before offering another creation. A
later same-positive-Locus occurrence is only a candidate for user awareness.
Keeping it writes nothing. Adding still uses the ordinary creation publisher and
routing inheritance.
-/
def runAfterCompletion
    (bounds : Bounds) (root : System.FilePath)
    (known : List String) (record : Loam.Tui.Main.ScheduledRecord)
    (effectiveOn : String) (loadCatalog : IO Loam.LocusCatalog.Catalog) : IO String := do
  let completed := completedNotice record
  match ← Loam.ScheduledReview.loadHouseholdEvidence root root with
  | .error message =>
      return completed ++
        " Later Scheduled inspection unavailable: " ++ message ++
        " No additional Scheduled created."
  | .ok snapshot =>
      match Loam.ScheduledReview.laterSimilarOpenRecords snapshot record with
      | .error message =>
          return completed ++
            " Later Scheduled inspection unavailable: " ++ message ++
            " No additional Scheduled created."
      | .ok candidates =>
          let prompt := initialPrompt candidates
          let frame := compileWidget (promptView prompt)
          Loam.Tui.Terminal.redrawFromBlank bounds frame
          match ← runPrompt bounds prompt frame with
          | .keep =>
              match candidates.head? with
              | some candidate =>
                  return completed ++ " Kept existing later Scheduled " ++
                    candidate.id.token ++ " for " ++ candidate.scheduledOn ++
                    "; no additional Scheduled created."
              | none =>
                  return completed ++ " No additional Scheduled created."
          | .done =>
              return completed ++ " No additional Scheduled created."
          | .add =>
              let notice ← addNext bounds root known record effectiveOn loadCatalog
              return completed ++ " " ++ notice

end Loam.Tui.ScheduledContinuationSession
