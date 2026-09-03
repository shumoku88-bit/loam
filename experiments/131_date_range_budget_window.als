module experiments/observation_131_date_range_budget_window

abstract sig Purpose {}
one sig Food extends Purpose {}

abstract sig TemporalFact {
  day: one Int,
  qty: one Int
}

abstract sig Actual extends TemporalFact {}
abstract sig Scheduled extends TemporalFact {}

one sig ActualEarly, ActualBoundary extends Actual {}
one sig ScheduledEarly, ScheduledBoundary, ScheduledLate extends Scheduled {}

-- Window is experiment-local query context scaffolding, not proposed canonical
-- household state. The labels below intentionally carry no semantics beyond
-- their resolved [start, end) endpoints and independent Capacity authority.
abstract sig Window {
  start: one Int,
  end: one Int,
  capacity: Purpose -> one Int
}

one sig Monthly, CustomSame, SameRangeOtherCapacity,
        Pension, HalfYear, Next extends Window {}

fun capacityAt[w: Window, p: Purpose]: one Int {
  p.(w.capacity)
}

pred inWindow[w: Window, f: TemporalFact] {
  f.day >= w.start
  f.day < w.end
}

fun consumption[w: Window, p: Purpose]: one Int {
  sum f: Actual | inWindow[w, f] => f.qty else 0
}

fun commitment[w: Window, p: Purpose]: one Int {
  sum f: Scheduled | inWindow[w, f] => f.qty else 0
}

fun remaining[w: Window, p: Purpose]: one Int {
  sub[capacityAt[w, p], consumption[w, p]]
}

fun headroom[w: Window, p: Purpose]: one Int {
  sub[remaining[w, p], commitment[w, p]]
}

fact FixedTemporalEvidence {
  ActualEarly.day = 1
  ActualEarly.qty = 2

  ActualBoundary.day = 4
  ActualBoundary.qty = 1

  ScheduledEarly.day = 2
  ScheduledEarly.qty = 3

  ScheduledBoundary.day = 4
  ScheduledBoundary.qty = 5

  ScheduledLate.day = 5
  ScheduledLate.qty = 7

  all f: TemporalFact | f.qty > 0
}

fact FixedWindowQueries {
  -- A monthly-looking query and a custom query resolve to exactly the same
  -- half-open interval and the same independent Capacity authority.
  Monthly.start = 1
  Monthly.end = 4
  capacityAt[Monthly, Food] = 10

  CustomSame.start = 1
  CustomSame.end = 4
  capacityAt[CustomSame, Food] = 10

  -- Same DateRange, different allocation authority. This is the pressure that
  -- prevents DateRange from silently becoming Capacity authority itself.
  SameRangeOtherCapacity.start = 1
  SameRangeOtherCapacity.end = 4
  capacityAt[SameRangeOtherCapacity, Food] = 12

  -- Pension-like two-period focus, a longer half-year-like focus, and the
  -- immediately adjacent range. The labels are fixtures only.
  Pension.start = 0
  Pension.end = 5
  capacityAt[Pension, Food] = 20

  HalfYear.start = 0
  HalfYear.end = 6
  capacityAt[HalfYear, Food] = 30

  Next.start = 4
  Next.end = 6
  capacityAt[Next, Food] = 15
}

fact ValidWindows {
  all w: Window | {
    w.start < w.end
    all p: Purpose | capacityAt[w, p] >= 0
  }
}

pred differentLabelsCollapseToSameRangeProjection {
  Monthly.start = CustomSame.start
  Monthly.end = CustomSame.end
  capacityAt[Monthly, Food] = capacityAt[CustomSame, Food]
  consumption[Monthly, Food] = consumption[CustomSame, Food]
  commitment[Monthly, Food] = commitment[CustomSame, Food]
  remaining[Monthly, Food] = remaining[CustomSame, Food]
  headroom[Monthly, Food] = headroom[CustomSame, Food]
}

pred selectedScheduledChangesWithRange {
  commitment[Monthly, Food] = 3
  commitment[Pension, Food] = 8
  commitment[HalfYear, Food] = 15
  commitment[Next, Food] = 12
}

pred boundaryBelongsToNextNotMonthly {
  not inWindow[Monthly, ActualBoundary]
  not inWindow[Monthly, ScheduledBoundary]
  inWindow[Next, ActualBoundary]
  inWindow[Next, ScheduledBoundary]
}

pred sameFactAppearsInOverlappingWindowsWithoutCopy {
  inWindow[Monthly, ScheduledEarly]
  inWindow[Pension, ScheduledEarly]
  inWindow[HalfYear, ScheduledEarly]
}

pred sameRangeDifferentCapacityChangesBudgetAnswer {
  Monthly.start = SameRangeOtherCapacity.start
  Monthly.end = SameRangeOtherCapacity.end
  consumption[Monthly, Food] = consumption[SameRangeOtherCapacity, Food]
  commitment[Monthly, Food] = commitment[SameRangeOtherCapacity, Food]
  headroom[Monthly, Food] != headroom[SameRangeOtherCapacity, Food]
}

-- Equal endpoints determine temporal membership and therefore the selected
-- Actual / Scheduled quantities. No Cycle identity is needed for this part.
assert DateRangeDeterminesTemporalSelection {
  all w1, w2: Window |
    (w1.start = w2.start and w1.end = w2.end) implies {
      { f: TemporalFact | inWindow[w1, f] } =
        { f: TemporalFact | inWindow[w2, f] }
      all p: Purpose | {
        consumption[w1, p] = consumption[w2, p]
        commitment[w1, p] = commitment[w2, p]
      }
    }
}

-- Half-open adjacency means a fact exactly at the boundary belongs to Next,
-- not to both selected windows.
assert HalfOpenAdjacentWindowsDoNotDoubleCount {
  no f: TemporalFact |
    inWindow[Monthly, f] and inWindow[Next, f]
}

-- Deliberately too strong: endpoint equality cannot determine Capacity-derived
-- answers because Capacity remains independent allocation authority.
assert DateRangeAloneDeterminesFullBudgetProjection {
  all w1, w2: Window |
    (w1.start = w2.start and w1.end = w2.end) implies
      all p: Purpose | {
        remaining[w1, p] = remaining[w2, p]
        headroom[w1, p] = headroom[w2, p]
      }
}

-- Once both DateRange and the independent Capacity authority are fixed, the
-- selected bounded budget projection is fixed. Distinct query-context identity
-- adds no answer in this specimen.
assert DateRangePlusCapacityDeterminesBudgetProjection {
  all w1, w2: Window |
    (w1.start = w2.start and
     w1.end = w2.end and
     (all p: Purpose | capacityAt[w1, p] = capacityAt[w2, p])) implies
      all p: Purpose | {
        consumption[w1, p] = consumption[w2, p]
        commitment[w1, p] = commitment[w2, p]
        remaining[w1, p] = remaining[w2, p]
        headroom[w1, p] = headroom[w2, p]
      }
}

run differentLabelsCollapseToSameRangeProjection for 6 Int
run selectedScheduledChangesWithRange for 6 Int
run boundaryBelongsToNextNotMonthly for 6 Int
run sameFactAppearsInOverlappingWindowsWithoutCopy for 6 Int
run sameRangeDifferentCapacityChangesBudgetAnswer for 6 Int
check DateRangeDeterminesTemporalSelection for 6 Int
check HalfOpenAdjacentWindowsDoNotDoubleCount for 6 Int
check DateRangeAloneDeterminesFullBudgetProjection for 6 Int
check DateRangePlusCapacityDeterminesBudgetProjection for 6 Int
