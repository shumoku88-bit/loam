import Loam.Tui.Capacity

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def moveNextN : Nat → Loam.Tui.Capacity.State → Loam.Tui.Capacity.State
  | 0, state => state
  | count + 1, state => moveNextN count (Loam.Tui.Capacity.moveNext state)

private def purposeRow (index : Nat) : Loam.CapacityReview.Row :=
  { purpose := ⟨"purpose-" ++ toString index⟩
    entitlement := Quantity.ofQuanta (Int.ofNat index) }

def main : IO Unit := do
  let empty := Loam.Tui.Capacity.initial { rows := [] }
  let emptyText := widgetText (Loam.Tui.Capacity.view empty)
  expect (contains "Capacity / Current" emptyText) "Capacity heading was not rendered"
  expect (contains "0 remembered purposes" emptyText) "empty Capacity count was not rendered"
  expect (contains "no cycle or time window is inferred" emptyText)
    "empty Capacity surface lost its no-window boundary"
  expect (contains "t transfer" emptyText)
    "empty Capacity surface did not expose the first transfer entrance"
  expect (contains "not money available to allocate" emptyText)
    "empty Capacity surface lost its unallocated-boundary warning"

  match Loam.Tui.Capacity.update empty .back with
  | .back => pure ()
  | _ => throw (IO.userError "Capacity back action did not return Home intent")
  match Loam.Tui.Capacity.update empty .other with
  | .stay _ => pure ()
  | _ => throw (IO.userError "ordinary Capacity input escaped the workspace")
  match Loam.Tui.Capacity.update empty .transfer with
  | .transfer _ => pure ()
  | _ => throw (IO.userError "empty Capacity workspace did not emit transfer intent")

  let food : Loam.CapacityReview.Row :=
    { purpose := ⟨"food"⟩, entitlement := Quantity.ofQuanta 60 }
  let groceries : Loam.CapacityReview.Row :=
    { purpose := ⟨"groceries"⟩, entitlement := Quantity.ofQuanta 40 }
  let state := Loam.Tui.Capacity.initial { rows := [food, groceries] }
  let text := widgetText (Loam.Tui.Capacity.view state)
  expect (contains "2 remembered purpose(s)" text) "Capacity purpose count was not rendered"
  expect (contains "food: 60 jpy" text) "food entitlement was not rendered"
  expect (contains "groceries: 40 jpy" text) "groceries entitlement was not rendered"
  expect (contains "all retained JPY Capacity movements" text)
    "Capacity surface lost its all-retained projection statement"
  expect (contains "not priority" text) "Capacity surface omitted its ordering non-claim"
  expect (contains "No cycle, period, or selected-day meaning" text)
    "Capacity surface accidentally implied temporal policy"
  expect (contains "shared CapacityPublisher owns publication" text)
    "Capacity surface did not identify the shared publication boundary"
  expect (Loam.Tui.Capacity.selectedPurpose? state == some ⟨"food"⟩)
    "Capacity did not expose the selected purpose as local transfer seed"

  let refreshed := Loam.Tui.Capacity.refreshed
    { rows := [food, groceries, { purpose := ⟨"buffer"⟩, entitlement := 0 }] }
    (Loam.Tui.Capacity.moveNext state)
  expect (Loam.Tui.Capacity.selectedPurpose? refreshed == some ⟨"groceries"⟩)
    "fresh Capacity review did not preserve the local selected row coordinate"

  let many := Loam.Tui.Capacity.initial { rows := (List.range 14).map purposeRow }
  match many.selected with
  | none => throw (IO.userError "non-empty Capacity snapshot had no selection")
  | some selected => expect (selected.val == 0) "Capacity did not select the first purpose"

  let shifted := moveNextN 12 many
  match shifted.selected with
  | none => throw (IO.userError "Capacity selection disappeared after row 12")
  | some selected =>
      expect (selected.val == 12)
        "Capacity selection could not reach the thirteenth remembered purpose"
  expect (Loam.Tui.Capacity.windowStart shifted == 1)
    "Capacity local window did not follow the thirteenth selected purpose"
  let visible := Loam.Tui.Capacity.visibleRows shifted
  expect (visible.length == 12)
    "Capacity local window did not retain twelve visible rows"
  expect (visible.any fun row => row.1 == 12)
    "Capacity local window omitted the selected thirteenth purpose"
  let shiftedText := widgetText (Loam.Tui.Capacity.view shifted)
  expect (contains "purpose-12: 12 jpy" shiftedText)
    "Capacity view did not render the reachable thirteenth purpose"
  expect (!contains "purpose-0: 0 jpy" shiftedText)
    "Capacity local window remained pinned to the first twelve purposes"

  let atEnd := moveNextN 13 many
  let beyond := Loam.Tui.Capacity.moveNext atEnd
  match beyond.selected with
  | none => throw (IO.userError "Capacity selection disappeared at the final row")
  | some selected =>
      expect (selected.val == 13)
        "Capacity moved beyond the final remembered purpose"
  expect (contains "No next Capacity row" beyond.notice)
    "Capacity final-row boundary did not fail safely"

  IO.println "TUI Capacity: navigation, transfer intent, fresh selection, all-retained projection and no-window boundary passed."
