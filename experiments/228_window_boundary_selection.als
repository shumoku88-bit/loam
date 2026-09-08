module experiments/observation_228_window_boundary_selection

open util/ordering[Day] as ord

sig Day {}

abstract sig Cadence {}
one sig Monthly, BiMonthly extends Cadence {}

abstract sig BoundarySource {
  boundaries: set Day,
  cadence: lone Cadence
}
one sig Pension, Salary, Custom extends BoundarySource {}

one sig Context {
  selected: one Day,
  source: lone BoundarySource
}

fun atOrBefore[s: BoundarySource, d: Day] : set Day {
  { b: s.boundaries | ord/lte[b, d] }
}

fun after[s: BoundarySource, d: Day] : set Day {
  { b: s.boundaries | ord/lt[d, b] }
}

fun startFor[s: BoundarySource, d: Day] : set Day {
  { b: atOrBefore[s, d] |
      no later: atOrBefore[s, d] | ord/lt[b, later] }
}

fun endFor[s: BoundarySource, d: Day] : set Day {
  { b: after[s, d] |
      no earlier: after[s, d] | ord/lt[earlier, b] }
}

pred windowDefined[s: BoundarySource, d: Day] {
  one startFor[s, d]
  one endFor[s, d]
  ord/lt[startFor[s, d], endFor[s, d]]
}

pred representativeHousehold {
  some disj d0, d1, d2, d3, d4, d5: Day |
    ord/lt[d0, d1] and ord/lt[d1, d2] and ord/lt[d2, d3] and
    ord/lt[d3, d4] and ord/lt[d4, d5] and
    Pension.boundaries = d0 + d4 and
    Pension.cadence = BiMonthly and
    Salary.boundaries = d1 + d3 + d5 and
    Salary.cadence = Monthly and
    Custom.boundaries = d0 + d2 + d5 and
    no Custom.cadence and
    Context.selected = d2 and
    Context.source = Pension and
    windowDefined[Pension, d2] and
    windowDefined[Salary, d2]
}

pred customWithoutCadenceStillSelects {
  some disj d0, d1, d2, d3, d4: Day |
    ord/lt[d0, d1] and ord/lt[d1, d2] and ord/lt[d2, d3] and ord/lt[d3, d4] and
    Custom.boundaries = d0 + d1 + d4 and
    no Custom.cadence and
    Context.selected = d2 and
    Context.source = Custom and
    startFor[Custom, d2] = d1 and
    endFor[Custom, d2] = d4
}

pred sameCadenceCanYieldDifferentWindows {
  some disj d0, d1, d2, d3, d4: Day |
    ord/lt[d0, d1] and ord/lt[d1, d2] and ord/lt[d2, d3] and ord/lt[d3, d4] and
    Pension.cadence = BiMonthly and
    Custom.cadence = BiMonthly and
    Pension.boundaries = d0 + d4 and
    Custom.boundaries = d1 + d3 and
    windowDefined[Pension, d2] and
    windowDefined[Custom, d2] and
    (startFor[Pension, d2] != startFor[Custom, d2] or
     endFor[Pension, d2] != endFor[Custom, d2])
}

pred overlappingBoundarySourcesNeedSourceChoice {
  some disj d0, d1, d2, d3, d4: Day |
    ord/lt[d0, d1] and ord/lt[d1, d2] and ord/lt[d2, d3] and ord/lt[d3, d4] and
    Pension.boundaries = d0 + d4 and
    Salary.boundaries = d1 + d3 and
    windowDefined[Pension, d2] and
    windowDefined[Salary, d2] and
    startFor[Pension, d2] != startFor[Salary, d2]
}

pred incompleteFutureLeavesWindowUndefined {
  some disj d0, d1, d2: Day |
    ord/lt[d0, d1] and ord/lt[d1, d2] and
    Pension.boundaries = d0 + d1 and
    Context.selected = d2 and
    Context.source = Pension and
    one startFor[Pension, d2] and
    no endFor[Pension, d2] and
    not windowDefined[Pension, d2]
}

assert AdjacentBoundaryWindowIsUnique {
  all s: BoundarySource, d: Day |
    lone startFor[s, d] and lone endFor[s, d]
}

assert DefinedWindowContainsSelectedDate {
  all s: BoundarySource, d: Day |
    windowDefined[s, d] implies
      ord/lte[startFor[s, d], d] and ord/lt[d, endFor[s, d]]
}

assert SameBoundarySetYieldsSameWindowRegardlessOfSourceName {
  all disj left, right: BoundarySource, d: Day |
    left.boundaries = right.boundaries implies
      startFor[left, d] = startFor[right, d] and
      endFor[left, d] = endFor[right, d]
}

run representativeHousehold for exactly 6 Day
run customWithoutCadenceStillSelects for exactly 5 Day
run sameCadenceCanYieldDifferentWindows for exactly 5 Day
run overlappingBoundarySourcesNeedSourceChoice for exactly 5 Day
run incompleteFutureLeavesWindowUndefined for exactly 3 Day
check AdjacentBoundaryWindowIsUnique for 7 Day
check DefinedWindowContainsSelectedDate for 7 Day
check SameBoundarySetYieldsSameWindowRegardlessOfSourceName for 7 Day
