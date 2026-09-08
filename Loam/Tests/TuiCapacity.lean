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

private def baseRow (purpose : String) (entitlement : Int) : Loam.CapacityReview.Row :=
  { purpose := ⟨purpose⟩, entitlement := Quantity.ofQuanta entitlement }

private def coverageRow
    (purpose : String)
    (entitlement consumption remaining commitment headroom : Int) :
    Loam.CurrentCoverageReview.Row :=
  { purpose := ⟨purpose⟩
    entitlement := Quantity.ofQuanta entitlement
    consumption := Quantity.ofQuanta consumption
    remaining := Quantity.ofQuanta remaining
    commitment := Quantity.ofQuanta commitment
    headroom := Quantity.ofQuanta headroom }

private def frontier (unmanaged unrouted unresolved : Int) :
    Loam.CurrentCoverageReview.ScheduledFrontier :=
  { unmanaged := Quantity.ofQuanta unmanaged
    unrouted := Quantity.ofQuanta unrouted
    unresolvedEligibility := Quantity.ofQuanta unresolved }


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
    { rows := [food, groceries,
        { purpose := ⟨"buffer"⟩, entitlement := Quantity.ofQuanta 0 }] }
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

  -- Coverage labels are presentation-only views over the shared derived quantities.
  let ok := coverageRow "ok" 100 30 70 35 35
  let over := coverageRow "over" 20 30 (-10) 35 (-45)
  let future := coverageRow "future" 60 30 30 35 (-5)
  let coverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-15"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := [ok, over, future]
    scheduledFrontier := some (frontier 0 0 0)
  }
  let coverageState := Loam.Tui.Capacity.withCoverage coverage "preset Pension" <|
    Loam.Tui.Capacity.initial {
      rows := [baseRow "ok" 100, baseRow "over" 20, baseRow "future" 60] }
  expect (Loam.Tui.Capacity.coverageLabel coverageState ok == "OK")
    "positive current and after-known coverage was not labelled OK"
  expect (Loam.Tui.Capacity.coverageLabel coverageState over == "OVER NOW")
    "negative Remaining was not labelled OVER NOW"
  expect (Loam.Tui.Capacity.coverageLabel coverageState future == "FUTURE SHORT")
    "positive Remaining with negative Headroom was not labelled FUTURE SHORT"
  let coverageText := widgetText (Loam.Tui.Capacity.view coverageState)
  expect (contains "ok: cap 100 | now 70 | after-known 35 | OK" coverageText)
    "current coverage row quantities were not rendered"
  expect (contains "over: cap 20 | now -10 | after-known -45 | OVER NOW" coverageText)
    "over-now diagnosis was not rendered"
  expect (contains "future: cap 60 | now 30 | after-known -5 | FUTURE SHORT" coverageText)
    "future-short diagnosis was not rendered"
  expect (contains "Coverage: observed 2026-09-08 | preset Pension -> 2026-10-15" coverageText)
    "explicit configured coverage horizon was not rendered"
  expect (contains "not SafeToSpend authority" coverageText)
    "coverage surface lost its non-authority warning"

  let check := coverageRow "check" 100 30 70 35 35
  let unresolvedCoverage : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-15"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := [check]
    scheduledFrontier := some (frontier 0 0 9)
  }
  let unresolvedState := Loam.Tui.Capacity.withCoverage unresolvedCoverage "preset Pension" <|
    Loam.Tui.Capacity.initial { rows := [baseRow "check" 100] }
  expect (Loam.Tui.Capacity.coverageLabel unresolvedState check == "CHECK")
    "unresolved Scheduled eligibility was silently labelled OK"
  let unresolvedText := widgetText (Loam.Tui.Capacity.view unresolvedState)
  expect (contains "check: cap 100 | now 70 | after-known 35 | CHECK" unresolvedText)
    "CHECK diagnosis was not rendered"
  expect (contains "unresolved 9 jpy" unresolvedText)
    "unresolved Scheduled frontier was hidden"

  let unavailable := Loam.Tui.Capacity.withoutCoverage
    "no configured boundary preset contains the current date" state
  let unavailableText := widgetText (Loam.Tui.Capacity.view unavailable)
  expect (contains "Current coverage unavailable" unavailableText)
    "optional coverage refusal was not visible"
  expect (contains "food: 60 jpy" unavailableText)
    "coverage refusal hid valid all-retained Capacity"

  IO.println "TUI Capacity: navigation, transfer intent, current coverage labels, frontier visibility and safe fallback passed."
