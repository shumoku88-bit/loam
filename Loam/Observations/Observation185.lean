import Init.Data.Int.Basic

namespace Loam.Observation185

set_option autoImplicit false

/-!
# Observation 185 — typed hypothetical relief without decision authority

Household advice asks questions such as:

* what happens if one Scheduled expense is skipped;
* what happens if consumption is reduced;
* what happens if Capacity is reallocated;
* what happens if a future contribution is paused;
* what happens if an existing asset is liquidated.

Those actions can produce the same immediate JPY relief while remaining different
household meanings. This observation asks whether a read-only hypothetical layer
can expose useful consequences without collapsing those interventions into one
numeric adjustment or promoting a preference/optimizer into canonical authority.

The structures here are observation-local. They model only three derived axes:
selected liquid quantity, selected-Purpose headroom, and total wealth. They do not
claim that these three numbers are a complete household state.
-/

/-- A tiny derived view used only for the observation. -/
structure HouseholdProjection where
  liquid : Int
  selectedPurposeHeadroom : Int
  wealth : Int
  deriving Repr, DecidableEq

/--
Interventions remain typed even when some of their immediate arithmetic effects
coincide.
-/
inductive Intervention where
  | suppressScheduledExpense (amount : Nat)
  | reduceConsumption (amount : Nat)
  | reallocateCapacity (amount : Nat)
  | pauseFutureContribution (amount : Nat)
  | liquidateExistingAsset (amount : Nat)
  deriving Repr, DecidableEq

/-- Observation-local vector of derived consequences. -/
structure ReliefDelta where
  liquid : Int
  selectedPurposeHeadroom : Int
  wealth : Int
  deriving Repr, DecidableEq

private def quantity (amount : Nat) : Int := Int.ofNat amount

/--
A deliberately small consequence map.

`pauseFutureContribution` and `liquidateExistingAsset` both improve selected
liquidity in this bounded view without increasing total wealth. They still remain
distinct interventions because one changes a future transfer while the other
changes an already-held asset position.
-/
def Intervention.relief : Intervention → ReliefDelta
  | .suppressScheduledExpense amount =>
      let q := quantity amount
      ⟨q, q, q⟩
  | .reduceConsumption amount =>
      let q := quantity amount
      ⟨q, q, q⟩
  | .reallocateCapacity amount =>
      let q := quantity amount
      ⟨0, q, 0⟩
  | .pauseFutureContribution amount =>
      let q := quantity amount
      ⟨q, 0, 0⟩
  | .liquidateExistingAsset amount =>
      let q := quantity amount
      ⟨q, 0, 0⟩

/-- Apply one hypothetical consequence to a derived projection only. -/
def applyIntervention
    (state : HouseholdProjection) (intervention : Intervention) : HouseholdProjection :=
  let delta := intervention.relief
  {
    liquid := state.liquid + delta.liquid
    selectedPurposeHeadroom :=
      state.selectedPurposeHeadroom + delta.selectedPurposeHeadroom
    wealth := state.wealth + delta.wealth
  }

/-- Apply a finite hypothetical overlay in presentation order. -/
def applyScenario : HouseholdProjection → List Intervention → HouseholdProjection
  | state, [] => state
  | state, intervention :: rest =>
      applyScenario (applyIntervention state intervention) rest

/--
A read-only query result carries the canonical input back unchanged, the derived
projection, and the exact typed hypothetical overlay that produced it.
-/
structure QueryResult where
  canonical : HouseholdProjection
  projected : HouseholdProjection
  scenario : List Intervention
  deriving Repr, DecidableEq

/-- Observation-local read-only hypothetical query. -/
def query
    (canonical : HouseholdProjection) (scenario : List Intervention) : QueryResult :=
  {
    canonical := canonical
    projected := applyScenario canonical scenario
    scenario := scenario
  }

/-- Empty hypothetical input is exactly the baseline projection. -/
theorem empty_scenario_is_baseline (canonical : HouseholdProjection) :
    (query canonical []).projected = canonical := by
  rfl

/-- The query boundary never replaces its canonical input with the projection. -/
theorem query_preserves_canonical
    (canonical : HouseholdProjection) (scenario : List Intervention) :
    (query canonical scenario).canonical = canonical := by
  rfl

/-- The typed provenance of the hypothetical overlay survives the projection. -/
theorem query_preserves_scenario
    (canonical : HouseholdProjection) (scenario : List Intervention) :
    (query canonical scenario).scenario = scenario := by
  rfl

/-! ## Different shortages are different questions -/

private def headroomShortfall : HouseholdProjection :=
  {
    liquid := 1000
    selectedPurposeHeadroom := -500
    wealth := 5000
  }

/--
Capacity reallocation can repair selected-Purpose headroom without changing cash
or total wealth in this bounded view. A budget-allocation shortage is therefore
not identical to a liquid-cash shortage.
-/
theorem reallocation_can_change_headroom_without_cash_or_wealth :
    let after :=
      (query headroomShortfall [.reallocateCapacity 500]).projected
    after.liquid = headroomShortfall.liquid ∧
      after.selectedPurposeHeadroom = 0 ∧
      after.wealth = headroomShortfall.wealth := by
  decide

/-! ## Equal liquid relief does not imply equal household consequence -/

private def liquidShortfall : HouseholdProjection :=
  {
    liquid := -1000
    selectedPurposeHeadroom := 0
    wealth := 10000
  }

/--
Skipping an expense and pausing an internal future contribution can repair the
same immediate liquid shortfall while having different total-wealth consequences
in the modeled projection.
-/
theorem same_liquid_relief_can_have_different_wealth_effect :
    let expense :=
      (query liquidShortfall [.suppressScheduledExpense 1000]).projected
    let contribution :=
      (query liquidShortfall [.pauseFutureContribution 1000]).projected
    expense.liquid = contribution.liquid ∧
      expense.liquid = 0 ∧
      expense.wealth ≠ contribution.wealth := by
  decide

/-! ## Even equal projection vectors do not identify the intervention -/

/--
Pausing a future contribution and liquidating an existing asset have the same
three-axis result in this deliberately small projection, yet remain unequal typed
interventions. Derived arithmetic therefore cannot reconstruct the action that
produced it.
-/
theorem equal_projection_does_not_identify_intervention :
    let pause : Intervention := .pauseFutureContribution 1000
    let liquidation : Intervention := .liquidateExistingAsset 1000
    (query liquidShortfall [pause]).projected =
        (query liquidShortfall [liquidation]).projected ∧
      pause ≠ liquidation := by
  decide

/-!
Observation 185 earns only this narrow boundary:

```text
canonical evidence
+ explicitly typed hypothetical intervention list
-> derived comparison projection
```

with these constraints:

```text
empty overlay -> baseline
query          -> canonical input unchanged
same JPY relief != same household consequence
same projected vector != same intervention meaning
```

That is enough to support questions like "which change removes this shortfall?"
without making the projection itself a decision authority.

The observation does **not** earn a canonical Scenario, Recommendation,
Preference, Optimization, Savings, or SafeToSpend object. It does not choose
which intervention a person should prefer, automatically cancel a Scheduled
item, reallocate Capacity, pause an investment contribution, or liquidate an
asset. It also does not claim that the three modeled axes are a complete
household state.

A production follow-up should start with one concrete read-only hypothetical
operation over an already-qualified Application projection, retain the typed
intervention provenance, and compare baseline with overlay. It should not begin
with a generic optimizer or one scalar "money saved" field.
-/

end Loam.Observation185
