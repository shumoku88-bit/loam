import Loam.Tui.Capacity

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

def main : IO Unit := do
  let empty := Loam.Tui.Capacity.initial { rows := [] }
  let emptyText := widgetText (Loam.Tui.Capacity.view empty)
  expect (contains "Capacity / Current" emptyText) "Capacity heading was not rendered"
  expect (contains "0 remembered purposes" emptyText) "empty Capacity count was not rendered"
  expect (contains "no cycle or time window is inferred" emptyText)
    "empty Capacity surface lost its no-window boundary"

  match Loam.Tui.Capacity.update empty true with
  | .back => pure ()
  | _ => throw (IO.userError "Capacity back action did not return Home intent")
  match Loam.Tui.Capacity.update empty false with
  | .stay _ => pure ()
  | _ => throw (IO.userError "ordinary Capacity input escaped the read-only surface")

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
  expect (contains "Read-only" text) "Capacity surface lost its read-only boundary"

  IO.println "TUI Capacity: all-retained projection, no-window boundary and read-only navigation passed."
