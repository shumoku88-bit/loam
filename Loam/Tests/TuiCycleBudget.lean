import Loam.Tui.CycleBudget
import Loam.Tui.Home

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)
private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))
private def contains (needle haystack : String) : Bool := (haystack.splitOn needle).length > 1
private def q := Quantity.ofQuanta

private def fixture : Loam.CycleBudgetReview.Snapshot :=
  { observedAt := "2026-09-08"
    window := .ok {
      source := "Pension"
      start := "2026-08-14"
      endExclusive := "2026-10-15"
      hasFollowingBoundary := false }
    coverage := .ok {
      currentWindowStart := "2026-08-14"
      observedAt := "2026-09-08"
      endExclusive := "2026-10-15"
      rows := [{ purpose := ⟨"食費:ストック"⟩, entitlement := q 111, consumption := q 222, commitment := q 333 }]
      scheduledFrontier := some { unmanaged := q 1234, unrouted := q 2345, unresolvedEligibility := q 4000 }
      actualRoutingFrontier := {
        unroutedExpense := [
          { event := ⟨"actual-1"⟩
            validOn := "2026-09-05"
            locus := ⟨"shipping"⟩
            measure := ⟨"jpy"⟩
            quantity := q 720
            role := some .expense }
        ]
        unresolvedRole := [
          { event := ⟨"actual-2"⟩
            validOn := "2026-09-06"
            locus := ⟨"mystery"⟩
            measure := ⟨"jpy"⟩
            quantity := q 10
            role := none }
        ]
      } }
    physical := .ok { rows := [
      { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, quantity := q 1200 },
      { coordinate := ⟨⟨"yucho"⟩, ⟨"jpy"⟩⟩, quantity := q 3400 }] }
    selection := .ok [⟨⟨"cash"⟩, ⟨"jpy"⟩⟩]
    -- Coverage owns query-global future pressure; funding keeps only independent quantities.
    funding := .ok {
      budgetableBacking := q 90000
      remainingAssigned := q 55000 } }

def main : IO Unit := do
  let bounds : Bounds := { width := 100, height := 40 }
  let state : Loam.Tui.CycleBudget.State := { snapshot := fixture }
  let rendered := text (Loam.Tui.CycleBudget.view bounds state)
  for value in ["Budget / Pension Cycle", "2026-08-14 -> 2026-10-15", "Observed 2026-09-08",
      "37 days to next boundary", "Boundary horizon: 2026-10-15 is the last explicitly configured boundary.",
      "Purpose / jpy", "Purpose totals / jpy (allocated capacity, not money received)",
      "Assigned 111   Spent 222   Now -111",
      "~jpy/day", "After-known", "known managed plans only; not spending permission",
      "-111", "-444", "食費:ストック", "-12", "d details", "Other future pressure is not assigned",
      "Unrouted Actual interpretation is not included", "Funding / jpy (separate from Purpose totals)",
      "Backing 90000   Remaining assigned 55000   Residual 35000"] do
    expect (contains value rendered) ("missing compact answer: " ++ value)
  expect (!(contains "Budgetable backing" rendered) && !(contains "cash: 1200" rendered) &&
    !(contains "Details / Purpose components" rendered))
    "expanded accounting details displaced the Purpose overview"
  expect (!(contains "Daily pace:" rendered)) "Purpose guide copied the independent Home pool pace"
  let usd : MeasureId := ⟨"usd"⟩
  let .ok baseCoverage := fixture.coverage
    | throw (IO.userError "fixture has no coverage")
  let .ok baseFunding := fixture.funding
    | throw (IO.userError "fixture has no funding")
  let usdFixture : Loam.CycleBudgetReview.Snapshot := {
    fixture with
      measure := usd
      coverage := .ok { baseCoverage with measure := usd }
      funding := .ok { baseFunding with measure := usd }
  }
  let usdRendered := text (Loam.Tui.CycleBudget.view bounds { snapshot := usdFixture })
  for value in ["Purpose / usd", "Purpose totals / usd", "~usd/day",
      "Funding / usd (separate from Purpose totals)"] do
    expect (contains value usdRendered) ("USD Cycle Budget label missing: " ++ value)
  expect (!(contains "Purpose / jpy" usdRendered) && !(contains "~jpy/day" usdRendered))
    "Cycle Budget rewrote the snapshot Measure as JPY"
  let rowText := text (Loam.Tui.CycleBudget.coverageRow []
    { purpose := ⟨"食費"⟩, entitlement := q 100, consumption := q 0, commitment := q 0 } (some 3))
  expect (contains "食費" rowText && contains "33" rowText &&
    Loam.Tui.Layout.displayWidth rowText == 61)
    "Japanese label or daily guide broke fixed-column coverage row"
  let (expanded, detailIntent) := Loam.Tui.CycleBudget.update bounds state (.input 'd')
  expect (detailIntent == .stay && expanded.details && expanded.scroll == 0)
    "d did not open detail mode"
  let detailsText := text (Loam.Tui.CycleBudget.view bounds expanded)
  for value in ["111", "222", "333", "90000", "55000", "35000", "4000", "1234", "2345",
      "Residual before unresolved", "Unresolved future pressure", "Unrouted future pressure",
      "Unmanaged future pressure", "Actual routing frontier", "Unrouted Actual Expense rows: 1",
      "Role-unresolved Actual rows: 1", "Purpose coverage excludes still-unresolved",
      "cash: 1200 jpy  [budget backing]", "yucho: 3400 jpy  [outside budget backing]",
      "Cap", "Spent", "Known future"] do
    expect (contains value detailsText) ("details lost supplied evidence: " ++ value)
  let (collapsed, _) := Loam.Tui.CycleBudget.update bounds expanded (.input 'D')
  expect (!collapsed.details && !(contains "Budgetable backing" <|
    text (Loam.Tui.CycleBudget.view bounds collapsed))) "D did not collapse details"
  expect (!(contains "Safe to spend" rendered) && !(contains "Available" rendered))
    "residual was promoted to spending permission"
  expect (!(contains "Capacity/actions" rendered)) "retired Budget Capacity detour still rendered"
  let continued : Loam.Tui.CycleBudget.State := {
    snapshot := { fixture with
      window := .ok {
        source := "Pension"
        start := "2026-08-14"
        endExclusive := "2026-10-15"
        hasFollowingBoundary := true } } }
  let continuedText := text (Loam.Tui.CycleBudget.view bounds continued)
  expect (!(contains "Boundary horizon:" continuedText))
    "Budget warned despite an explicitly configured following boundary"
  expect (!(contains "read only" rendered)) "writable Budget still claims read only"
  let missing : Loam.Tui.CycleBudget.State := { snapshot := { fixture with
    selection := .error "not configured", funding := .error "not configured" } }
  let missingText := text (Loam.Tui.CycleBudget.view bounds missing)
  expect (contains "食費:ストック" missingText && contains "-12" missingText &&
    contains "Assigned 111   Spent 222   Now -111" missingText &&
    contains "Funding unavailable: not configured" missingText)
    "independent funding failure hid Purpose totals or guide"
  let missingDetails := text (Loam.Tui.CycleBudget.view bounds { missing with details := true })
  for value in ["Funding unavailable: not configured", "-111", "cash: 1200 jpy",
      "backing selection unavailable", "4000"] do
    expect (contains value missingDetails) ("optional failure hid detail evidence: " ++ value)
  expect (!(contains "[outside budget backing]" missingDetails)) "missing selection inferred outside"
  let .ok originalCoverage := fixture.coverage
    | throw (IO.userError "fixture has no coverage")
  let threeDays : Loam.Tui.CycleBudget.State := {
    snapshot := { fixture with
      observedAt := "2026-10-12"
      coverage := .ok { originalCoverage with
        observedAt := "2026-10-12"
        rows := [{ purpose := ⟨"食費"⟩, entitlement := q 100, consumption := q 0, commitment := q 0 }] } } }
  let threeDaysText := text (Loam.Tui.CycleBudget.view bounds threeDays)
  expect (contains "食費" threeDaysText && contains "33" threeDaysText)
    "positive guide did not divide After-known by remaining calendar days"
  expect (contains "Assigned 100   Spent 0   Now 100" threeDaysText)
    "Purpose totals were not recomputed from the current rows"
  let stale : Loam.Tui.CycleBudget.State := {
    snapshot := { fixture with observedAt := "2026-10-12" } }
  expect (contains "Per-day guide unavailable: coverage horizon differs" <|
    text (Loam.Tui.CycleBudget.view bounds stale))
    "mismatched coverage was divided by a new date"
  let expired : Loam.Tui.CycleBudget.State := {
    snapshot := { fixture with
      observedAt := "2026-10-15"
      coverage := .ok { originalCoverage with
        observedAt := "2026-10-15" } } }
  expect (contains "Per-day guide unavailable: no remaining calendar days" <|
    text (Loam.Tui.CycleBudget.view bounds expired))
    "zero-day horizon was divided"
  let failed : Loam.Tui.CycleBudget.State := { snapshot := { fixture with
    coverage := .error "bad evidence", funding := .error "bad evidence" } }
  let failedText := text (Loam.Tui.CycleBudget.view bounds failed)
  expect (contains "CurrentCoverage unavailable" failedText &&
    contains "Funding unavailable: bad evidence" failedText)
    "independent coverage or funding failure was hidden"
  expect (!(contains "cash: 1200" failedText)) "detail balances leaked into compact view"
  expect (!(contains "~jpy/day" failedText) && !(contains "Purpose totals / jpy" failedText))
    "missing coverage invented totals or a daily guide"
  expect (Loam.Tui.CycleBudget.isHomeEntrance (.input 'c')) "Home c entrance missing"
  expect (!(Loam.Tui.CycleBudget.isHomeEntrance (.input 'e'))) "raw Capacity alias stolen"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'q')).2 == .home) "q is not Home"
  expect ((Loam.Tui.CycleBudget.update bounds state .escape).2 == .home) "Esc is not Home"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'b')).2 == .stay) "retired b Home alias survived"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'e')).2 == .stay)
    "Budget e still enters raw Capacity"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'E')).2 == .stay)
    "Budget E still enters raw Capacity"
  expect (contains "u route" rendered) "footer missing u route"
  expect (contains "g grant" rendered) "footer missing g grant"
  expect (contains "r rebalance" rendered) "footer missing r rebalance"
  let (stayEmpty, intentEmpty) := Loam.Tui.CycleBudget.update bounds state (.input 'u')
  expect (intentEmpty == .stay) "empty unresolved does not stay"
  expect (stayEmpty.notice == "No unresolved Scheduled routing subjects.") "empty notice wrong"

  let withUnresolved : Loam.Tui.CycleBudget.State :=
    match fixture.coverage with
    | .error _ => state
    | .ok cov =>
        let cov' := { cov with
          unresolvedScheduled := [
            { subject := { scheduled := ⟨"scheduled-1"⟩, locus := ⟨"wifi"⟩ }
              scheduledOn := "2026-10-08"
              measure := ⟨"jpy"⟩
              quantity := q 4000 } ] }
        { snapshot := { fixture with coverage := .ok cov' } }
  let (nextUnresolved, intentUnresolved) := Loam.Tui.CycleBudget.update bounds withUnresolved (.input 'u')
  expect (intentUnresolved == .unresolved) "u key failed to enter unresolved"
  expect (nextUnresolved.notice.isEmpty) "notice not cleared on enter"
  let (_, intentUnresolvedCap) := Loam.Tui.CycleBudget.update bounds withUnresolved (.input 'U')
  expect (intentUnresolvedCap == .unresolved) "U key failed to enter unresolved"

  -- C2 synthetic tests:
  -- 1. Single shortage emits .grant intent
  let (stateSingleG, intentSingleG) := Loam.Tui.CycleBudget.update bounds state (.input 'g')
  expect (stateSingleG.notice.isEmpty) "notice not cleared on single grant"
  match intentSingleG with
  | .grant row =>
      expect (row.purpose.token == "食費:ストック") "purpose mismatch"
      expect (row.headroom.quanta == -444) "headroom mismatch"
  | _ => throw (IO.userError "expected grant intent for single shortage")

  -- 2. No shortages -> notice and no action
  let noShortagesCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := [{ purpose := ⟨"食費"⟩, entitlement := q 1000, consumption := q 200, commitment := q 300 }]
    scheduledFrontier := none
  }
  let stateNoShortages : Loam.Tui.CycleBudget.State := { snapshot := { fixture with coverage := .ok noShortagesCoverage } }
  let (stateNoShortagesAfterG, intentNoShortages) := Loam.Tui.CycleBudget.update bounds stateNoShortages (.input 'g')
  expect (intentNoShortages == .stay) "0 shortages must stay"
  expect (stateNoShortagesAfterG.notice == "No Purpose has negative After-known headroom.") "0 shortages notice mismatch"

  -- 3. Now negative but After-known positive -> NOT shortage
  let nowNegHeadroomPosCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := [{ purpose := ⟨"食費"⟩, entitlement := q 1000, consumption := q 1500, commitment := q (-700) }]
    scheduledFrontier := none
  }
  let stateNowNeg : Loam.Tui.CycleBudget.State := { snapshot := { fixture with coverage := .ok nowNegHeadroomPosCoverage } }
  let (stateNowNegAfterG, intentNowNeg) := Loam.Tui.CycleBudget.update bounds stateNowNeg (.input 'g')
  expect (intentNowNeg == .stay) "Now negative but After-known positive must not be shortage"
  expect (stateNowNegAfterG.notice == "No Purpose has negative After-known headroom.") "notice mismatch"

  -- 3b. Now positive but After-known negative -> IS shortage
  let nowPosHeadroomNegCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := [{ purpose := ⟨"固定費予定"⟩, entitlement := q 12000, consumption := q 5000, commitment := q 9000 }]
    scheduledFrontier := none
  }
  let stateNowPos : Loam.Tui.CycleBudget.State := { snapshot := { fixture with coverage := .ok nowPosHeadroomNegCoverage } }
  let (_, intentNowPos) := Loam.Tui.CycleBudget.update bounds stateNowPos (.input 'g')
  match intentNowPos with
  | .grant row =>
      expect (row.purpose.token == "固定費予定") "purpose token mismatch"
      expect (row.headroom.quanta == -2000) "headroom mismatch"
  | _ => throw (IO.userError "expected grant intent for After-known negative")

  -- 4. Multiple shortages -> human selection required in picker
  let multiShortagesCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows :=
      [ { purpose := ⟨"固定費予定"⟩, entitlement := q 12000, consumption := q 5000, commitment := q 9000 }
      , { purpose := ⟨"タバコ"⟩, entitlement := q 10000, consumption := q 8000, commitment := q 5000 }
      , { purpose := ⟨"食費"⟩, entitlement := q 30000, consumption := q 10000, commitment := q 0 }
      ]
    scheduledFrontier := none
  }
  let stateMulti : Loam.Tui.CycleBudget.State := { snapshot := { fixture with coverage := .ok multiShortagesCoverage } }
  let (statePicker, intentPicker) := Loam.Tui.CycleBudget.update bounds stateMulti (.input 'g')
  expect (intentPicker == .stay) "multiple shortages must not auto-publish"
  match statePicker.submode with
  | .grantPicker shortages selected =>
      expect (shortages.length == 2) "only 2 shortages filtered (not 3)"
      expect (selected == 0) "initial selected 0"
  | _ => throw (IO.userError "expected grantPicker submode")
  let pickerView := text (Loam.Tui.CycleBudget.view bounds statePicker)
  expect (contains "Cycle Grant / Select Purpose" pickerView) "picker title"
  expect (contains "固定費予定" pickerView && contains "-2000" pickerView) "first candidate"
  expect (contains "タバコ" pickerView && contains "-3000" pickerView) "second candidate"
  expect (!(contains "食費" pickerView)) "non-shortage must not appear in picker"

  -- Picker navigation: j / k
  let (stateDown, _) := Loam.Tui.CycleBudget.update bounds statePicker (.input 'j')
  match stateDown.submode with
  | .grantPicker _ sel => expect (sel == 1) "j moved selection down"
  | _ => throw (IO.userError "lost picker submode")

  -- Picker selection with Enter
  let (stateSelected, intentSelected) := Loam.Tui.CycleBudget.update bounds stateDown .enter
  expect (stateSelected.submode == .normal) "submode reset to normal after enter"
  match intentSelected with
  | .grant row => expect (row.purpose.token == "タバコ") "selected row 1 purpose"
  | _ => throw (IO.userError "expected grant intent on enter")

  -- Picker cancel with Esc
  let (stateCancelEsc, intentCancelEsc) := Loam.Tui.CycleBudget.update bounds statePicker .escape
  expect (stateCancelEsc.submode == .normal) "submode reset on Esc"
  expect (intentCancelEsc == .stay) "Esc must stay"

  -- Picker cancel with q; retired b alias must not cancel.
  let (stateCancelQ, intentCancelQ) := Loam.Tui.CycleBudget.update bounds statePicker (.input 'q')
  expect (stateCancelQ.submode == .normal) "submode reset on q"
  expect (intentCancelQ == .stay) "q cancel must stay in Budget"
  let (stateIgnoredB, intentIgnoredB) := Loam.Tui.CycleBudget.update bounds statePicker (.input 'b')
  expect (stateIgnoredB.submode == statePicker.submode) "retired b alias still cancels picker"
  expect (intentIgnoredB == .stay) "ignored b changed intent"

  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'r')).2 == .rebalance)
    "r did not enter existing Capacity Rebalance"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'R')).2 == .rebalance)
    "R did not enter existing Capacity Rebalance"
  let small : Bounds := { width := 80, height := 12 }
  let down := (Loam.Tui.CycleBudget.update small state .down).1
  expect (down.scroll == 1) "small terminal cannot scroll"
  expect ((Loam.Tui.CycleBudget.view small down).lines.length < small.height) "footer overflow"
  let last := text (Loam.Tui.CycleBudget.view small { state with scroll := 999 })
  expect (contains "-111" last && contains "q/Esc Home" last) "scrolled rows/help inaccessible"
  expect (Loam.ActualDate.daysBetween? "2026-09-08" "2026-10-15" == some 37) "distance 37"
  expect (Loam.ActualDate.daysBetween? "2024-02-28" "2024-03-01" == some 2) "leap distance"
  expect (Loam.ActualDate.daysBetween? "2026-12-31" "2027-01-01" == some 1) "year distance"
  expect (Loam.ActualDate.daysBetween? "2026-09-08" "2026-09-08" == some 0) "same date"
  expect (Loam.ActualDate.daysBetween? "2026-10-15" "2026-09-08" == some (-37)) "signed distance"
  expect ((Loam.ActualDate.daysBetween? "2026-02-29" "2026-10-15").isNone) "invalid day accepted"
  let presets := [{ name := "Pension", boundaries := ["2026-08-14", "2026-10-15"] }]
  let home := Loam.Tui.Main.initialState "2026-10-08"
  let shifted := { home with selectedDate := "2027-01-01" }
  -- Home date never enters shared current-window selection.
  expect (home.selectedDate != shifted.selectedDate) "fixture must move Home focus"
  match Loam.BoundaryPresetConfig.currentWindowFor? presets "2026-09-08" with
  | .error message => throw (IO.userError message)
  | .ok window =>
    expect (window.start == "2026-08-14" && window.endExclusive == "2026-10-15")
      "current preset was redefined by Home focus"
  expect (!(Loam.BoundaryPresetConfig.currentWindowFor? (presets ++ presets) "2026-09-08").isOk)
    "ambiguous preset accepted"
  IO.println "Cycle Budget: derived funding summary, CurrentCoverage-owned future pressure, direct actions, scrolling and dates passed."
