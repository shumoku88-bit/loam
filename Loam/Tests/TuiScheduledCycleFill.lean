import Loam.ScheduledCreationPublisher
import Loam.Tui.ScheduledCycleFill

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

  IO.println "TUI Scheduled cycle fill: cadence choice and final explicit review passed."
