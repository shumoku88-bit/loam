module experiments/observation_133_overlapping_budget_views

abstract sig Purpose {}
one sig Food extends Purpose {}

abstract sig TemporalFact {
  day: one Int,
  qty: one Int
}
abstract sig Actual extends TemporalFact {}
abstract sig Scheduled extends TemporalFact {}

one sig ActualShared, ActualLater extends Actual {}
one sig ScheduledShared, ScheduledLater extends Scheduled {}

-- Experiment-local resolved budget views. These are query/application
-- scaffolding, not proposed canonical household objects or role-bearing facts.
abstract sig View {
  start: one Int,
  end: one Int,
  capacity: Purpose -> one Int
}
one sig PensionView, PensionViewCopy, MonthView, HalfView extends View {}

-- A dashboard may show several views at once while choosing one of them for a
-- scalar operating question such as "what is headroom in the budget I am
-- currently using?". Selection is experiment-local query/config state.
abstract sig Dashboard {
  visible: set View,
  selected: one View
}
one sig UsePension, UseMonth, UsePensionMinimal, UsePensionCopy extends Dashboard {}

fun capacityAt[v: View, p: Purpose]: one Int {
  p.(v.capacity)
}

pred inView[v: View, f: TemporalFact] {
  f.day >= v.start
  f.day < v.end
}

fun consumption[v: View, p: Purpose]: one Int {
  sum f: Actual | inView[v, f] => f.qty else 0
}

fun commitment[v: View, p: Purpose]: one Int {
  sum f: Scheduled | inView[v, f] => f.qty else 0
}

fun remaining[v: View, p: Purpose]: one Int {
  sub[capacityAt[v, p], consumption[v, p]]
}

fun headroom[v: View, p: Purpose]: one Int {
  sub[remaining[v, p], commitment[v, p]]
}

fun unionConsumption[v1, v2: View, p: Purpose]: one Int {
  sum f: Actual | (inView[v1, f] or inView[v2, f]) => f.qty else 0
}

fun unionCommitment[v1, v2: View, p: Purpose]: one Int {
  sum f: Scheduled | (inView[v1, f] or inView[v2, f]) => f.qty else 0
}

fun operatingHeadroom[d: Dashboard, p: Purpose]: one Int {
  headroom[d.selected, p]
}

fact FixedEvidence {
  ActualShared.day = 2
  ActualShared.qty = 3
  ActualLater.day = 4
  ActualLater.qty = 2

  ScheduledShared.day = 2
  ScheduledShared.qty = 4
  ScheduledLater.day = 4
  ScheduledLater.qty = 5

  all f: TemporalFact | f.qty > 0
}

fact FixedViews {
  PensionView.start = 0
  PensionView.end = 4
  capacityAt[PensionView, Food] = 20

  -- Identity-distinct copy with the same selected definition.
  PensionViewCopy.start = 0
  PensionViewCopy.end = 4
  capacityAt[PensionViewCopy, Food] = 20

  MonthView.start = 1
  MonthView.end = 3
  capacityAt[MonthView, Food] = 10

  HalfView.start = 0
  HalfView.end = 6
  capacityAt[HalfView, Food] = 30

  all v: View | {
    v.start < v.end
    all p: Purpose | capacityAt[v, p] >= 0
  }
}

fact FixedDashboards {
  UsePension.visible = PensionView + MonthView + HalfView
  UsePension.selected = PensionView

  UseMonth.visible = PensionView + MonthView + HalfView
  UseMonth.selected = MonthView

  UsePensionMinimal.visible = PensionView
  UsePensionMinimal.selected = PensionView

  UsePensionCopy.visible = PensionViewCopy + MonthView + HalfView
  UsePensionCopy.selected = PensionViewCopy

  all d: Dashboard | d.selected in d.visible
}

pred overlappingViewsReuseSameEvidence {
  inView[PensionView, ActualShared]
  inView[MonthView, ActualShared]
  inView[HalfView, ActualShared]
  inView[PensionView, ScheduledShared]
  inView[MonthView, ScheduledShared]
  inView[HalfView, ScheduledShared]
}

pred sameVisibleViewsDifferentSelectionDifferentOperatingAnswer {
  UsePension.visible = UseMonth.visible
  operatingHeadroom[UsePension, Food] = 13
  operatingHeadroom[UseMonth, Food] = 3
  operatingHeadroom[UsePension, Food] != operatingHeadroom[UseMonth, Food]
}

pred extraUnselectedViewsDoNotChangeSelectedAnswer {
  UsePension.visible != UsePensionMinimal.visible
  UsePension.selected = UsePensionMinimal.selected
  operatingHeadroom[UsePension, Food] = operatingHeadroom[UsePensionMinimal, Food]
}

pred equalSelectedDefinitionDifferentIdentitySameAnswer {
  UsePension.selected != UsePensionCopy.selected
  UsePension.selected.start = UsePensionCopy.selected.start
  UsePension.selected.end = UsePensionCopy.selected.end
  capacityAt[UsePension.selected, Food] = capacityAt[UsePensionCopy.selected, Food]
  operatingHeadroom[UsePension, Food] = operatingHeadroom[UsePensionCopy, Food]
}

-- Deliberately too strong: adding projections from overlapping windows counts
-- shared evidence more than once. A dashboard view set is not an additive
-- partition merely because every member is individually meaningful.
assert SummingOverlappingViewConsumptionEqualsUnion {
  add[consumption[PensionView, Food], consumption[MonthView, Food]] =
    unionConsumption[PensionView, MonthView, Food]
}

assert SummingOverlappingViewCommitmentEqualsUnion {
  add[commitment[PensionView, Food], commitment[MonthView, Food]] =
    unionCommitment[PensionView, MonthView, Food]
}

-- Deliberately too strong: the same visible views do not determine one scalar
-- operating answer if the user/application selects a different view to answer
-- that question.
assert VisibleViewSetDeterminesOperatingHeadroom {
  all d1, d2: Dashboard |
    d1.visible = d2.visible implies
      all p: Purpose | operatingHeadroom[d1, p] = operatingHeadroom[d2, p]
}

-- Once the selected view's information-equivalent definition is fixed, extra
-- unselected views and selected-view identity add no selected operating answer
-- in this bounded model.
assert SelectedViewDefinitionDeterminesOperatingHeadroom {
  all d1, d2: Dashboard |
    (d1.selected.start = d2.selected.start and
     d1.selected.end = d2.selected.end and
     (all p: Purpose |
       capacityAt[d1.selected, p] = capacityAt[d2.selected, p])) implies
      all p: Purpose | operatingHeadroom[d1, p] = operatingHeadroom[d2, p]
}

run overlappingViewsReuseSameEvidence for 6 Int
run sameVisibleViewsDifferentSelectionDifferentOperatingAnswer for 6 Int
run extraUnselectedViewsDoNotChangeSelectedAnswer for 6 Int
run equalSelectedDefinitionDifferentIdentitySameAnswer for 6 Int

check SummingOverlappingViewConsumptionEqualsUnion for 6 Int
check SummingOverlappingViewCommitmentEqualsUnion for 6 Int
check VisibleViewSetDeterminesOperatingHeadroom for 6 Int
check SelectedViewDefinitionDeterminesOperatingHeadroom for 6 Int
