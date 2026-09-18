import Loam.ScheduledCreationPublisher
import Loam.ScheduledReview
import Loam.Tui.ScheduledCycleFill
import Loam.Tui.ScheduledCycleFillSession

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def source? : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-3000) }
    , { coordinate := ⟨"gpt-plus"⟩, quantity := Quantity.ofQuanta 3000 } ]
  pure {
    id := ⟨"scheduled-source"⟩
    scheduledOn := "2026-08-15"
    movement := movement
  }

def main : IO Unit := do
  let some source := source? | throw (IO.userError "cycle-fill source fixture")
  let window : Loam.BoundaryPresetConfig.CurrentWindow := {
    source := "Pension"
    start := "2026-08-14"
    endExclusive := "2026-12-15"
    hasFollowingBoundary := true
  }
  let state := Loam.Tui.ScheduledCycleFill.initial source window "2026-08-14"
  let text := widgetText (Loam.Tui.ScheduledCycleFill.view state)
  expect (contains "Monthly" text && contains "Every 2 months" text && contains "Yearly" text)
    "cycle-fill cadence choices were not visible"
  expect (contains "no recurrence authority is retained" text)
    "cycle-fill view did not explain construction-only cadence"

  let twoMonth := Loam.Tui.ScheduledCycleFill.update state .right
  let chosen := Loam.Tui.ScheduledCycleFill.update twoMonth.state .enter
  expect (decide (chosen.cadence = some .everyTwoMonths))
    "cycle-fill cadence selection did not preserve explicit input choice"

  let draft1 : Loam.ScheduledCreationPublisher.Draft := {
    scheduledOn := "2026-09-15"
    movement := source.movement
  }
  let draft2 : Loam.ScheduledCreationPublisher.Draft := {
    scheduledOn := "2026-10-16"
    movement := source.movement
  }
  let preview := Loam.Tui.ScheduledCycleFill.withDrafts state .monthly [draft1, draft2]
  let previewText := widgetText (Loam.Tui.ScheduledCycleFill.view preview)
  expect (contains "2026-09-15" previewText && contains "2026-10-16" previewText)
    "cycle-fill final review did not show individually edited dates"
  expect (contains "Cadence will not be stored" previewText)
    "cycle-fill final review implied retained recurrence"

  let publish := Loam.Tui.ScheduledCycleFill.update preview .enter
  expect publish.publish
    "cycle-fill final review did not emit publication intent"

  let some raisedMovement := BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-6000) }
      , { coordinate := ⟨"gpt-plus"⟩, quantity := Quantity.ofQuanta 6000 } ]
    | throw (IO.userError "cycle-fill awareness movement fixture")
  let existing : ScheduledOccurrence String := {
    id := ⟨"already-planned"⟩
    scheduledOn := draft2.scheduledOn
    movement := raisedMovement
  }
  let some scheduled := ScheduledMemory.ofOccurrences? [existing]
    | throw (IO.userError "cycle-fill awareness Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "cycle-fill awareness terminal memory")
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "cycle-fill awareness Event memory")
  let snapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events
  }

  let .ok overlaps :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot draft2.scheduledOn draft2.movement
    | throw (IO.userError "cycle-fill exact-date awareness refused")
  expect (overlaps.map (fun record => record.id.token) == ["already-planned"])
    "cycle-fill awareness did not surface same-date same-positive-Locus retained plan"
  let some overlap := overlaps.head?
    | throw (IO.userError "cycle-fill awareness overlap unexpectedly missing")
  expect (overlap.movement.changes.any fun change =>
      change.coordinate.token == "gpt-plus" && change.quantity.quanta == 6000)
    "cycle-fill awareness incorrectly required equal amounts"

  let .ok differentDate :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot "2026-11-16" draft2.movement
    | throw (IO.userError "cycle-fill different-date awareness refused")
  expect differentDate.isEmpty
    "cycle-fill awareness matched a retained plan on a different explicit date"

  let some wifiMovement := BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-3000) }
      , { coordinate := ⟨"wifi"⟩, quantity := Quantity.ofQuanta 3000 } ]
    | throw (IO.userError "cycle-fill different-Locus movement fixture")
  let .ok differentLocus :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot draft2.scheduledOn wifiMovement
    | throw (IO.userError "cycle-fill different-Locus awareness refused")
  expect differentLocus.isEmpty
    "cycle-fill awareness matched a retained plan with a different positive Locus set"

  let some awareness :=
      Loam.Tui.ScheduledCycleFillSession.initialAwarenessPrompt? draft2 overlaps
    | throw (IO.userError "cycle-fill awareness prompt missing")
  let awarenessText :=
    widgetText (Loam.Tui.ScheduledCycleFillSession.awarenessPromptView awareness)
  expect (contains "already-planned" awarenessText &&
      contains "Keep existing" awarenessText &&
      contains "Add another" awarenessText)
    "cycle-fill awareness prompt did not expose retained evidence and explicit choice"
  expect (contains "does not claim this is the same series, contract, or obligation" awarenessText)
    "cycle-fill awareness prompt overstated the advisory match"

  let keep :=
    Loam.Tui.ScheduledCycleFillSession.updateAwarenessPrompt awareness .enter
  expect (keep.action == some .keepExisting)
    "cycle-fill awareness did not default to keeping existing evidence"

  let addState :=
    (Loam.Tui.ScheduledCycleFillSession.updateAwarenessPrompt awareness .right).state
  let add :=
    Loam.Tui.ScheduledCycleFillSession.updateAwarenessPrompt addState .enter
  expect (add.action == some .addAnother)
    "cycle-fill awareness could not explicitly add another Scheduled"

  let reviewState :=
    (Loam.Tui.ScheduledCycleFillSession.updateAwarenessPrompt addState .right).state
  let review :=
    Loam.Tui.ScheduledCycleFillSession.updateAwarenessPrompt reviewState .enter
  expect (review.action.isNone && review.state.mode == .review)
    "cycle-fill awareness could not review retained Scheduled evidence"
  let reviewText :=
    widgetText (Loam.Tui.ScheduledCycleFillSession.awarenessPromptView review.state)
  expect (contains "Expected effects:" reviewText && contains "6000 jpy" reviewText)
    "cycle-fill awareness Review did not show retained movement evidence"

  IO.println "TUI Scheduled cycle fill: cadence, final review, and existing-plan awareness passed."
