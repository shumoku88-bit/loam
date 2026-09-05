namespace Loam.Observation164Contract

set_option autoImplicit false

/-!
# Observation 164 contract — independent statement surface

This file is intentionally self-contained. In particular it does not import
Observation 159, `VectorEquivalent`, `aggregateAt`, `MovementChange`, or
`Quantity`.

The reviewed surface pins the observable meaning directly in integer quanta:
wallet and food coordinates must agree independently. An implementation may
change how it represents or proves presentation equivalence, but it must still
map its observable coordinate quantities onto this surface.
-/

/-- A reviewed two-coordinate vector claim, independent of LOAM's implementation definition. -/
def ExpectedVectorClaim
    (leftWallet leftFood rightWallet rightFood : Int) : Prop :=
  leftWallet = rightWallet ∧ leftFood = rightFood

end Loam.Observation164Contract
