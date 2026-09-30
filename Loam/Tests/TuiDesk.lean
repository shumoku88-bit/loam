import Loam.Core
import Loam.Desk.Model
import Loam.Desk.View

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def actualRecord?
    (id date description fromLocus toLocus : String) (quanta : Int) :
    Option Loam.Desk.Model.ReviewRecord := do
  let event ← Event.ofEffects? ⟨id⟩
    [ Effect.ofQuantity ⟨id ++ "-from"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩
        (Quantity.ofQuanta (-quanta))
    , Effect.ofQuantity ⟨id ++ "-to"⟩ ⟨toLocus⟩ ⟨"jpy"⟩
        (Quantity.ofQuanta quanta)
    ]
  pure { event, date := some date, description, replacement := none }

private def snapshot : IO Loam.Desk.Model.Snapshot := do
  let old ← requireSome
    (actualRecord? "event-0" "2026-09-06" "coffee" "cash" "food" 140)
    "old Desk fixture was not admitted"
  let first ← requireSome
    (actualRecord? "event-1" "2026-09-07" "groceries" "paypay" "food" 680)
    "first Desk fixture was not admitted"
  let second ← requireSome
    (actualRecord? "event-2" "2026-09-07" "charge" "smbc" "paypay" 3000)
    "second Desk fixture was not admitted"
  let nextMonth ← requireSome
    (actualRecord? "event-3" "2026-10-01" "book" "paypay" "books" 2470)
    "next-month Desk fixture was not admitted"
  pure {
    today := "2026-09-07"
    records := [second, nextMonth, old, first]
  }

def main : IO Unit := do
  let snap ← snapshot
  let start := Loam.Desk.Model.initial snap "2026-09-07"
  expect (start.selectedRow == some 1)
    "Desk initial selection did not align to the first Actual on the focused date"
  expect ((Loam.Desk.Model.visibleRecords snap start).map (·.description) ==
      ["coffee", "groceries", "charge"])
    "Desk monthly Actual rows were not chronological"

  let next := (Loam.Desk.Model.update snap start .nextRow).state
  let selected ← requireSome (Loam.Desk.Model.selectedRecord? snap next)
    "Desk next-row selection disappeared"
  expect (selected.description == "charge" && next.focusDate == "2026-09-07")
    "Desk next-row navigation did not preserve selected-row date context"

  let tomorrow := (Loam.Desk.Model.update snap next .nextDay).state
  expect (tomorrow.focusDate == "2026-09-08" && tomorrow.selectedRow.isNone)
    "Desk next-day navigation did not allow a date with no Actual"

  let back := (Loam.Desk.Model.update snap tomorrow .previousDay).state
  expect (back.focusDate == "2026-09-07" && back.selectedRow == some 1)
    "Desk previous-day navigation did not realign to the first Actual"

  let october := (Loam.Desk.Model.update snap back .nextMonth).state
  expect (october.focusDate == "2026-10-07" && october.selectedRow.isNone)
    "Desk month navigation did not preserve the day coordinate"

  let jumpStart := (Loam.Desk.Model.update snap october .beginJump).state
  let typed := "2026-10-01".toList.foldl
    (fun current char => (Loam.Desk.Model.update snap current (.jumpInput char)).state)
    jumpStart
  let jumped := (Loam.Desk.Model.update snap typed .acceptJump).state
  expect (jumped.focusDate == "2026-10-01" && jumped.selectedRow == some 0)
    "Desk jump-to-date did not select the matching October Actual"

  let evidence := (Loam.Desk.Model.update snap jumped .toggleEvidence).state
  expect evidence.showEvidence
    "Desk selected-row evidence toggle did not open"

  let wideText := widgetText
    (Loam.Desk.View.view { width := 110, height := 28 } snap back)
  expect (contains "LOAM Desk" wideText && contains "2026-09" wideText &&
      contains "groceries" wideText && contains "Mo Tu We Th Fr Sa Su" wideText)
    "Desk wide view lost the calendar, month or Actual ledger"

  let narrowText := widgetText
    (Loam.Desk.View.view { width := 64, height := 24 } snap back)
  expect (contains "Actual" narrowText && contains "groceries" narrowText)
    "Desk narrow view did not preserve the Actual ledger"

  IO.println "Desk TUI v0: monthly Actual desk navigation and responsive view checks passed."
