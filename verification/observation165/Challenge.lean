namespace Observation165

set_option autoImplicit false

/--
Trusted statement surface for the first LOAM Comparator field trial.

This file deliberately knows only integer observables. It does not import LOAM,
Observation 159, VectorEquivalent, aggregateAt, MovementChange, or Quantity.
-/
theorem vector_claim
    (leftWallet leftFood rightWallet rightFood : Int) :
    leftWallet = rightWallet ∧ leftFood = rightFood := by
  sorry

end Observation165
