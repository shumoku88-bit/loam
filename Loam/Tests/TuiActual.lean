import Loam.Tui.Main
import Loam.Tui.ActualWorkspace

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def testRecord (index : Nat) : Loam.Tui.Main.ReviewRecord :=
  { event :=
      { id := ⟨"event-" ++ toString index⟩
        effects := []
        keyNodup := by simp }
    date := some "2026-09-07"
    description := "row-" ++ toString index
    replacement := none }

private def actualRecord?
    (id date description fromLocus toLocus : String) (quanta : Int) : Option Loam.Tui.Main.ReviewRecord := do
  let event ← Event.ofEffects? ⟨id⟩
    [ Effect.ofQuantity ⟨id ++ "-from"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-quanta))
    , Effect.ofQuantity ⟨id ++ "-to"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)
    ]
  pure { event, date := some date, description, replacement := none }

private def emptyScheduledSnapshot : IO Loam.ScheduledReview.EvidenceSnapshot := do
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? []) "empty Scheduled memory was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? []) "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? []) "empty Event memory was not admitted"
  pure { scheduled, terminals, events }

private def actualWorkspaceSnapshot : IO Loam.Tui.Main.Snapshot := do
  let first ← requireSome (actualRecord? "event-0" "2026-09-07" "alpha" "paypay" "food" 100)
    "first Actual workspace fixture was not admitted"
  let second ← requireSome (actualRecord? "event-1" "2026-09-07" "beta" "smbc" "paypay" 200)
    "second Actual workspace fixture was not admitted"
  let previous ← requireSome (actualRecord? "event-2" "2026-09-06" "gamma" "paypay" "books" 300)
    "previous-day Actual workspace fixture was not admitted"
  let scheduled ← emptyScheduledSnapshot
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := [previous, second, first]
  }
  pure { actual, scheduled := .ok scheduled }


def main : IO Unit := do
  let snapshot ← actualWorkspaceSnapshot
  let actualStart := Loam.Tui.ActualWorkspace.initial "2026-09-07"
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot actualStart).length == 2)
    "Actual workspace Focus Day did not use the shared selected-day Actual answer"
  let right := (Loam.Tui.ActualWorkspace.update snapshot actualStart .focusRight).state
  let second := (Loam.Tui.ActualWorkspace.update snapshot right .next).state
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot second with
  | none => throw (IO.userError "Actual workspace transaction selection disappeared")
  | some record =>
      expect (record.description == "beta")
        "Actual workspace j/down-style selection did not move to the second transaction"
  let hraText := widgetText (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot second)
  expect (contains "Household Actuals Workspace" hraText)
    "Actual workspace shell heading disappeared"
  expect (contains "Selected Actual Details:" hraText && contains "beta" hraText)
    "Actual workspace did not keep selected transaction details visible without a detail transition"
  let allCurrent := (Loam.Tui.ActualWorkspace.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot allCurrent).length == 3)
    "Actual workspace filter did not expand from Focus Day to all current Actual evidence"
  expect (allCurrent.order == .asc)
    "Actual workspace initial order was not ascending"

  -- Focus left pane (loci) and select locus 1 (paypay)
  let allCurrentLoci := (Loam.Tui.ActualWorkspace.update snapshot allCurrent .focusLeft).state
  let paypayLocus := (Loam.Tui.ActualWorkspace.update snapshot allCurrentLoci .next).state
  expect (Loam.Tui.ActualWorkspace.selectedLocus? snapshot paypayLocus == some "paypay")
    "Actual workspace next did not select the paypay locus"
  let paypayAsc := Loam.Tui.ActualWorkspace.visibleRecords snapshot paypayLocus
  expect (paypayAsc.map (·.description) == ["gamma", "beta", "alpha"])
    "Actual workspace paypay records in ascending order did not list oldest first"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayLocus with
  | none => throw (IO.userError "Actual workspace paypay record selection disappeared")
  | some record =>
      expect (record.description == "gamma")
        "Actual workspace ascending paypay record was not oldest first (gamma)"

  -- Toggle order to descending (newest first)
  let paypayDesc := (Loam.Tui.ActualWorkspace.update snapshot paypayLocus .cycleOrder).state
  expect (paypayDesc.order == .desc)
    "Actual workspace cycleOrder did not change order to descending"
  let paypayDescRecords := Loam.Tui.ActualWorkspace.visibleRecords snapshot paypayDesc
  expect (paypayDescRecords.map (·.description) == ["alpha", "beta", "gamma"])
    "Actual workspace paypay records in descending order did not list newest first"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayDesc with
  | none => throw (IO.userError "Actual workspace descending paypay record selection disappeared")
  | some record =>
      expect (record.description == "alpha")
        "Actual workspace descending paypay record at row 0 was not newest (alpha)"

  -- Move down in descending order
  let paypayDescRight := (Loam.Tui.ActualWorkspace.update snapshot paypayDesc .focusRight).state
  let paypayDescSecond := (Loam.Tui.ActualWorkspace.update snapshot paypayDescRight .next).state
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayDescSecond with
  | none => throw (IO.userError "Actual workspace descending second record disappeared")
  | some record =>
      expect (record.description == "beta")
        "Actual workspace descending second record was not beta"

  -- Toggle back to ascending
  let paypayAscAgain := (Loam.Tui.ActualWorkspace.update snapshot paypayDescSecond .cycleOrder).state
  expect (paypayAscAgain.order == .asc)
    "Actual workspace cycleOrder did not toggle back to ascending"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayAscAgain with
  | none => throw (IO.userError "Actual workspace toggled-back record disappeared")
  | some record =>
      expect (record.description == "gamma")
        "Actual workspace toggled-back record at row 0 was not oldest (gamma)"

  -- View check
  let descViewText := widgetText (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot paypayDesc)
  expect (contains "desc" descViewText && contains "newest first" descViewText)
    "Actual workspace view did not display descending order indication"
  expect (contains "[s] sort" descViewText)
    "Actual workspace view footer did not expose [s] sort"

  -- Production Actual workspace owns its own eight-row viewport. Pin navigation beyond it
  -- before the older Main cursor implementation is retired.
  let longActual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := (List.range 12).map testRecord
  }
  let longSnapshot : Loam.Tui.Main.Snapshot := { snapshot with actual := longActual }
  let longActualStart :=
    (Loam.Tui.ActualWorkspace.update longSnapshot
      (Loam.Tui.ActualWorkspace.initial "2026-09-07") .focusRight).state
  let longShifted := (List.range 10).foldl
    (fun current _ => (Loam.Tui.ActualWorkspace.update longSnapshot current .next).state)
    longActualStart
  expect (longShifted.transactionRow == 10)
    "Actual workspace selection could not reach the eleventh record"
  let longRecords := Loam.Tui.ActualWorkspace.visibleRecords longSnapshot longShifted
  let selectedLong ← requireSome
    (Loam.Tui.ActualWorkspace.selectedRecord? longSnapshot longShifted)
    "Actual workspace eleventh-row selection disappeared"
  let longViewText := widgetText
    (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } longSnapshot longShifted)
  expect (contains selectedLong.description longViewText)
    "Actual workspace moving viewport did not render its selected eleventh record"
  match longRecords.head? with
  | none => throw (IO.userError "Actual workspace long-list fixture became empty")
  | some firstLong =>
      expect (!contains firstLong.description longViewText)
        "Actual workspace eight-row viewport did not move beyond its first record"
  let longLast := (List.range 11).foldl
    (fun current _ => (Loam.Tui.ActualWorkspace.update longSnapshot current .next).state)
    longActualStart
  let longBlocked := (Loam.Tui.ActualWorkspace.update longSnapshot longLast .next).state
  expect (longBlocked.transactionRow == longLast.transactionRow &&
    contains "No next Actual row" longBlocked.notice)
    "Actual workspace end-of-list refusal moved selection or lost its notice"

  IO.println "TUI Actual: Actual workspace mechanics and production viewport checks passed."
