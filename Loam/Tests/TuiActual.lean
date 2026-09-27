import Loam.Tui.Main
import Loam.Tui.ActualWorkspace
import Loam.Tui.SelectedDay

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

  -- Slash-style search reuses ActualReview text search across all current evidence.
  let some searchMetadata := Loam.LocusCatalog.decode?
      ("paypay\tPayPay\tPayPay残高\n" ++
       "food\t食費\t食費支出\n" ++
       "smbc\tSMBC\t銀行口座\n" ++
       "books\t書籍\t本・学習用の書籍\n")
    | throw (IO.userError "Actual workspace search metadata fixture")
  let searchStart := Loam.Tui.ActualWorkspace.withMetadata
    (Loam.Tui.ActualWorkspace.initial "2026-09-07") searchMetadata
  let searching := (Loam.Tui.ActualWorkspace.update snapshot searchStart .beginSearch).state
  expect (searching.scope == .allCurrent && searching.pane == .transactions &&
      searching.searchEditing)
    "Actual workspace search did not enter all-current transaction search"
  let gammaSearch := "gamma".toList.foldl
    (fun current char =>
      (Loam.Tui.ActualWorkspace.update snapshot current (.searchInput char)).state)
    searching
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot gammaSearch).map (·.description) == ["gamma"])
    "Actual workspace description search did not isolate the older matching Actual"
  let keptSearch := (Loam.Tui.ActualWorkspace.update snapshot gammaSearch .acceptSearch).state
  expect (!keptSearch.searchEditing && keptSearch.searchQuery == "gamma")
    "Actual workspace Enter did not keep the accepted search result"
  let openSearch := Loam.Tui.ActualWorkspace.update snapshot keptSearch .openSelected
  expect (openSearch.command == .openSelected)
    "Actual workspace Enter intent did not open the selected search result"
  let gammaRecord ← requireSome
    (Loam.Tui.ActualWorkspace.selectedRecord? snapshot keptSearch)
    "Actual workspace search result selection disappeared"
  let gammaDay ← requireSome
    (Loam.Tui.SelectedDay.initialForActual? snapshot gammaRecord)
    "Selected-day workspace could not initialize from the searched Actual"
  expect (gammaDay.focusDate == "2026-09-06")
    "Actual search did not preserve the selected record occurrence date"
  let openedGamma ← requireSome
    (Loam.Tui.SelectedDay.selectedActual? snapshot gammaDay)
    "Selected-day search handoff lost the exact selected Actual"
  expect (openedGamma.event.id.token == "event-2")
    "Selected-day search handoff selected a different Actual on the target date"

  let dateSearch := { searching with searchQuery := "2026-09-06", searchEditing := false }
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot dateSearch).map (·.description) == ["gamma"])
    "Actual workspace date search did not reuse ActualReview text matching"
  let locusSearch := { searching with searchQuery := "books", searchEditing := false }
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot locusSearch).map (·.description) == ["gamma"])
    "Actual workspace Locus-token search did not reuse ActualReview text matching"
  let labelSearch := { searching with searchQuery := "書籍", searchEditing := false }
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot labelSearch).map (·.description) == ["gamma"])
    "Actual workspace human-facing Locus label search did not find the matching Actual"
  let searchText := widgetText
    (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot gammaSearch)
  expect (contains "Search: /gamma_" searchText &&
      contains "Backspace delete" searchText)
    "Actual workspace active search query or search help disappeared"
  let cancelledSearch := (Loam.Tui.ActualWorkspace.update snapshot gammaSearch .cancelSearch).state
  expect (cancelledSearch.searchQuery.isEmpty && !cancelledSearch.searchEditing &&
      (Loam.Tui.ActualWorkspace.visibleRecords snapshot cancelledSearch).length == 3)
    "Actual workspace Esc-style search cancellation did not restore all-current browsing"

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

  IO.println "TUI Actual: Actual workspace search/open, mechanics and production viewport checks passed."
