import Loam.Core.BalancedMovement

namespace Loam.Observation161Contract

open Loam.Core

set_option autoImplicit false

/-!
# Observation 161 contract — statement alignment boundary

This file is deliberately small. It represents the proposition that a reviewer
intends the proof-bearing observation to establish. The proof implementation
lives separately in `Observation161.lean`.

The machine-checkable boundary is therefore:

```text
reviewed expected proposition
    -> theorem must inhabit exactly that proposition
    -> Lean kernel checks the inhabitance
```

Changing the proof theorem to establish a different proposition is not enough:
the alignment check in the implementation must still type-check against
`ExpectedClaim`.
-/

inductive Coordinate where
  | wallet
  | food
  deriving Repr, DecidableEq

/-- Minimal concrete movement used only to exercise the alignment boundary. -/
def presentation : List (MovementChange Coordinate) :=
  [ { coordinate := .wallet, quantity := Quantity.ofQuanta (-100) },
    { coordinate := .food, quantity := Quantity.ofQuanta 100 } ]

/--
The independently named proposition that the proof-bearing observation is
required to establish.
-/
def ExpectedClaim : Prop :=
  movementTotalQuanta presentation = 0

end Loam.Observation161Contract
