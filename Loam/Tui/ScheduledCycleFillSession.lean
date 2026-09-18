import Loam.BoundaryPresetConfig
import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.ScheduledCycleFill
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
    (window : Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String)
    (drafts : List Loam.ScheduledCreationPublisher.Draft) : Bool :=
  drafts.all fun draft =>
    Loam.ScheduledCycleFill.validResolvedDate window observedAt draft.scheduledOn

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
        " explicit Scheduled occurrence(s) for the current cycle. No recurrence was retained."
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
  if step.cancel then return "Current-cycle Scheduled fill cancelled."
  if step.publish then
    match step.state.mode with
    | .preview _ drafts _ =>
        if !allDatesValid step.state.window step.state.observedAt drafts then
          pure <|
            "Current-cycle Scheduled fill not published: every edited due date must remain " ++
            "inside the current cycle and not precede the observation date."
        else
          publishDrafts root step.state.source step.state.observedAt drafts
    | .cadence _ =>
        pure "Current-cycle Scheduled fill reached an invalid preview state."
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
  if step.cancel then return "Current-cycle Scheduled fill cancelled."
  match step.cadence with
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCycleFill.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      chooseCadence bounds root known catalog step.state nextFrame
  | some cadence =>
      match Loam.ScheduledCycleFill.planCandidatesAfter
          state.window state.observedAt
          { anchor := state.source.scheduledOn, cadence := cadence } with
      | .error message => pure ("Current-cycle Scheduled fill unavailable: " ++ message)
      | .ok [] =>
          pure <|
            "No later " ++ cadence.label ++
            " occurrence falls inside the current cycle."
      | .ok candidates =>
          match ← collectDrafts bounds known catalog state.source candidates with
          | .error message => pure ("Current-cycle Scheduled fill unavailable: " ++ message)
          | .ok none => pure "Current-cycle Scheduled fill cancelled before publication."
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
  match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
  | .error message =>
      pure ("Current-cycle Scheduled fill unavailable: " ++ message)
  | .ok window =>
      let state := Loam.Tui.ScheduledCycleFill.initial source window observedAt
      let frame := compileWidget (Loam.Tui.ScheduledCycleFill.view state)
      Loam.Tui.Terminal.redrawFromBlank bounds frame
      chooseCadence bounds root known catalog state frame

end Loam.Tui.ScheduledCycleFillSession
