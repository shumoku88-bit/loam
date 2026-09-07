import Loam.Tui.Attention

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def due : Attention String :=
  { id := ⟨"attention-due"⟩
    context := "renew document"
    due := .dueOn "2026-09-10" }

private def noDue : Attention String :=
  { id := ⟨"attention-no-due"⟩
    context := "watch refund"
    due := .noDueDate }

private def unknownDue : Attention String :=
  { id := ⟨"attention-unknown"⟩
    context := "clarify timing"
    due := .dueUndetermined }

def main : IO Unit := do
  let unavailable := Loam.Tui.Attention.initial .unavailable
  let unavailableText := widgetText (Loam.Tui.Attention.view unavailable)
  expect (contains "Attention / Unavailable" unavailableText)
    "unavailable Attention source lost its distinct surface"
  expect (contains "not a claim that there are zero open matters" unavailableText)
    "unavailable Attention source collapsed into an empty claim"

  match Loam.Tui.Attention.update unavailable true with
  | .back => pure ()
  | _ => throw (IO.userError "Attention back action did not return Home intent")
  match Loam.Tui.Attention.update unavailable false with
  | .stay _ => pure ()
  | _ => throw (IO.userError "ordinary Attention input escaped the read-only surface")

  let explicitEmpty := Loam.Tui.Attention.initial
    (.available { openItems := [] })
  let emptyText := widgetText (Loam.Tui.Attention.view explicitEmpty)
  expect (contains "Attention / Open" emptyText) "explicit empty Attention source lost open heading"
  expect (contains "0 open" emptyText) "explicit empty Attention source did not show zero open"
  expect (!contains "Attention / Unavailable" emptyText)
    "explicit empty Attention source collapsed into unavailable"

  let openState := Loam.Tui.Attention.initial
    (.available { openItems := [due, noDue, unknownDue] })
  let openText := widgetText (Loam.Tui.Attention.view openState)
  expect (contains "3 open" openText) "open Attention count was not rendered"
  expect (contains "due 2026-09-10" openText) "due-on Attention meaning was not rendered"
  expect (contains "no due date" openText) "no-due Attention meaning was not rendered"
  expect (contains "due unknown" openText) "unknown-due Attention meaning was not rendered"
  expect (contains "representation order, not priority or due ordering" openText)
    "Attention surface accidentally omitted its ordering non-claim"
  expect (contains "Read-only" openText) "Attention surface lost its read-only boundary"

  IO.println "TUI Attention: unavailable/empty distinction, due meanings and read-only navigation passed."
