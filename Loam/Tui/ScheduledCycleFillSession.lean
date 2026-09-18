import Loam.BoundaryPresetConfig
import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.ScheduledCycleFill
import Loam.ScheduledReview
import Loam.Tui.Kernel
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.ScheduledCycleFill
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCycleFillSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-- Presentation suggestion adapter: only the exclusive date enters generation semantics. -/
private def fillLimitOfSuggestion
    (suggestion : Loam.BoundaryPresetConfig.HorizonSuggestion) :
    Loam.ScheduledCycleFill.FillLimit :=
  { endExclusive := suggestion.endExclusive }

private def candidateNotice : Loam.ScheduledCycleFill.Candidate → String
  | .dated date =>
      "Generated candidate " ++ date ++
      ". Edit the date or amount if the real obligation differs."
  | .needsDate year month nominalDay =>
      "Nominal day " ++ toString nominalDay ++ " does not exist in " ++
      toString year ++ "-" ++ toString month ++
      ". Enter the explicit real date you intend; LOAM will not choose it for you."

private def editorForCandidate
    (source : Loam.Tui.Main.ScheduledRecord)
    (catalog : Loam.LocusCatalog.Catalog)
    (candidate : Loam.ScheduledCycleFill.Candidate) :
    Except String Loam.Tui.ScheduledCreation.State := do
  let base ← Loam.Tui.ScheduledCreation.initialFromScheduled? source
  let date :=
    match candidate with
    | .dated suggested => suggested
    | .needsDate _ _ _ => ""
  pure <| Loam.Tui.ScheduledCreation.withCatalog
    { base with
      form := { base.form with date := date }
      notice := candidateNotice candidate }
    catalog

partial def collectDrafts
    (bounds : Bounds)
    (known : List String)
    (catalog : Loam.LocusCatalog.Catalog)
    (source : Loam.Tui.Main.ScheduledRecord)
    (candidates : List Loam.ScheduledCycleFill.Candidate)
    (acc : List Loam.ScheduledCreationPublisher.Draft := []) :
    IO (Except String (Option (List Loam.ScheduledCreationPublisher.Draft))) := do
  match candidates with
  | [] => return .ok (some acc)
  | candidate :: rest =>
      match editorForCandidate source catalog candidate with
      | .error message => return .error message
      | .ok editor =>
          let frame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
          Loam.Tui.Terminal.redrawFromBlank bounds frame
          match ← Loam.Tui.ScheduledCreationSession.collectDraft bounds known editor frame with
          | none => return .ok none
          | some draft => collectDrafts bounds known catalog source rest (acc ++ [draft])

private def allDatesValid
    (horizon : Loam.BoundaryPresetConfig.HorizonSuggestion)
    (observedAt : String)
    (drafts : List Loam.ScheduledCreationPublisher.Draft) : Bool :=
  drafts.all fun draft =>
    Loam.ScheduledCycleFill.validResolvedDate
      (fillLimitOfSuggestion horizon) observedAt draft.scheduledOn

inductive AwarenessMode where
  | choice
  | review
  deriving Repr, DecidableEq, BEq

inductive AwarenessAction where
  | keepExisting
  | addAnother
  deriving Repr, DecidableEq, BEq

structure AwarenessPromptState where
  draft : Loam.ScheduledCreationPublisher.Draft
  candidate : Loam.ScheduledReview.Record
  additionalCount : Nat := 0
  mode : AwarenessMode := .choice
  choice : Nat := 0

structure AwarenessPromptStep where
  state : AwarenessPromptState
  action : Option AwarenessAction := none

def initialAwarenessPrompt?
    (draft : Loam.ScheduledCreationPublisher.Draft)
    (candidates : List Loam.ScheduledReview.Record) : Option AwarenessPromptState :=
  match candidates with
  | [] => none
  | first :: rest =>
      some { draft, candidate := first, additionalCount := rest.length }

private def moveAwarenessChoice
    (state : AwarenessPromptState) (back : Bool) : AwarenessPromptState :=
  let next :=
    if back then (state.choice + 2) % 3
    else (state.choice + 1) % 3
  { state with choice := next }

def updateAwarenessPrompt
    (state : AwarenessPromptState)
    (key : Loam.Tui.Terminal.Key) : AwarenessPromptStep :=
  match state.mode with
  | .review =>
      match key with
      | .enter | .escape =>
          { state := { state with mode := .choice } }
      | _ => { state }
  | .choice =>
      match key with
      | .escape =>
          { state, action := some .keepExisting }
      | .tab | .right | .down =>
          { state := moveAwarenessChoice state false }
      | .shiftTab | .left | .up =>
          { state := moveAwarenessChoice state true }
      | .enter =>
          match state.choice % 3 with
          | 0 => { state, action := some .keepExisting }
          | 1 => { state, action := some .addAnother }
          | _ => { state := { state with mode := .review } }
      | _ => { state }

private def awarenessLine (text : String) : Widget := .row [span text]

private def awarenessOption (selected : Bool) (text : String) : Span :=
  span ("[" ++ text ++ "] ") (if selected then .selected else .normal)

private def awarenessChoiceView (state : AwarenessPromptState) : Widget :=
  .column <|
    [ awarenessLine "Scheduled / Fill Plans / Existing Plan"
    , awarenessLine ("Fill draft due: " ++ state.draft.scheduledOn)
    , awarenessLine ("Existing Scheduled: " ++ state.candidate.id.token)
    , awarenessLine ("Existing expected: " ++ Loam.ScheduledReview.summary state.candidate)
    ] ++
    (if state.additionalCount = 0 then [] else
      [awarenessLine ("Also found " ++ toString state.additionalCount ++
        " more current-open plan(s) with the same date and positive Locus set.")]) ++
    [ awarenessLine ""
    , awarenessLine "Match basis: same explicit date and same positive Locus set."
    , awarenessLine "LOAM does not claim this is the same series, contract, or obligation."
    , awarenessLine "Keep the existing plan, add another explicit Scheduled, or review it."
    , .row
        [ awarenessOption (state.choice % 3 = 0) "Keep existing"
        , awarenessOption (state.choice % 3 = 1) "Add another"
        , awarenessOption (state.choice % 3 = 2) "Review"
        ]
    , awarenessLine "Tab / arrows select   Enter confirm   Esc keep existing"
    ]

private def awarenessReviewView (state : AwarenessPromptState) : Widget :=
  .column <|
    [ awarenessLine "Scheduled / Fill Plans / Existing Plan / Review"
    , awarenessLine ("Identity: " ++ state.candidate.id.token)
    , awarenessLine ("Due: " ++ state.candidate.scheduledOn)
    , awarenessLine ("Summary: " ++ Loam.ScheduledReview.summary state.candidate)
    , awarenessLine "Expected effects:"
    ] ++
    (state.candidate.movement.changes.map fun change =>
      awarenessLine ("  " ++ change.coordinate.token ++ "  " ++
        toString change.quantity.quanta ++ " " ++ state.candidate.measure.token)) ++
    [ awarenessLine ""
    , awarenessLine "This is retained Scheduled evidence, not a same-series claim."
    , awarenessLine "Enter / Esc back"
    ]

def awarenessPromptView (state : AwarenessPromptState) : Widget :=
  match state.mode with
  | .choice => awarenessChoiceView state
  | .review => awarenessReviewView state

partial def runAwarenessPrompt
    (bounds : Bounds)
    (state : AwarenessPromptState)
    (frame : CompiledWidget) : IO AwarenessAction := do
  let step := updateAwarenessPrompt state (← Loam.Tui.Terminal.readKey)
  match step.action with
  | some action => return action
  | none =>
      let nextFrame := compileWidget (awarenessPromptView step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runAwarenessPrompt bounds step.state nextFrame

private partial def resolveDraftAwareness
    (bounds : Bounds)
    (snapshot : Loam.ScheduledReview.EvidenceSnapshot)
    (drafts : List Loam.ScheduledCreationPublisher.Draft)
    (acc : List Loam.ScheduledCreationPublisher.Draft := []) :
    IO (Except String (List Loam.ScheduledCreationPublisher.Draft)) := do
  match drafts with
  | [] => return .ok acc
  | draft :: rest =>
      match Loam.ScheduledReview.sameDateSimilarOpenRecords
          snapshot draft.scheduledOn draft.movement with
      | .error message => return .error message
      | .ok [] =>
          resolveDraftAwareness bounds snapshot rest (acc ++ [draft])
      | .ok candidates =>
          let some prompt := initialAwarenessPrompt? draft candidates
            | return .error "loam: Scheduled awareness candidates unexpectedly disappeared"
          let frame := compileWidget (awarenessPromptView prompt)
          Loam.Tui.Terminal.redrawFromBlank bounds frame
          match ← runAwarenessPrompt bounds prompt frame with
          | .keepExisting =>
              resolveDraftAwareness bounds snapshot rest acc
          | .addAnother =>
              resolveDraftAwareness bounds snapshot rest (acc ++ [draft])

private partial def publishDraftsFrom
    (root : System.FilePath)
    (source : Loam.Tui.Main.ScheduledRecord)
    (observedAt : String)
    (drafts : List Loam.ScheduledCreationPublisher.Draft)
    (createdCount : Nat) : IO String := do
  match drafts with
  | [] =>
      pure <|
        "Published " ++ toString createdCount ++
        " explicit Scheduled occurrence(s) through the selected horizon. No recurrence was retained."
  | draft :: rest =>
      match ← Loam.HouseholdCommand.createScheduled root draft with
      | .error message =>
          pure <|
            "Cycle fill stopped after " ++ toString createdCount ++
            " publication(s): " ++ message
      | .ok created =>
          let nextCount := createdCount + 1
          match ← Loam.HouseholdCommand.inheritScheduledRouting
              root source.id created observedAt with
          | .error message =>
              pure <|
                "Created " ++ created.token ++
                ", but routing inheritance failed; cycle fill stopped after " ++
                toString nextCount ++ " publication(s): " ++ message
          | .ok _ =>
              publishDraftsFrom root source observedAt rest nextCount

private def publishDrafts
    (root : System.FilePath)
    (source : Loam.Tui.Main.ScheduledRecord)
    (observedAt : String)
    (drafts : List Loam.ScheduledCreationPublisher.Draft) : IO String :=
  publishDraftsFrom root source observedAt drafts 0

partial def reviewAndPublish
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.ScheduledCycleFill.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCycleFill.update state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled plan fill cancelled."
  if step.publish then
    match step.state.mode with
    | .preview _ drafts _ =>
        if !allDatesValid step.state.horizon step.state.observedAt drafts then
          pure <|
            "Scheduled plan fill not published: every edited due date must remain " ++
            "inside the selected horizon and not precede the observation date."
        else
          match ← Loam.ScheduledReview.loadHouseholdEvidence root root with
          | .error message =>
              pure <|
                "Scheduled plan fill not published: existing Scheduled inspection " ++
                "is unavailable: " ++ message
          | .ok snapshot =>
              match ← resolveDraftAwareness bounds snapshot drafts with
              | .error message =>
                  pure <|
                    "Scheduled plan fill not published: existing Scheduled awareness " ++
                    "failed: " ++ message
              | .ok [] =>
                  pure <|
                    "No new Scheduled occurrences published; existing matching plan(s) were kept."
              | .ok approved =>
                  publishDrafts root step.state.source step.state.observedAt approved
    | .horizon _ | .cadence _ =>
        pure "Scheduled plan fill reached an invalid preview state."
  else
    let nextFrame := compileWidget (Loam.Tui.ScheduledCycleFill.view step.state)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    reviewAndPublish bounds root step.state nextFrame

partial def chooseCadence
    (bounds : Bounds)
    (root : System.FilePath)
    (known : List String)
    (catalog : Loam.LocusCatalog.Catalog)
    (state : Loam.Tui.ScheduledCycleFill.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCycleFill.update state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled plan fill cancelled."
  match step.cadence with
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCycleFill.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      chooseCadence bounds root known catalog step.state nextFrame
  | some cadence =>
      match Loam.ScheduledCycleFill.planCandidates
          (fillLimitOfSuggestion state.horizon) state.observedAt
          { anchor := state.source.scheduledOn, cadence := cadence } with
      | .error message => pure ("Scheduled plan fill unavailable: " ++ message)
      | .ok [] =>
          pure <|
            "No later " ++ cadence.label ++
            " occurrence falls before the selected horizon."
      | .ok candidates =>
          match ← collectDrafts bounds known catalog state.source candidates with
          | .error message => pure ("Scheduled plan fill unavailable: " ++ message)
          | .ok none => pure "Scheduled plan fill cancelled before publication."
          | .ok (some drafts) =>
              let preview := Loam.Tui.ScheduledCycleFill.withDrafts state cadence drafts
              let previewFrame := compileWidget (Loam.Tui.ScheduledCycleFill.view preview)
              Loam.Tui.Terminal.redrawFromBlank bounds previewFrame
              reviewAndPublish bounds root preview previewFrame

def run
    (bounds : Bounds)
    (dataDir root : System.FilePath)
    (known : List String)
    (catalog : Loam.LocusCatalog.Catalog)
    (source : Loam.Tui.Main.ScheduledRecord)
    (observedAt : String) : IO String := do
  match ← Loam.BoundaryPresetConfig.loadHorizonSuggestions dataDir observedAt with
  | .error message =>
      pure ("Scheduled plan fill unavailable: " ++ message)
  | .ok horizons =>
      let some state :=
          Loam.Tui.ScheduledCycleFill.initial? source horizons observedAt
        | return "Scheduled plan fill unavailable: no boundary horizon suggestion is configured."
      let frame := compileWidget (Loam.Tui.ScheduledCycleFill.view state)
      Loam.Tui.Terminal.redrawFromBlank bounds frame
      chooseCadence bounds root known catalog state frame

end Loam.Tui.ScheduledCycleFillSession
