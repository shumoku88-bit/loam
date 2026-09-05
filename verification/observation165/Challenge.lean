namespace Observation165

set_option autoImplicit false

/--
Trusted statement surface for the first LOAM Comparator field trial.

This file deliberately knows only the concrete integer observables reviewed in
Observation 164. It does not import LOAM, Observation 159, VectorEquivalent,
aggregateAt, MovementChange, or Quantity.
-/
theorem vector_claim :
    ((-100 : Int) = -100) ∧ ((100 : Int) = 100) := by
  sorry

end Observation165
