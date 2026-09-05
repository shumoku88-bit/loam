import Loam.Observations.Observation159

namespace Loam.Observation163

open Loam.Core
open Loam.Observation159

set_option autoImplicit false

/-!
# Observation 163 — definition drift boundary

Observation 162 checks that existing theorem terms inhabit a separately named
`ExpectedClaim`. That catches theorem-statement drift while the reviewed claim
stays fixed.

This observation probes a different failure mode: the reviewed claim and the
implementation can still move together when both depend on the same changed
definition. The field trial deliberately compares two candidate meanings for
presentation equivalence:

* the Observation 159 meaning: every coordinate aggregate is equal;
* a weakened drifted meaning: only total augmentation is equal.

A concrete witness has equal total augmentation but different coordinate
vectors. If both a reviewed contract and its implementation were changed to use
the weakened shared definition, ordinary proposition inhabitation would remain
green even though the semantic boundary had moved.
-/

/-- Two balanced-looking presentations whose coordinate vectors differ. -/
def driftLeft : List (MovementChange Coordinate) :=
  [ { coordinate := .wallet, quantity := Quantity.ofQuanta (-100) },
    { coordinate := .food, quantity := Quantity.ofQuanta 100 } ]

/-- Same zero augmentation, but only half the coordinate quantities. -/
def driftRight : List (MovementChange Coordinate) :=
  [ { coordinate := .wallet, quantity := Quantity.ofQuanta (-50) },
    { coordinate := .food, quantity := Quantity.ofQuanta 50 } ]

/-- The original semantic boundary from Observation 159. -/
def StrictMeaning : Prop :=
  VectorEquivalent driftLeft driftRight

/-- A plausible but materially weaker replacement definition. -/
def DriftedMeaning : Prop :=
  movementTotalQuanta driftLeft = movementTotalQuanta driftRight

/-- The weakened meaning accepts the witness because both totals are zero. -/
theorem drifted_meaning_accepts_witness : DriftedMeaning := by
  decide

/-- The original coordinate-vector meaning rejects exactly the same witness. -/
theorem strict_meaning_rejects_witness : ¬ StrictMeaning := by
  intro h
  have hWallet := h Coordinate.wallet
  have unequal :
      Quantity.ofQuanta (-100) ≠ Quantity.ofQuanta (-50) := by
    decide
  apply unequal
  simpa [aggregateAt, driftLeft, driftRight] using hWallet

/-- The two meanings are observably different on one finite witness. -/
theorem definition_drift_is_semantic : DriftedMeaning ∧ ¬ StrictMeaning := by
  exact ⟨drifted_meaning_accepts_witness, strict_meaning_rejects_witness⟩

/-!
The next two declarations model the dangerous coupled edit. They intentionally
share `DriftedMeaning`: one is presented as the reviewed contract and one as the
implementation theorem. Lean can prove their alignment perfectly, even though
the previous theorem establishes that this shared meaning is weaker than the
Observation 159 meaning.
-/

/-- Reviewed contract after a hypothetical coupled definition edit. -/
def ExpectedClaimAfterCoupledDrift : Prop :=
  DriftedMeaning

/-- Implementation after the same hypothetical coupled definition edit. -/
theorem implementation_after_coupled_drift : DriftedMeaning := by
  exact drifted_meaning_accepts_witness

/-- Statement alignment remains mechanically green after the coupled drift. -/
theorem coupled_drift_still_inhabits_reviewed_contract :
    ExpectedClaimAfterCoupledDrift := by
  exact implementation_after_coupled_drift

/--
The limitation is therefore explicit: proposition inhabitation protects the
edge between a reviewed proposition and a theorem, but does not independently
pin the meanings of declarations shared by both sides.
-/
theorem current_contract_layer_does_not_pin_shared_definition :
    ExpectedClaimAfterCoupledDrift ∧ ¬ StrictMeaning := by
  exact ⟨coupled_drift_still_inhabits_reviewed_contract,
    strict_meaning_rejects_witness⟩

end Loam.Observation163
