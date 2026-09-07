import Loam.Tui.Reports

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1


def main : IO Unit := do
  let initial := Loam.Tui.Reports.initial
  let initialText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Reports / Budget Window" initialText) "Reports heading was not rendered"
  expect (contains "Start: _" initialText) "Reports start was not explicitly blank"
  expect (contains "End (exclusive): _" initialText) "Reports end was not explicitly blank"
  expect (contains "no cycle, month, or selected day is inferred" initialText)
    "Reports surface accidentally implied an automatic window policy"

  let explicit : Loam.Tui.Reports.State := {
    form := {
      start := "2026-08-17"
      endExclusive := "2026-10-15"
      focus := ⟨2, by decide⟩
    }
  }
  let runStep := Loam.Tui.Reports.update explicit .enter
  match runStep.query with
  | none => throw (IO.userError "Run did not emit an explicit window query")
  | some query =>
      expect (query.start == "2026-08-17") "Run changed explicit start"
      expect (query.endExclusive == "2026-10-15") "Run changed explicit end"

  let food : Loam.BudgetWindowReview.Row := {
    purpose := ⟨"food"⟩
    entitlement := Quantity.ofQuanta 100
    consumption := Quantity.ofQuanta 30
    remaining := Quantity.ofQuanta 70
  }
  let report := Loam.Tui.Reports.withSnapshot explicit {
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    rows := [food]
  }
  let text := widgetText (Loam.Tui.Reports.view report)
  expect (contains "Budget window [2026-08-17, 2026-10-15)" text)
    "explicit window was not rendered"
  expect (contains "food: entitlement 100 | consumption 30 | remaining 70 jpy" text)
    "Budget Window components were not rendered"
  expect (contains "Remaining is derived exactly" text)
    "Reports surface lost the derived Remaining boundary"

  match Loam.Tui.Reports.update report .escape with
  | { back := true, .. } => pure ()
  | _ => throw (IO.userError "Reports escape did not return Home intent")

  IO.println "TUI Reports: explicit window intent, derived Remaining and no-cycle boundary passed."
