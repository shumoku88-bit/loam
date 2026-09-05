import Lean.Elab.Tactic.Omega

namespace Loam.Observation183

set_option autoImplicit false

/-!
# Observation 183 — conservative same-day funding without time-of-day

PR #379 made current-open Scheduled effects visible at selected balance
coordinates. That projection deliberately stops at signed aggregate effects.

This observation asks one stronger question for a single fixed
`Locus × Measure × ScheduledDate` bucket:

> If positive and negative Scheduled effects share the same date, but their
> within-day order is unknown, can the minimum additional opening quantity that
> guarantees a nonnegative balance be derived without inventing time-of-day?

The observation works only in exact quanta for one already-fixed coordinate and
measure. `inflow` and `outflow` are directional subtotals, not new Core domain
entities. Both are required to be nonnegative by the theorem premises.
-/

/-- Observation-local directional subtotals for one selected balance coordinate on one day. -/
structure SameDayPressure where
  inflow : Int
  outflow : Int
deriving Repr, DecidableEq

namespace SameDayPressure

/-- Directional subtotals are magnitudes, so both must be nonnegative. -/
def WellFormed (day : SameDayPressure) : Prop :=
  0 ≤ day.inflow ∧ 0 ≤ day.outflow

/-- The ordinary signed daily aggregate loses the directional split. -/
def net (day : SameDayPressure) : Int :=
  day.inflow - day.outflow

end SameDayPressure

/--
The smallest nonnegative additional opening quantity suggested by the
all-outflow-before-any-inflow extreme.

Same-day inflow is intentionally absent from this definition: when no intra-day
order is known, it cannot safely be assumed to arrive before the day's outflow.
-/
def requiredAdditionalOpening (opening : Int) (day : SameDayPressure) : Int :=
  if day.outflow ≤ opening then 0 else day.outflow - opening

/--
Order-free safety quantifies over every aggregate progress point compatible with
the day's directional totals.

`received` and `paid` do not introduce timestamps. They only range over how much
of the already-known same-day inflow/outflow may have happened so far. In
particular, `received = 0` and `paid = day.outflow` includes the conservative
extreme where all outflow occurs before any inflow.
-/
def SafeForUnknownOrder
    (opening additional : Int) (day : SameDayPressure) : Prop :=
  0 ≤ additional ∧
    ∀ received paid : Int,
      0 ≤ received →
      received ≤ day.inflow →
      0 ≤ paid →
      paid ≤ day.outflow →
      0 ≤ opening + additional + received - paid

/-- The candidate requirement is always nonnegative. -/
theorem requiredAdditionalOpening_nonnegative
    (opening : Int) (day : SameDayPressure) :
    0 ≤ requiredAdditionalOpening opening day := by
  unfold requiredAdditionalOpening
  by_cases hCovered : day.outflow ≤ opening
  · simp [hCovered]
  · simp [hCovered]
    omega

/--
The candidate is not merely sufficient. Under nonnegative directional totals it
is exactly the minimum additional opening quantity that is safe for every
within-day progress state.
-/
theorem safeForUnknownOrder_iff_required_le
    (opening additional : Int)
    (day : SameDayPressure)
    (hDay : day.WellFormed) :
    SafeForUnknownOrder opening additional day ↔
      requiredAdditionalOpening opening day ≤ additional := by
  constructor
  · intro hSafe
    rcases hSafe with ⟨hAdditional, hProgress⟩
    have hExtreme :
        0 ≤ opening + additional + 0 - day.outflow :=
      hProgress 0 day.outflow (by omega) hDay.1 hDay.2 (by omega)
    unfold requiredAdditionalOpening
    by_cases hCovered : day.outflow ≤ opening
    · simp [hCovered]
      exact hAdditional
    · simp [hCovered]
      omega
  · intro hRequired
    constructor
    · have hNonnegative := requiredAdditionalOpening_nonnegative opening day
      omega
    · intro received paid hReceivedNonnegative hReceivedBound
        hPaidNonnegative hPaidBound
      unfold requiredAdditionalOpening at hRequired
      by_cases hCovered : day.outflow ≤ opening
      · simp [hCovered] at hRequired
        omega
      · simp [hCovered] at hRequired
        omega

/-- Any amount strictly below the candidate fails the order-free guarantee. -/
theorem below_required_is_not_safe
    (opening additional : Int)
    (day : SameDayPressure)
    (hDay : day.WellFormed)
    (hBelow : additional < requiredAdditionalOpening opening day) :
    ¬ SafeForUnknownOrder opening additional day := by
  intro hSafe
  have hRequired :=
    (safeForUnknownOrder_iff_required_le opening additional day hDay).1 hSafe
  omega

/-! ## Net-only insufficiency -/

private def idleDay : SameDayPressure :=
  ⟨0, 0⟩

private def balancedActivityDay : SameDayPressure :=
  ⟨10, 10⟩

/-- No activity and equal inflow/outflow can have the same daily net. -/
theorem same_daily_net_can_hide_directional_activity :
    idleDay.net = balancedActivityDay.net := by
  decide

/-- Yet the conservative opening requirement distinguishes them. -/
theorem same_daily_net_different_required_opening :
    requiredAdditionalOpening 0 idleDay = 0 ∧
      requiredAdditionalOpening 0 balancedActivityDay = 10 := by
  decide

/--
Changing only same-day inflow cannot reduce the conservative requirement while
within-day order remains unknown. Only opening quantity and same-day outflow
matter at this boundary.
-/
theorem same_outflow_same_requirement
    (opening inflowA inflowB outflow : Int) :
    requiredAdditionalOpening opening ⟨inflowA, outflow⟩ =
      requiredAdditionalOpening opening ⟨inflowB, outflow⟩ := by
  rfl

/-!
Observation 183 therefore earns a narrow result:

```text
unknown within-day order
+ nonnegative same-day inflow/outflow subtotals
+ one fixed balance coordinate
-> exact conservative additional opening requirement
   = max(0, outflow - opening)
```

No clock, timestamp, intra-day sequence, Balance entity, Backing relation,
Funding transaction, or safe-to-spend authority is earned.

The negative result is equally important. A signed daily net is insufficient for
this stronger question. A future practical projection that wants conservative
funding pressure must retain or derive same-day directional subtotals before
collapsing them to net Scheduled effect.
-/

end Loam.Observation183
