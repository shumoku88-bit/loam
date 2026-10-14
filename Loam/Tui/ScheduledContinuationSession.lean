import Loam.HouseholdCommand
import Loam.Presentation.LocusCatalog
import Loam.Review.ScheduledReview
import Loam.Tui.Kernel
import Loam.Tui.Layout
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
  | defer
  | add
  | done
  deriving Repr, DecidableEq, BEq

structure PromptState where
  candidate : Option Loam.ScheduledReview.Record := none
  additionalCount : Nat := 0
  mode : PromptMode := .choice
  choice : Nat := 0
  reviewRow : Nat := 0

structure PromptStep where
  state : PromptState
  action : Option PromptAction := none

def initialPrompt (candidates : List Loam.ScheduledReview.Record) : PromptState :=
  match candidates with
  | [] => {}
  | first :: rest => { candidate := some first, additionalCount := rest.length }

private def optionCount (_state : PromptState) : Nat :=
  3

private def moveChoice (state : PromptState) (back : Bool) : PromptState :=
  let count := optionCount state
  let next :=
    if back then (state.choice + count - 1) % count
    else (state.choice + 1) % count
  { state with choice := next }

/-- The full existing evidence remains navigable rather than truncated in the review.
    Width controls physical wrapping; it never changes the retained Scheduled record. -/
private def reviewLines (bounds : Bounds)
    (candidate : Loam.ScheduledReview.Record) : List String :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds 2 - 2
  let innerWidth := if width >= 24 && bodyCapacity >= 5 then width - 2 else width
  let content := [
      "Identity: " ++ candidate.id.token,
      "Due: " ++ candidate.scheduledOn,
      "Summary: " ++ Loam.ScheduledReview.summary candidate
    ] ++
    (candidate.movement.changes.map fun change =>
      "  " ++ change.coordinate.token ++ "  " ++
        toString change.quantity.quanta ++ " " ++ candidate.measure.token) ++
    ["This is an explicit existing Scheduled occurrence, not a same-series claim."]
  content.flatMap (Loam.Tui.Layout.wrapColumns innerWidth)

/-- Key handling is pure but bound-aware so long reviews never accumulate an
    unreachable scroll index when the terminal is resized. -/
def updatePrompt (bounds : Bounds) (state : PromptState)
    (key : Loam.Tui.Terminal.Key) : PromptStep :=

  match state.mode with
  | .review =>
      let count := match state.candidate with
        | some candidate => (reviewLines bounds candidate).length
        | none => 0
      let visible := Loam.Tui.Layout.footerBodyCapacity bounds 2 - 2
      let current := min state.reviewRow (count - 1)
      match key with
      | .escape =>
          { state := { state with mode := .choice, reviewRow := 0 } }
      | .up | .input 'k' =>
          { state := { state with reviewRow := current - 1 } }
      | .down | .input 'j' =>
          { state := { state with reviewRow := min (count - 1) (current + 1) } }
      | .pageUp =>
          { state := { state with reviewRow := current - visible } }
      | .pageDown =>
          { state := { state with reviewRow := min (count - 1) (current + visible) } }
      | .home =>
          { state := { state with reviewRow := 0 } }
      | .«end» =>
          { state := { state with reviewRow := count - 1 } }
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
              match state.choice % 3 with
              | 0 => { state, action := some .done }
              | 1 => { state, action := some .defer }
              | _ => { state, action := some .add }
      | _ => { state }

private def clipped (bounds : Bounds) (message : String)
    (style : Style := .normal) : Widget :=
  .row [span (Loam.Tui.Layout.ellipsize
    (Loam.Tui.Layout.contentWidth bounds) message) style]

private def footer (bounds : Bounds) (help : String) : List Widget :=
  [clipped bounds "" .muted, clipped bounds help .muted]

private def finish (bounds : Bounds) (body bottom : List Widget) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  .column <| Loam.Tui.Layout.fitWithFooter bounds
    (body.map (Loam.Tui.Layout.clipWidgetRow width))
    (bottom.map (Loam.Tui.Layout.clipWidgetRow width))

/-- Preserve all explicit decisions at 32×9; a frame is only added if it fits
    around all three actions. Review data is never confused with those actions. -/
private def actionRows (bounds : Bounds) (selected : Nat) (labels : List String)
    (available : Nat) : List Widget :=
  let rows := labels.zipIdx.map fun (label, index) =>
    .row [span ((if selected % labels.length == index then "> " else "  ") ++ label)
      (if selected % labels.length == index then .selected else .normal)]
  let width := Loam.Tui.Layout.contentWidth bounds
  if width >= 24 && available >= rows.length + 2 then
    Loam.Tui.Layout.widgetRows <|
      Loam.Tui.Layout.framedPanel width (rows.length + 2) "Choose next step"
        (.column rows) true
  else rows

private def candidateChoiceView (bounds : Bounds)
    (state : PromptState) (candidate : Loam.ScheduledReview.Record) : Widget :=
  let foot := footer bounds
    (if bounds.width < 50 then "Up/Dn choose  Enter  Esc keep"
     else "Tab/Arrows choose  Enter confirm  Esc keep as is")
  let head := [
    clipped bounds "Scheduled / Completion / Existing Plan",
    clipped bounds ("Later: " ++ candidate.id.token),
    clipped bounds ("Due: " ++ candidate.scheduledOn)]
  let extra :=
    (if bounds.height >= 14 then
      [clipped bounds ("Expected: " ++ Loam.ScheduledReview.summary candidate)] else []) ++
    (if bounds.height >= 18 then
      [clipped bounds ("Also found " ++ toString state.additionalCount ++
          " more similar later Scheduled occurrence(s).") .muted,
       clipped bounds "Match basis: same positive Locus set and a later explicit date." .muted,
       clipped bounds "LOAM does not claim this is the same series or contract." .muted,
       clipped bounds "Only Add another creates a new explicit Scheduled." .muted]
     else [])
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length -
    head.length - extra.length
  let actions := actionRows bounds state.choice
    ["Keep as is", "Add another", "Review"] available
  finish bounds (head ++ extra ++ actions) foot

private def noCandidateView (bounds : Bounds) (state : PromptState) : Widget :=
  let foot := footer bounds
    (if bounds.width < 50 then "Up/Dn choose  Enter  Esc done"
     else "Tab/Arrows choose  Enter confirm  Esc done")
  let head := [
    clipped bounds "Scheduled / Completion / Next Plan",
    clipped bounds "No similar later current-open Scheduled was found.",
    clipped bounds "Nothing will be inferred or created automatically."]
  let extra := if bounds.height >= 14 then
    [clipped bounds "Defer keeps an unfinished intent in Attention." .muted]
    else []
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length -
    head.length - extra.length
  let actions := actionRows bounds state.choice ["Done", "Defer", "Add next"] available
  finish bounds (head ++ extra ++ actions) foot

private def candidateReviewView (bounds : Bounds) (state : PromptState)
    (candidate : Loam.ScheduledReview.Record) : Widget :=
  let lines := reviewLines bounds candidate
  let selected := min state.reviewRow (lines.length - 1)
  let foot := footer bounds
    (if bounds.width < 50 then "j/k scroll  Home/End  Esc back"
     else "j/k or Up/Down scroll  Home/End  Esc back")
  let head := [clipped bounds "Scheduled / Completion / Existing Plan / Review",
    clipped bounds "Expected effects:"]
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length - head.length
  let width := Loam.Tui.Layout.contentWidth bounds
  let framed := width >= 24 && available >= 5
  let capacity := if framed then available - 2 else available
  let rows := (Loam.Tui.Layout.centeredListWindow lines selected capacity).map
    fun (index, content) =>
      .row [span content (if index == selected then .selected else .normal)]
  let body :=
    if framed then Loam.Tui.Layout.widgetRows <|
      Loam.Tui.Layout.framedPanel width (min available (rows.length + 2))
        "Retained Scheduled evidence" (.column rows) true
    else rows
  finish bounds (head ++ body) foot

def promptView (bounds : Bounds) (state : PromptState) : Widget :=
  match state.mode, state.candidate with
  | .review, some candidate => candidateReviewView bounds state candidate
  | .review, none => noCandidateView bounds { state with mode := .choice }
  | .choice, some candidate => candidateChoiceView bounds state candidate
  | .choice, none => noCandidateView bounds state

partial def runPrompt
    (bounds : Bounds) (state : PromptState) (frame : CompiledWidget) :
    IO PromptAction := do
  let key ← Loam.Tui.Terminal.readKey
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (promptView active state)
  let step := updatePrompt bounds state key
  match step.action with
  | some action => return action
  | none =>
      let nextFrame := compileWidget (promptView bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runPrompt bounds step.state nextFrame

/-- Human context retained when continuation is deliberately left undecided. -/
def deferredAttentionDraft
    (record : Loam.Tui.Main.ScheduledRecord) : Loam.AttentionPublisher.AddDraft :=
  {
    context :=
      "Decide continuation after " ++ record.id.token ++
      " (scheduled " ++ record.scheduledOn ++ "): " ++
      Loam.ScheduledReview.summary record
    due := .dueUndetermined
  }

/--
Persist explicit unfinished continuation intent through the existing Attention
authority. This creates no Scheduled occurrence, recurrence, cadence, or next
date.
-/
def publishDeferredContinuation
    (root : System.FilePath) (record : Loam.Tui.Main.ScheduledRecord) :
    IO (Except String Loam.Core.AttentionId) :=
  Loam.HouseholdCommand.addAttention root (deferredAttentionDraft record)

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
      let frame := compileWidget (Loam.Tui.ScheduledCreation.view bounds known editor)
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
Keeping it writes nothing. Deferring without a later candidate records one ordinary
Attention item with unknown due timing. Adding still uses the ordinary creation
publisher and routing inheritance.
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
          let active ← Loam.Tui.Terminal.currentBounds
          let frame := compileWidget (promptView active prompt)
          Loam.Tui.Terminal.redrawFromBlank active frame
          match ← runPrompt active prompt frame with
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
          | .defer =>
              match ← publishDeferredContinuation root record with
              | .ok attention =>
                  return completed ++
                    " Deferred continuation as " ++ attention.token ++
                    "; no additional Scheduled created."
              | .error message =>
                  return completed ++
                    " Deferred continuation could not be retained: " ++ message ++
                    " No additional Scheduled created."
          | .add =>
              let active ← Loam.Tui.Terminal.currentBounds
              let notice ← addNext active root known record effectiveOn loadCatalog
              return completed ++ " " ++ notice

end Loam.Tui.ScheduledContinuationSession
