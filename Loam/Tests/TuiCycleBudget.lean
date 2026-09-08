import Loam.Tui.CycleBudget
import Loam.Tui.HraHome

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)
private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))
private def contains (needle haystack : String) : Bool := (haystack.splitOn needle).length > 1
private def q := Quantity.ofQuanta

private def fixture : Loam.CycleBudgetReview.Snapshot :=
  { observedAt := "2026-09-08"
    window := .ok { source := "Pension", start := "2026-08-14", endExclusive := "2026-10-15" }
    coverage := .ok {
      currentWindowStart := "2026-08-14"
      observedAt := "2026-09-08"
      endExclusive := "2026-10-15"
      rows := [{ purpose := ⟨"食費:ストック"⟩, entitlement := q 111, consumption := q 222, remaining := q (-1180), commitment := q 333, headroom := q (-444) }]
      scheduledFrontier := some { unmanaged := q 10, unrouted := q 20, unresolvedEligibility := q 4810 } }
    physical := .ok { rows := [
      { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, quantity := q 909 },
      { coordinate := ⟨⟨"yucho"⟩, ⟨"jpy"⟩⟩, quantity := q 555 }] }
    selection := .ok [⟨⟨"cash"⟩, ⟨"jpy"⟩⟩]
    -- Deliberately inconsistent sentinels: rendering must not rederive supplied answers.
    funding := .ok {
      measure := ⟨"jpy"⟩
      budgetableBacking := q 76389
      remainingAssigned := q 47068
      residualBeforeUnresolved := q 29321
      unmanagedFuturePressure := q 1234
      unroutedFuturePressure := q 2345
      unresolvedFuturePressure := q 4810 } }

def main : IO Unit := do
  let bounds : Bounds := { width := 100, height := 40 }
  let state : Loam.Tui.CycleBudget.State := { snapshot := fixture }
  let rendered := text (Loam.Tui.CycleBudget.view bounds state)
  for value in ["Budget / Pension Cycle", "2026-08-14 -> 2026-10-15", "Observed 2026-09-08",
      "37 days to next boundary", "111", "222", "-1180", "333", "-444", "食費:ストック",
      "76389", "47068", "29321", "4810", "1234", "2345", "Residual before unresolved",
      "Unresolved future pressure", "Unrouted future pressure", "Unmanaged future pressure",
      "cash: 909 jpy  [budget backing]", "yucho: 555 jpy  [outside budget backing]"] do
    expect (contains value rendered) ("missing supplied answer: " ++ value)
  expect (!(contains "Safe to spend" rendered) && !(contains "Available" rendered))
    "residual was promoted to spending permission"
  let missing : Loam.Tui.CycleBudget.State := { snapshot := { fixture with
    selection := .error "not configured", funding := .error "not configured" } }
  let missingText := text (Loam.Tui.CycleBudget.view bounds missing)
  for value in ["Funding unavailable: not configured", "-1180", "cash: 909 jpy",
      "backing selection unavailable", "4810"] do
    expect (contains value missingText) ("optional failure hid evidence: " ++ value)
  expect (!(contains "[outside budget backing]" missingText)) "missing selection inferred outside"
  let failed : Loam.Tui.CycleBudget.State := { snapshot := { fixture with
    coverage := .error "bad evidence", funding := .error "bad evidence" } }
  let failedText := text (Loam.Tui.CycleBudget.view bounds failed)
  expect (contains "CurrentCoverage unavailable" failedText && contains "cash: 909" failedText)
    "coverage failure hid physical evidence"
  expect (Loam.Tui.CycleBudget.isHomeEntrance (.input 'c')) "Home c entrance missing"
  expect (!(Loam.Tui.CycleBudget.isHomeEntrance (.input 'e'))) "raw Capacity alias stolen"
  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'b')).2 == .home) "back is not Home"
  expect ((Loam.Tui.CycleBudget.update bounds state .escape).2 == .home) "Esc is not Home"
  expect (contains "u route" rendered) "footer missing u route"
  expect (contains "g grant" rendered) "footer missing g grant"
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
              quantity := q 4810 } ] }
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
    rows := [{ purpose := ⟨"食費"⟩, entitlement := q 1000, consumption := q 200, remaining := q 800, commitment := q 300, headroom := q 500 }]
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
    rows := [{ purpose := ⟨"食費"⟩, entitlement := q 1000, consumption := q 1500, remaining := q (-500), commitment := q (-700), headroom := q 200 }]
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
    rows := [{ purpose := ⟨"固定費予定"⟩, entitlement := q 17108, consumption := q 8378, remaining := q 8730, commitment := q 12558, headroom := q (-3828) }]
    scheduledFrontier := none
  }
  let stateNowPos : Loam.Tui.CycleBudget.State := { snapshot := { fixture with coverage := .ok nowPosHeadroomNegCoverage } }
  let (_, intentNowPos) := Loam.Tui.CycleBudget.update bounds stateNowPos (.input 'g')
  match intentNowPos with
  | .grant row =>
      expect (row.purpose.token == "固定費予定") "purpose token mismatch"
      expect (row.headroom.quanta == -3828) "headroom mismatch"
  | _ => throw (IO.userError "expected grant intent for After-known negative")

  -- 4. Multiple shortages -> human selection required in picker
  let multiShortagesCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows :=
      [ { purpose := ⟨"固定費予定"⟩, entitlement := q 17108, consumption := q 8378, remaining := q 8730, commitment := q 12558, headroom := q (-3828) }
      , { purpose := ⟨"タバコ"⟩, entitlement := q 10000, consumption := q 8000, remaining := q 2000, commitment := q 5000, headroom := q (-3000) }
      , { purpose := ⟨"食費"⟩, entitlement := q 30000, consumption := q 10000, remaining := q 20000, commitment := q 0, headroom := q 20000 }
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
  expect (contains "固定費予定" pickerView && contains "-3828" pickerView) "first candidate"
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

  -- Picker cancel with b
  let (stateCancelB, intentCancelB) := Loam.Tui.CycleBudget.update bounds statePicker (.input 'b')
  expect (stateCancelB.submode == .normal) "submode reset on b"
  expect (intentCancelB == .stay) "b must stay"

  expect ((Loam.Tui.CycleBudget.update bounds state (.input 'r')).2 == .stay) "r emitted write action"
  let small : Bounds := { width := 80, height := 12 }
  let down := (Loam.Tui.CycleBudget.update small state .down).1
  expect (down.scroll == 1) "small terminal cannot scroll"
  expect ((Loam.Tui.CycleBudget.view small down).lines.length < small.height) "footer overflow"
  let last := text (Loam.Tui.CycleBudget.view small { state with scroll := 999 })
  expect (contains "-1180" last && contains "b Home" last) "scrolled rows/help inaccessible"
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
  IO.println "Read-only Cycle Budget: supplied mappings, degraded layers, navigation, scrolling and dates passed."
