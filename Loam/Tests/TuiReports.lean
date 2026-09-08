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
  let initial := Loam.Tui.Reports.initialForDate "2026-09-07"
  let initialText := widgetText (Loam.Tui.Reports.view initial)
  expect (contains "Reports / Budget Window" initialText) "Reports heading was not rendered"
  expect (contains "Start: 2026-09-01" initialText) "Reports did not seed the selected-day calendar month start"
  expect (contains "End (exclusive): 2026-10-01" initialText)
    "Reports did not seed the selected-day calendar month end"
  expect (contains "Calendar month is only a coordinate convenience" initialText)
    "Reports surface lost the calendar-coordinate non-claim"
  expect (initial.form.focus.val == 2) "calendar-month prefill did not focus Run"

  let previous := (Loam.Tui.Reports.update initial .left).state
  expect (previous.form.start == "2026-08-01") "left did not shift to previous calendar month"
  expect (previous.form.endExclusive == "2026-09-01")
    "left did not keep an explicit half-open calendar month"

  let next := (Loam.Tui.Reports.update initial .right).state
  expect (next.form.start == "2026-10-01") "right did not shift to next calendar month"
  expect (next.form.endExclusive == "2026-11-01")
    "right did not keep an explicit half-open calendar month"

  let december := Loam.Tui.Reports.initialForDate "2026-12-20"
  let january := (Loam.Tui.Reports.update december .right).state
  expect (january.form.start == "2027-01-01") "calendar month shift lost year rollover"
  expect (january.form.endExclusive == "2027-02-01") "calendar month year rollover end was wrong"

  let explicit : Loam.Tui.Reports.State := {
    form := {
      start := "2026-08-17"
      endExclusive := "2026-10-15"
      focus := ⟨2, by decide⟩
    }
    calendarAnchor := "2026-09-07"
  }
  let shiftedExplicit := (Loam.Tui.Reports.update explicit .right).state
  expect (shiftedExplicit.form.start == "2026-08-17")
    "arrow key rewrote a manually edited non-calendar window"
  expect (contains "press m to restore" shiftedExplicit.notice)
    "non-calendar arrow refusal did not explain the recovery action"

  let restored := (Loam.Tui.Reports.update explicit (.input 'm')).state
  expect (restored.form.start == "2026-09-01") "m did not restore selected-day calendar month start"
  expect (restored.form.endExclusive == "2026-10-01")
    "m did not restore selected-day calendar month end"
  expect (restored.form.focus.val == 2) "m did not return focus to Run"

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
    commitment := Quantity.ofQuanta 35
    headroom := Quantity.ofQuanta 35
  }
  let report := Loam.Tui.Reports.withSnapshot explicit {
    start := "2026-08-17"
    endExclusive := "2026-10-15"
    observedAt := "2026-09-08"
    rows := [food]
    scheduledFrontier := some {
      unmanaged := Quantity.ofQuanta 7
      unrouted := Quantity.ofQuanta 8
      unresolvedEligibility := Quantity.ofQuanta 9
    }
  }
  let text := widgetText (Loam.Tui.Reports.view report)
  expect (contains "Budget window [2026-08-17, 2026-10-15)" text)
    "explicit window was not rendered"
  expect (contains "Scheduled routing observed at 2026-09-08" text)
    "Reports did not render the distinct routing observation coordinate"
  expect (contains "food: entitlement 100 | consumption 30 | remaining 70 jpy" text)
    "Budget Window components were not rendered"
  expect (contains "commitment<end 35 | headroom 35 jpy" text)
    "managed Scheduled Commitment / Headroom were not rendered"
  expect (contains "Scheduled frontier jpy: unmanaged 7 | unrouted 8 | unresolved eligibility 9" text)
    "Scheduled non-managed frontier was not rendered once at snapshot level"
  expect (contains "Remaining = window Entitlement - window Consumption." text)
    "Reports surface lost the Remaining equation"
  expect (contains "Headroom = Remaining - managed current-open Scheduled pressure due before End." text)
    "Reports surface lost the Headroom equation"
  expect (contains "Start does not discard overdue current-open Scheduled pressure." text)
    "Reports surface lost the overdue-current-open boundary"

  let editing : Loam.Tui.Reports.State := {
    report with form := { report.form with focus := ⟨0, by decide⟩ }
  }
  let edited := (Loam.Tui.Reports.update editing (.input '9')).state
  expect edited.snapshot.isNone "editing coordinates left a stale report snapshot visible"

  match Loam.Tui.Reports.update report .escape with
  | { back := true, .. } => pure ()
  | _ => throw (IO.userError "Reports escape did not return Home intent")

  IO.println
    "TUI Reports: explicit window, observation date, Headroom and Scheduled frontier rendering passed."
