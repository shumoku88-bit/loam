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
  -- Width-based wrapping preserves Japanese, combining marks, and complete text.
  for columns in [2, 3, 10, 32, 80] do
    for text in ["", "abc def 123", "日本語と長い説明を途中で失わない", "e\u0301と日本語", "☕🙂coffee"] do
      let lines := Loam.Tui.Layout.wrapColumns columns text
      expect (String.intercalate "" lines == text &&
          lines.all fun line => Loam.Tui.Layout.displayWidth line <= columns)
        "Column wrapping lost text or exceeded its physical width"
  expect (Loam.Tui.Layout.wrapColumns 0 "日本語" == [] &&
      Loam.Tui.Layout.wrapColumns 1 "a日b" == ["a", "…", "b"])
    "Degenerate wrapping silently lost a wide glyph or exceeded its bounds"

  let snapshot ← actualWorkspaceSnapshot
  let actualStart := Loam.Tui.ActualWorkspace.initial "2026-09-07"
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot actualStart).length == 2)
    "Actual workspace Focus Day did not use the shared selected-day Actual answer"
  let right := (Loam.Tui.ActualWorkspace.update snapshot { actualStart with pane := .loci } .focusRight).state
  let second := (Loam.Tui.ActualWorkspace.update snapshot right .next).state
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot second with
  | none => throw (IO.userError "Actual workspace transaction selection disappeared")
  | some record =>
      expect (record.description == "beta")
        "Actual workspace j/down-style selection did not move to the second transaction"
  let hraText := widgetText (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot second)
  expect (contains "Household Actuals Workspace" hraText)
    "Actual workspace shell heading disappeared"
  expect (contains "╭ Details" hraText && contains "beta" hraText)
    "Actual workspace did not keep selected transaction details visible without a detail transition"
  -- Detail hierarchy: quantities first, descriptive text readable, identity quiet.
  let ordinaryDetails := Loam.Tui.ActualWorkspace.detailLines snapshot actualStart
  let detailTexts := ordinaryDetails.map widgetText
  expect (match detailTexts.findIdx? (contains "100 jpy"),
      detailTexts.findIdx? (contains "alpha"), detailTexts.findIdx? (contains "ID:") with
    | some amount, some description, some identity => amount < description && description < identity
    | _, _, _ => false)
    "Actual details did not prioritize quantities ahead of description and identity"
  expect ((Widget.column ordinaryDetails).lines.any fun cells =>
      cells.any (fun cell => cell.glyph == 'D' && cell.style == .muted))
    "Actual detail metadata became visually stronger than the quantities"
  expect (!contains "Status: Current" (widgetText (.column ordinaryDetails)) &&
      !contains "Selected Actual Details:" (widgetText (.column ordinaryDetails)))
    "Actual details retained redundant status or a second heading inside the frame"

  let longDescription := String.intercalate "" (List.replicate 8 "長い説明も日本語の幅で折り返して最後まで読む。")
  let longIdentity := "wrapped-id-" ++ String.intercalate "" (List.replicate 8 "1234567890") ++ "-tail"
  let wrappedRecord ← requireSome (actualRecord? longIdentity "2026-09-07"
    longDescription "paypay" "food" 12345) "wrapped details fixture was not admitted"
  let wrappedSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { today := "2026-09-07", allRecords := [wrappedRecord] } }
  -- A one-row detail viewport exposes each real content row without duplicate headers.
  let scanned := (List.range 64).map fun scroll =>
    let rendered := Loam.Tui.ActualWorkspace.view { width := 48, height := 6 }
      wrappedSnapshot { actualStart with pane := .details, detailScroll := scroll }
    let cells := rendered.lines[1]?.getD []
    String.ofList ((cells.drop 1).take (cells.length - 2) |>.map Cell.glyph)
  let reconstructed := (String.intercalate "" scanned).replace " " ""
  expect (contains longDescription reconstructed && contains longIdentity reconstructed &&
      contains "-12,345jpy" reconstructed && contains "12,345jpy" reconstructed)
    "Scrollable details lost a wrapped description, identity, or signed Effect"
  let geometry := fun (widget : Widget) => widget.lines.map fun cells =>
    cells.any (fun cell => cell.glyph == '╭' || cell.glyph == '╰')
  let normalView := Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot actualStart
  let wrappedView := Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    wrappedSnapshot actualStart
  expect (geometry normalView == geometry wrappedView)
    "A wrapped description changed panel heights or moved the list/detail divider"
  for bounds in [{ width := 100, height := 30 }, { width := 80, height := 24 },
      { width := 48, height := 10 }, { width := 48, height := 6 }] do
    for pane in [Loam.Tui.ActualWorkspace.Pane.loci, .transactions, .details] do
      let baseState := { actualStart with pane }
      let baseGeometry := geometry (Loam.Tui.ActualWorkspace.view bounds snapshot baseState)
      for variant in
          [{ baseState with notice := "End of Details." },
           { baseState with searchQuery := "gamma", searchEditing := true },
           { baseState with searchQuery := "gamma", notice := "No matching record." }] do
        let rendered := Loam.Tui.ActualWorkspace.view bounds snapshot variant
        expect (geometry rendered == baseGeometry)
          "Search or a boundary notice changed pane heights or divider positions"
      let noticed := widgetText (Loam.Tui.ActualWorkspace.view bounds snapshot
        { baseState with notice := "End of Details." })
      expect (contains "End of Details." noticed)
        "Stable geometry hid the boundary notice on a compact terminal"
  let compactSearch := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 48, height := 10 } snapshot
    { actualStart with searchQuery := "gamma", searchEditing := true })
  expect (contains "Search: /gamma_" compactSearch)
    "Stable context hid the search prompt on a low terminal"

  let stationaryDetails := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 100, height := 30 } snapshot
    { actualStart with pane := .details, detailScroll := 999 })
  expect (!contains "▲" stationaryDetails)
    "Details advertised an upward scroll when the complete content already fit"

  let allCurrent := (Loam.Tui.ActualWorkspace.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot allCurrent).length == 3)
    "Actual workspace filter did not expand from Focus Day to all current Actual evidence"
  expect (allCurrent.order == .desc)
    "Actual workspace initial order was not newest-first"

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

  -- Restrained palette: inactive panels and help stay muted; only focus is accented.
  let cornerStyles := fun (widget : Widget) =>
    (widget.lines.flatMap fun line => line.filter (fun cell => cell.glyph == '╭')).map Cell.style
  let defaultFrame := Loam.Tui.Layout.framedPanel 20 4 "Probe" (plainLine "content")
  let focusedFrame := Loam.Tui.Layout.framedPanel 20 4 "Probe" (plainLine "content")
    true
  expect (cornerStyles defaultFrame == [.muted] && cornerStyles focusedFrame == [.series1])
    "Panel styling lost muted inactive borders or the shared focus accent"
  expect (widgetText defaultFrame == widgetText focusedFrame &&
      focusedFrame.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) == 20)
    "Focus styling changed text or fixed-rectangle geometry"
  for (pane, expected) in
      [(Loam.Tui.ActualWorkspace.Pane.loci, [Style.series1, .muted, .muted]),
       (.transactions, [.muted, .series1, .muted]),
       (.details, [.muted, .muted, .series1])] do
    let rendered := Loam.Tui.ActualWorkspace.view { width := 144, height := 40 }
      snapshot { actualStart with pane }
    expect (cornerStyles rendered == expected)
      "Actual panels added decorative colors or focused more than one wide panel"
    for footerRow in rendered.lines.drop (rendered.lines.length - 2) do
      expect (footerRow.all fun cell => cell.style == .muted)
        "Actual footer introduced accent colors instead of remaining quiet"
  for bounds in [{ width := 144, height := 40 }, { width := 80, height := 24 },
      { width := 48, height := 10 }] do
    for pane in [Loam.Tui.ActualWorkspace.Pane.loci, .transactions, .details] do
      let rendered := Loam.Tui.ActualWorkspace.view bounds snapshot { actualStart with pane }
      expect (((cornerStyles rendered).filter (· == .series1)).length == 1)
        "Responsive Actual layout highlighted zero or multiple focused panels"
      expect (rendered.lines.all fun cells => cells.all fun cell =>
          cell.style == .normal || cell.style == .muted ||
          cell.style == .series1 || cell.style == .selected)
        "Responsive Actual layout introduced unnecessary accent colors"
      if pane == .details then
        expect (contains "Details [active]" (widgetText rendered) &&
            !rendered.lines.any (fun cells => cells.any (fun cell => cell.style == .selected)))
          "Compact Details focus remained invisible or also selected an unfocused list"
  let extraWide := Loam.Tui.ActualWorkspace.view { width := 220, height := 40 }
    snapshot actualStart
  let cornerColumns := ((extraWide.lines[2]?.getD []).zipIdx.filter
    (fun (cell, _) => cell.glyph == '╭')).map (·.2)
  expect (cornerColumns == [0, 51])
    "Extra-wide Actual layout grew the sidebar beyond its 50-column cap"

  -- Dense table: Description grows, amounts share the right edge, and context is compact.
  let table := Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    snapshot actualStart
  let tableLines := table.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  expect (tableLines.any fun line =>
      contains "Date" line && contains "Description" line && contains "Amount" line)
    "Actual table lost its column headings"
  for (description, amount) in [("alpha", "100 jpy"), ("beta", "200 jpy")] do
    expect (tableLines.any fun line => contains description line && line.endsWith (amount ++ "│"))
      "Actual table did not right-align complete amounts against the panel edge"
  expect (contains "known through 2026-09-07" (widgetText table) &&
      contains "Focus Day (2026-09-07)" (widgetText table) &&
      contains "1/2" (widgetText table))
    "Actual table lost known-through, scope, or selection position"
  expect ((tableLines[2]?.getD "").startsWith "╭")
    "Actual context still occupied more than two rows"

  -- Split amounts on either side and multiple Measures must not become a scalar total.
  let splitEvent ← requireSome (Event.ofEffects? ⟨"split"⟩
    [ Effect.ofQuantity ⟨"split-from"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-300))
    , Effect.ofQuantity ⟨"split-food"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    , Effect.ofQuantity ⟨"split-books"⟩ ⟨"books"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 200)
    ]) "split table fixture was not admitted"
  let splitRecord : Loam.Tui.Main.ReviewRecord := {
    event := splitEvent, date := some "2026-09-07", description := "split-row", replacement := none }
  let fromSplitEvent ← requireSome (Event.ofEffects? ⟨"from-split"⟩
    [ Effect.ofQuantity ⟨"from-split-a"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofQuantity ⟨"from-split-b"⟩ ⟨"smbc"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-200))
    , Effect.ofQuantity ⟨"from-split-to"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 300)
    ]) "FROM split table fixture was not admitted"
  let multiEvent ← requireSome (Event.ofEffects? ⟨"multi"⟩
    [ Effect.ofQuantity ⟨"multi-jpy-from"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofQuantity ⟨"multi-jpy-to"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    , Effect.ofQuantity ⟨"multi-usd-from"⟩ ⟨"smbc"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-123456))
    , Effect.ofQuantity ⟨"multi-usd-to"⟩ ⟨"books"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 123456)
    ]) "multi-Measure table fixture was not admitted"
  let presentationState := Loam.Tui.ActualWorkspace.withMeasurePresentation actualStart
    [{ measure := ⟨"usd"⟩, scale := 2 }]
  for (record, marker) in
      [(splitRecord, "split"),
       ({ splitRecord with event := fromSplitEvent, description := "from-split-row" }, "split"),
       ({ splitRecord with event := multiEvent, description := "multi-row" }, "multi (2)")] do
    let specimen : Loam.Tui.Main.Snapshot := {
      snapshot with actual := { today := "2026-09-07", allRecords := [record] } }
    let lines := (Loam.Tui.ActualWorkspace.view { width := 100, height := 36 }
      specimen presentationState).lines.map fun cells => String.ofList (cells.map Cell.glyph)
    expect (lines.any fun line =>
        contains record.description line && line.endsWith (marker ++ "│"))
      "Actual table collapsed split or multi-Measure Effects to a scalar"
    if marker == "multi (2)" then
      let text := String.intercalate "\n" lines
      expect (contains "-1,234.56 usd" text && contains "1,234.56 usd" text &&
          contains "100 jpy" text)
        "Actual details did not preserve separate Measures and exact decimal formatting"
    else
      expect (contains "100 jpy" (String.intercalate "\n" lines) &&
          contains "200 jpy" (String.intercalate "\n" lines))
        "Actual details lost individual split Effects"

  -- Simple amounts use the same exact decimal conventions; oversized values are not cut numbers.
  let decimalEvent ← requireSome (Event.ofEffects? ⟨"decimal"⟩
    [ Effect.ofQuantity ⟨"decimal-from"⟩ ⟨"smbc"⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-123456))
    , Effect.ofQuantity ⟨"decimal-to"⟩ ⟨"books"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 123456)
    ]) "decimal amount fixture was not admitted"
  let decimalRecord : Loam.Tui.Main.ReviewRecord := { splitRecord with
    event := decimalEvent, description := "decimal-row" }
  let decimalSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { today := "2026-09-07", allRecords := [decimalRecord] } }
  let decimalLines := (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    decimalSnapshot presentationState).lines.map fun cells => String.ofList (cells.map Cell.glyph)
  expect (decimalLines.any fun line =>
      contains "decimal-row" line && line.endsWith "1,234.56 usd│")
    "Actual table lost exact formatted decimal amounts"
  let oversized ← requireSome
    (actualRecord? "oversized" "2026-09-07" "huge-row" "paypay" "food" 12345678901234567890)
    "oversized amount fixture was not admitted"
  let oversizedSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { today := "2026-09-07", allRecords := [oversized] } }
  let oversizedLines := (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    oversizedSnapshot actualStart).lines.map fun cells => String.ofList (cells.map Cell.glyph)
  expect (oversizedLines.any fun line => contains "huge-row" line && line.endsWith "see details│")
    "Actual table silently clipped an oversized amount"
  let oversizedDetailRows := (List.range 32).map fun scroll =>
    let rendered := Loam.Tui.ActualWorkspace.view { width := 32, height := 6 }
      oversizedSnapshot { actualStart with pane := .details, detailScroll := scroll }
    let cells := rendered.lines[1]?.getD []
    String.ofList ((cells.drop 1).take (cells.length - 2) |>.map Cell.glyph)
  let oversizedDetailText := (String.intercalate "" oversizedDetailRows).replace " " ""
  expect (contains "Amount(wrapped):" oversizedDetailText &&
      contains "-12,345,678,901,234,567,890jpy" oversizedDetailText &&
      contains "12,345,678,901,234,567,890jpy" oversizedDetailText)
    "Narrow details silently clipped an oversized signed quantity instead of wrapping it"
  let unknownSnapshot : Loam.Tui.Main.Snapshot := { snapshot with actual := {
    today := "2026-09-07", allRecords := [{ decimalRecord with date := none }] } }
  let unknownText := widgetText (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    unknownSnapshot { presentationState with scope := .allCurrent })
  expect (contains "unknown" unknownText && !contains " > 2026-09-07" unknownText)
    "Actual table manufactured an occurrence date for an undated record"

  let emptyEffectSnapshot : Loam.Tui.Main.Snapshot := { snapshot with actual := {
    today := "2026-09-07", allRecords := [testRecord 0] } }
  let emptyEffectLines := (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 }
    emptyEffectSnapshot actualStart).lines.map fun cells => String.ofList (cells.map Cell.glyph)
  expect (emptyEffectLines.any fun line => contains "row-0" line && line.endsWith "—│")
    "Actual table invented a zero quantity for an Event without Effects"
  let tinyTable := Loam.Tui.ActualWorkspace.view { width := 100, height := 6 }
    snapshot actualStart
  expect (tinyTable.lines.any fun cells => cells.any (fun cell => cell.style == .selected))
    "Actual column headings consumed the only available record row"
  expect ((Loam.Tui.ActualWorkspace.visibleRecords snapshot actualStart).map (·.event.id.token) ==
      (Loam.Tui.ActualWorkspace.visibleRecords snapshot presentationState).map (·.event.id.token))
    "Measure formatting changed Actual filtering, identity, or order"

  -- Focus left pane (loci) and select locus 1 (paypay)
  let allCurrentLoci := (Loam.Tui.ActualWorkspace.update snapshot allCurrent .focusLeft).state
  let paypayLocus := (Loam.Tui.ActualWorkspace.update snapshot allCurrentLoci .next).state
  expect (Loam.Tui.ActualWorkspace.selectedLocus? snapshot paypayLocus == some "paypay")
    "Actual workspace next did not select the paypay locus"
  let paypayDesc := Loam.Tui.ActualWorkspace.visibleRecords snapshot paypayLocus
  expect (paypayDesc.map (·.description) == ["alpha", "beta", "gamma"])
    "Actual workspace default paypay order did not list newest first"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayLocus with
  | none => throw (IO.userError "Actual workspace paypay record selection disappeared")
  | some record =>
      expect (record.description == "alpha")
        "Actual workspace default paypay record was not newest first (alpha)"

  -- Toggle order to ascending (oldest first)
  let paypayAsc := (Loam.Tui.ActualWorkspace.update snapshot paypayLocus .cycleOrder).state
  expect (paypayAsc.order == .asc)
    "Actual workspace cycleOrder did not change order to ascending"
  let paypayAscRecords := Loam.Tui.ActualWorkspace.visibleRecords snapshot paypayAsc
  expect (paypayAscRecords.map (·.description) == ["gamma", "beta", "alpha"])
    "Actual workspace paypay records in ascending order did not list oldest first"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayAsc with
  | none => throw (IO.userError "Actual workspace ascending paypay record selection disappeared")
  | some record =>
      expect (record.description == "gamma")
        "Actual workspace ascending paypay record at row 0 was not oldest (gamma)"

  -- Move down in ascending order
  let paypayAscRight := (Loam.Tui.ActualWorkspace.update snapshot paypayAsc .focusRight).state
  let paypayAscSecond := (Loam.Tui.ActualWorkspace.update snapshot paypayAscRight .next).state
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayAscSecond with
  | none => throw (IO.userError "Actual workspace ascending second record disappeared")
  | some record =>
      expect (record.description == "beta")
        "Actual workspace ascending second record was not beta"

  -- Toggle back to descending
  let paypayDescAgain := (Loam.Tui.ActualWorkspace.update snapshot paypayAscSecond .cycleOrder).state
  expect (paypayDescAgain.order == .desc)
    "Actual workspace cycleOrder did not toggle back to descending"
  match Loam.Tui.ActualWorkspace.selectedRecord? snapshot paypayDescAgain with
  | none => throw (IO.userError "Actual workspace toggled-back record disappeared")
  | some record =>
      expect (record.description == "alpha")
        "Actual workspace toggled-back record at row 0 was not newest (alpha)"

  -- View check
  let descViewText := widgetText (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } snapshot paypayDescAgain)
  expect (contains "desc" descViewText && contains "newest first" descViewText)
    "Actual workspace view did not display descending order indication"
  expect (contains "[s] sort" descViewText)
    "Actual workspace view footer did not expose [s] sort"

  -- Test details pane navigation, focus, and scrolling
  let toDetails := (Loam.Tui.ActualWorkspace.update snapshot paypayDescAgain .toggleDetails).state
  expect (toDetails.pane == .details)
    "toggleDetails did not enter details pane"
  let detailsScrolled := (Loam.Tui.ActualWorkspace.update snapshot toDetails .next).state
  expect (detailsScrolled.detailScroll == 1)
    "next in details pane did not increment detailScroll"
  let detailsScrolledUp := (Loam.Tui.ActualWorkspace.update snapshot detailsScrolled .previous).state
  expect (detailsScrolledUp.detailScroll == 0)
    "previous in details pane did not decrement detailScroll"
  let backToActuals := (Loam.Tui.ActualWorkspace.update snapshot detailsScrolled .back).state
  expect (backToActuals.pane == .transactions)
    "back event from details pane did not return to transactions pane"

  -- Test cyclePane Tab navigation
  let cycledToLoci := (Loam.Tui.ActualWorkspace.update snapshot { paypayDescAgain with pane := .details } .cyclePane).state
  expect (cycledToLoci.pane == .loci)
    "cyclePane from details did not cycle to loci"
  let cycledToTx := (Loam.Tui.ActualWorkspace.update snapshot cycledToLoci .cyclePane).state
  expect (cycledToTx.pane == .transactions)
    "cyclePane from loci did not cycle to transactions"
  let cycledToDetails := (Loam.Tui.ActualWorkspace.update snapshot cycledToTx .cyclePane).state
  expect (cycledToDetails.pane == .details)
    "cyclePane from transactions did not cycle to details"

  -- Test arrow-key looping navigation (symmetric with cyclePane / cyclePaneBack)
  let rightFromTx := (Loam.Tui.ActualWorkspace.update snapshot cycledToTx .focusRight).state
  expect (rightFromTx.pane == .details)
    "focusRight from transactions did not loop to details"
  let rightFromDetails := (Loam.Tui.ActualWorkspace.update snapshot rightFromTx .focusRight).state
  expect (rightFromDetails.pane == .loci)
    "focusRight from details did not navigate to loci"
  let rightFromLoci := (Loam.Tui.ActualWorkspace.update snapshot rightFromDetails .focusRight).state
  expect (rightFromLoci.pane == .transactions)
    "focusRight from loci did not navigate to transactions"
  let leftFromTx := (Loam.Tui.ActualWorkspace.update snapshot rightFromLoci .focusLeft).state
  expect (leftFromTx.pane == .loci)
    "focusLeft from transactions did not loop to loci"
  let leftFromLoci := (Loam.Tui.ActualWorkspace.update snapshot leftFromTx .focusLeft).state
  expect (leftFromLoci.pane == .details)
    "focusLeft from loci did not loop to details"
  let leftFromDetails := (Loam.Tui.ActualWorkspace.update snapshot leftFromLoci .focusLeft).state
  expect (leftFromDetails.pane == .transactions)
    "focusLeft from details did not navigate to transactions"

  -- Production Actual workspace should use the available terminal height rather than
  -- keeping the former fixed eight-row viewport, while still scrolling long lists.
  let longActual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := (List.range 30).map testRecord
  }
  let longSnapshot : Loam.Tui.Main.Snapshot := { snapshot with actual := longActual }
  let longActualStart :=
    (Loam.Tui.ActualWorkspace.update longSnapshot
      { Loam.Tui.ActualWorkspace.initial "2026-09-07" with pane := .loci } .focusRight).state
  let tallViewText := widgetText
    (Loam.Tui.ActualWorkspace.view { width := 100, height := 40 } longSnapshot longActualStart)
  expect (contains "row-21" tallViewText)
    "Actual workspace did not grow its list viewport beyond the former eight rows"
  let longShifted := (List.range 26).foldl
    (fun current _ => (Loam.Tui.ActualWorkspace.update longSnapshot current .next).state)
    longActualStart
  expect (longShifted.transactionRow == 26)
    "Actual workspace selection could not reach a record beyond the visible window"
  let longRecords := Loam.Tui.ActualWorkspace.visibleRecords longSnapshot longShifted
  let selectedLong ← requireSome
    (Loam.Tui.ActualWorkspace.selectedRecord? longSnapshot longShifted)
    "Actual workspace long-list selection disappeared"
  let longViewText := widgetText
    (Loam.Tui.ActualWorkspace.view { width := 100, height := 30 } longSnapshot longShifted)
  expect (contains selectedLong.description longViewText)
    "Actual workspace moving viewport did not render its selected long-list record"
  match longRecords.head? with
  | none => throw (IO.userError "Actual workspace long-list fixture became empty")
  | some firstLong =>
      expect (!contains firstLong.description longViewText)
        "Actual workspace moving viewport did not leave its first record behind"
  let longLast := (List.range 29).foldl
    (fun current _ => (Loam.Tui.ActualWorkspace.update longSnapshot current .next).state)
    longActualStart
  let longBlocked := (Loam.Tui.ActualWorkspace.update longSnapshot longLast .next).state
  expect (longBlocked.transactionRow == longLast.transactionRow &&
    contains "No next Actual row" longBlocked.notice)
    "Actual workspace end-of-list refusal moved selection or lost its notice"

  -- Responsive frame geometry uses terminal columns (including Japanese labels),
  -- not codepoint counts. Exercise breakpoint edges and degenerate bounds too.
  let japanese ← requireSome
    (actualRecord? "日本語-record" "2026-09-07"
      "セブンイレブン・長い説明とコーヒー" "銀行口座" "食費" 12345)
    "Japanese layout fixture was not admitted"
  let japaneseSnapshot : Loam.Tui.Main.Snapshot :=
    { snapshot with actual := { today := "2026-09-07", allRecords := [japanese] } }
  for width in [0, 1, 2, 20, 40, 80, 98, 99, 100, 144, 220] do
    for height in [0, 1, 2, 3, 8, 18, 21, 22, 24, 30, 36, 48, 60] do
      for pane in [Loam.Tui.ActualWorkspace.Pane.loci, .transactions, .details] do
        let bounds : Bounds := { width, height }
        let state := { actualStart with
          pane := pane
          searchEditing := true
          searchQuery := ""
          notice := "No previous Actual row." }
        let widget := Loam.Tui.ActualWorkspace.view bounds japaneseSnapshot state
        expect (widget.lines.length <= height - 1)
          s!"Actual layout exceeded usable height at {width}x{height}"
        expect (widget.lines.all fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds)
          s!"Actual layout exceeded terminal columns at {width}x{height}"

  let wide := Loam.Tui.ActualWorkspace.view { width := 144, height := 40 }
    longSnapshot longShifted
  let detailRow := wide.lines.findIdx? fun cells =>
    contains "╭ Details" (String.ofList (cells.map Cell.glyph))
  let selectedRow := wide.lines.findIdx? fun cells =>
    cells.any (fun cell => cell.style == .selected)
  expect (match detailRow, selectedRow with
    | some detail, some selected => detail < selected
    | _, _ => false)
    "Wide Actual list did not extend below the left detail heading"
  for width in [80, 100, 144] do
    let rendered := Loam.Tui.ActualWorkspace.view { width, height := 30 }
      japaneseSnapshot actualStart
    let text := widgetText rendered
    expect (contains "-12,345 jpy" text && contains "12,345 jpy" text)
      "Responsive detail column hid effect amounts"
    expect ((contains "╭" text || contains "┌" text) && !contains "====" text && !contains "----" text)
      "Actual workspace retained heavy separator rules"
  let japaneseTableText := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 100, height := 30 } japaneseSnapshot actualStart)
  expect (contains "…" japaneseTableText && contains "12,345 jpy" japaneseTableText)
    "Japanese table descriptions lost visible truncation or the complete amount"
  let longLocus ← requireSome (actualRecord? "long-locus" "2026-09-07" "long locus"
    "a-very-long-historical-locus-token-that-cannot-fit" "food" 100)
    "long Locus fixture was not admitted"
  let longLocusSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := { today := "2026-09-07", allRecords := [longLocus] } }
  let longLocusLines := (Loam.Tui.ActualWorkspace.view
    { width := 144, height := 40 } longLocusSnapshot actualStart).lines.map fun cells =>
      String.ofList (cells.map Cell.glyph)
  expect (longLocusLines.any fun line =>
      contains "a-very-long-historical-locus-token" line && contains "…" line)
    "Narrower Locus sidebar silently clipped a long identity instead of showing an ellipsis"
  let compactTableText := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 40, height := 24 } snapshot actualStart)
  expect (contains "Description" compactTableText && contains "alpha" compactTableText)
    "Compact Actual table did not retain readable descriptions"
  let narrowLoci := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 80, height := 24 } snapshot { actualStart with pane := .loci })
  expect (contains "Loci [active]" narrowLoci && contains "[All loci]" narrowLoci)
    "Narrow layout failed to expose the focused Loci pane"
  for bounds in [{ width := 80, height := 24 }, { width := 144, height := 40 }] do
    let rendered := Loam.Tui.ActualWorkspace.view bounds longSnapshot longShifted
    expect (rendered.lines.any fun cells => cells.any (fun c => c.style == .selected))
      "Resize lost the selected list row (not merely its detail text)"
  let emptyText := widgetText (Loam.Tui.ActualWorkspace.view
    { width := 100, height := 30 } snapshot { actualStart with searchQuery := "missing" })
  expect (contains "no matching Actual records" emptyText)
    "Empty responsive Actual pane lost its explanation"

  IO.println "TUI Actual: search/open, navigation and responsive frame checks passed."
