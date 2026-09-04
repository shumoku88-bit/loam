import Loam.Observations.Observation159

namespace Loam.Observation162

open Loam.Core
open Loam.Observation159

set_option autoImplicit false

/-!
# Observation 162 — statement contract field trial against Observation 159

Observation 161 established the minimal statement-alignment pattern in isolation.
This observation applies the idea to an already-existing proof-bearing observation
without changing Observation 159 itself.

The reviewed contract below intentionally names only the three claims that form
the practical center of Observation 159:

1. the compact and split presentations are coordinate-vector equivalent;
2. the two presentations retain different representation shape;
3. both presentations satisfy the existing zero-augmentation boundary.

The field trial asks whether those already-proved theorems can be required to
inhabit one explicit reviewed proposition. If any of their statements drift away
from this contract while the contract remains unchanged, this module stops
building.
-/

/-- Reviewed proposition extracted from the intended center of Observation 159. -/
def ExpectedClaim : Prop :=
  VectorEquivalent compactPresentation splitPresentation ∧
  compactPresentation.length ≠ splitPresentation.length ∧
  movementTotalQuanta compactPresentation = 0 ∧
  movementTotalQuanta splitPresentation = 0

/--
Existing Observation 159 proofs must jointly inhabit the reviewed contract.
No new proof of the underlying mathematics is introduced here.
-/
theorem observation159_inhabits_reviewed_contract : ExpectedClaim := by
  exact ⟨
    split_and_compact_are_vector_equivalent,
    equivalent_presentations_can_have_different_shape,
    both_presentations_have_zero_augmentation
  ⟩

/--
A consumer can unfold the contract to the exact conjunction being reviewed;
workflow success alone is not used as a proxy for statement meaning.
-/
theorem reviewed_contract_is_exact :
    ExpectedClaim ↔
      VectorEquivalent compactPresentation splitPresentation ∧
      compactPresentation.length ≠ splitPresentation.length ∧
      movementTotalQuanta compactPresentation = 0 ∧
      movementTotalQuanta splitPresentation = 0 := by
  rfl

end Loam.Observation162
