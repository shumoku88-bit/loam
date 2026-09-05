import Loam.Observations.Observation183
import Lean.Elab.Tactic.Omega

namespace Loam.Observation184

set_option autoImplicit false

open Loam.Observation183

/-!
# Observation 184 — multi-day conservative funding from date boundaries

Observation 183 established the exact conservative additional opening quantity
for one fixed date when same-day inflow/outflow order is unknown.

This observation asks whether those one-day requirements compose across an
ordered list of distinct date buckets without introducing time-of-day.

The list order represents already-known date order only. Within each date,
`SameDayPressure` keeps the same unknown-order semantics from Observation 183.
-/

/-- Every date bucket retains nonnegative directional magnitudes. -/
def WellFormedPeriod : List SameDayPressure → Prop
  | [] => True
  | day :: rest => day.WellFormed ∧ WellFormedPeriod rest

/-- Observation-local maximum, kept explicit to avoid earning a general abstraction. -/
def largerRequirement (a b : Int) : Int :=
  if a ≤ b then b else a

/-- The explicit maximum is below a bound exactly when both inputs are. -/
theorem largerRequirement_le_iff (a b bound : Int) :
    largerRequirement a b ≤ bound ↔ a ≤ bound ∧ b ≤ bound := by
  unfold largerRequirement
  by_cases hOrder : a ≤ b
  · simp [hOrder]
    omega
  · simp [hOrder]
    omega

/--
The conservative additional opening quantity for a whole ordered period.

For an empty horizon the only requirement is that the initial balance itself is
nonnegative. For a nonempty horizon, the same additional opening quantity must
cover both:

* the current date's unknown within-day order; and
* every later date after the current date's completed signed net has become part
  of the later opening quantity.

No later top-up is introduced here. `additional` is one quantity supplied before
the whole period starts.
-/
def requiredPeriodAdditionalOpening : Int → List SameDayPressure → Int
  | opening, [] => if 0 ≤ opening then 0 else -opening
  | opening, day :: rest =>
      largerRequirement
        (requiredAdditionalOpening opening day)
        (requiredPeriodAdditionalOpening (opening + day.net) rest)

/--
Period safety keeps the same unknown-order quantification inside each date while
using completed earlier-date net as part of the next date's opening quantity.
-/
def SafeForUnknownOrderPeriod : Int → Int → List SameDayPressure → Prop
  | opening, additional, [] =>
      0 ≤ additional ∧ 0 ≤ opening + additional
  | opening, additional, day :: rest =>
      SafeForUnknownOrder opening additional day ∧
        SafeForUnknownOrderPeriod (opening + day.net) additional rest

/-- The period requirement is always nonnegative. -/
theorem requiredPeriodAdditionalOpening_nonnegative
    (opening : Int) (days : List SameDayPressure) :
    0 ≤ requiredPeriodAdditionalOpening opening days := by
  induction days generalizing opening with
  | nil =>
      simp [requiredPeriodAdditionalOpening]
      by_cases hOpening : 0 ≤ opening
      · simp [hOpening]
      · simp [hOpening]
        omega
  | cons day rest ih =>
      simp only [requiredPeriodAdditionalOpening]
      have hToday := requiredAdditionalOpening_nonnegative opening day
      have hRest := ih (opening + day.net)
      unfold largerRequirement
      by_cases hOrder :
          requiredAdditionalOpening opening day ≤
            requiredPeriodAdditionalOpening (opening + day.net) rest
      · simp [hOrder]
        exact hRest
      · simp [hOrder]
        exact hToday

/--
The recursive period requirement is exact: it is the minimum single additional
opening quantity that is safe for every date and every unknown within-day
progress state.
-/
theorem safeForUnknownOrderPeriod_iff_required_le
    (opening additional : Int)
    (days : List SameDayPressure)
    (hDays : WellFormedPeriod days) :
    SafeForUnknownOrderPeriod opening additional days ↔
      requiredPeriodAdditionalOpening opening days ≤ additional := by
  induction days generalizing opening with
  | nil =>
      simp [SafeForUnknownOrderPeriod, requiredPeriodAdditionalOpening]
      by_cases hOpening : 0 ≤ opening
      · simp [hOpening]
        omega
      · simp [hOpening]
        omega
  | cons day rest ih =>
      rcases hDays with ⟨hDay, hRest⟩
      simp only [SafeForUnknownOrderPeriod, requiredPeriodAdditionalOpening]
      rw [safeForUnknownOrder_iff_required_le opening additional day hDay]
      rw [ih (opening := opening + day.net) hRest]
      exact
        (largerRequirement_le_iff
          (requiredAdditionalOpening opening day)
          (requiredPeriodAdditionalOpening (opening + day.net) rest)
          additional).symm

/-- Any single initial addition below the period requirement fails the guarantee. -/
theorem below_period_required_is_not_safe
    (opening additional : Int)
    (days : List SameDayPressure)
    (hDays : WellFormedPeriod days)
    (hBelow : additional < requiredPeriodAdditionalOpening opening days) :
    ¬ SafeForUnknownOrderPeriod opening additional days := by
  intro hSafe
  have hRequired :=
    (safeForUnknownOrderPeriod_iff_required_le opening additional days hDays).1 hSafe
  omega

/-! ## Date boundaries are usable order evidence -/

private def sameDateBalanced : List SameDayPressure :=
  [⟨10, 10⟩]

private def priorDateThenOutflow : List SameDayPressure :=
  [⟨10, 0⟩, ⟨0, 10⟩]

/-- Both presentations contain the same total inflow and outflow magnitudes. -/
def totalInflow : List SameDayPressure → Int
  | [] => 0
  | day :: rest => day.inflow + totalInflow rest

/-- Total outflow magnitude across the observed date buckets. -/
def totalOutflow : List SameDayPressure → Int
  | [] => 0
  | day :: rest => day.outflow + totalOutflow rest

/-- Grouping the same total quantities across a date boundary preserves totals. -/
theorem same_totals_across_date_boundary :
    totalInflow sameDateBalanced = totalInflow priorDateThenOutflow ∧
      totalOutflow sameDateBalanced = totalOutflow priorDateThenOutflow := by
  decide

/--
Yet the funding requirement differs. Same-date inflow cannot be assumed first,
while a completed prior-date inflow is valid opening quantity for the later date.
-/
theorem date_boundary_can_reduce_conservative_requirement :
    requiredPeriodAdditionalOpening 0 sameDateBalanced = 10 ∧
      requiredPeriodAdditionalOpening 0 priorDateThenOutflow = 0 := by
  decide

/-- Both periods also have the same final signed net. -/
theorem same_final_net_across_date_boundary :
    totalInflow sameDateBalanced - totalOutflow sameDateBalanced =
      totalInflow priorDateThenOutflow - totalOutflow priorDateThenOutflow := by
  decide

/-!
Observation 184 therefore earns a narrow composition rule:

```text
one initial additional quantity
+ date-ordered directional Scheduled subtotals
+ unknown order only inside each date
-> exact conservative requirement for the whole period
```

The recurrence is:

```text
R(opening, []) = max(0, -opening)
R(opening, day :: rest)
  = max(
      same-day requirement(opening, day),
      R(opening + day.net, rest)
    )
```

The key semantic result is that a date boundary itself carries usable order
evidence. A prior date's completed inflow may reduce a later date's requirement;
a same-date inflow may not do so when intra-day order is unknown.

No hour/minute timestamp, hidden event sequence, later top-up policy, Backing
relation, safe-to-spend authority, or production funding command is earned.
-/

end Loam.Observation184
