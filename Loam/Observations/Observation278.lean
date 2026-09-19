import Loam.Core.BalancedMovement

namespace Loam.Observation278

open Loam.Core

set_option autoImplicit false

/-!
# Observation 278 — correction and reversal conservation need no new evidence

Observation 276 established conservation for finite sequences of proof-carrying
`BalancedMovement` values. Observation 277 separated structural Event identity
from semantic payment idempotency.

This observation asks a third narrow question:

> If correction replaces one balanced movement with another, and reversal is the
> exact quantity negation of a balanced movement, does conservation follow from
> the evidence LOAM already carries?

The observation deliberately stays below publication, persistence, and payment
semantics. It does not introduce a ledger state, PaymentId, balance policy, or
tamper-evidence format.
-/

/--
A correction candidate preserves the global zero-total invariant when both the
original and replacement have already crossed the `BalancedMovement` boundary.

Nothing about the original payload has to be retained in a new accounting type
to restate this invariant: both zero-total proofs are already carried by the
two values.
-/
theorem balanced_replacement_preserves_zero_total
    {Coordinate : Type}
    (original replacement : BalancedMovement Coordinate) :
    movementTotalQuanta original.changes = 0 ∧
      movementTotalQuanta replacement.changes = 0 := by
  exact ⟨original.balanced, replacement.balanced⟩

/-- Exact quantity negation of every represented movement change. -/
private def negateChanges {Coordinate : Type}
    (changes : List (MovementChange Coordinate)) :
    List (MovementChange Coordinate) :=
  changes.map fun change =>
    ({ coordinate := change.coordinate, quantity := -change.quantity } :
      MovementChange Coordinate)

/--
The exact negation used by a reversal remains a balanced movement.

This consumes the existing `BalancedMovement.totalQuanta_negated` theorem; no
second runtime balance validation is needed.
-/
def exactReversal {Coordinate : Type}
    (movement : BalancedMovement Coordinate) :
    BalancedMovement Coordinate := {
  measure := movement.measure
  changes := negateChanges movement.changes
  balanced := by
    rw [show
      movementTotalQuanta (negateChanges movement.changes) =
        -movementTotalQuanta movement.changes by
          simpa [negateChanges] using
            BalancedMovement.totalQuanta_negated movement.changes]
    simp [movement.balanced]
}

/-- The reversal produced above carries exact zero-total evidence. -/
@[simp] theorem exactReversal_total_zero
    {Coordinate : Type}
    (movement : BalancedMovement Coordinate) :
    movementTotalQuanta (exactReversal movement).changes = 0 := by
  exact (exactReversal movement).balanced

/--
The target's total and its exact reversal total cancel without any additional
retained accounting fact.
-/
theorem target_and_reversal_total_cancel
    {Coordinate : Type}
    (movement : BalancedMovement Coordinate) :
    movementTotalQuanta movement.changes +
      movementTotalQuanta (exactReversal movement).changes = 0 := by
  simp

/--
Signed quantity at one coordinate before wrapping it back into `Quantity`.

This helper exists only to state the stronger reversal property below.
-/
private def coordinateTotal
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) : Int :=
  changes.foldr
    (fun change total =>
      if change.coordinate = coordinate then
        change.quantity.quanta + total
      else
        total)
    0

/--
Exact negation is coordinate-wise, not merely globally zero-sum.

For every coordinate, the reversal contributes the additive inverse of the
target's contribution. This is stronger than saying that both movements happen
to have total zero.
-/
private theorem coordinateTotal_negated
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    coordinateTotal (negateChanges changes) coordinate =
      -coordinateTotal changes coordinate := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · simp [coordinateTotal, negateChanges, h, ih, Int.neg_add]
      · simp [coordinateTotal, negateChanges, h, ih]

/--
At every coordinate, target plus reversal contributes exact zero.

This is the useful cancellation law for an explicit reversal relation: the
existing movement payload is sufficient to derive the inverse quantity.
-/
theorem target_and_reversal_cancel_at
    {Coordinate : Type} [DecidableEq Coordinate]
    (movement : BalancedMovement Coordinate)
    (coordinate : Coordinate) :
    (BalancedMovement.quantityAt movement coordinate).quanta +
      (BalancedMovement.quantityAt (exactReversal movement) coordinate).quanta = 0 := by
  change
    coordinateTotal movement.changes coordinate +
      coordinateTotal (negateChanges movement.changes) coordinate = 0
  rw [coordinateTotal_negated]
  exact Int.add_neg_cancel _

/-!
## Finding

For this bounded algebraic question, the existing evidence is enough:

```text
Correction:
  balanced target
      -> balanced replacement
      -> zero-total invariant remains true

Reversal:
  balanced target
      -> exact quantity negation
      -> balanced reversal
      -> target + reversal = 0 at every coordinate
```

No new retained evidence is required to prove these conservation properties.

This does **not** establish:

- semantic duplicate-payment prevention;
- that every Core Event is a balanced movement;
- nonnegative or credit-limit account policy;
- cryptographic tamper detection;
- payment authorization, clearing, settlement, or retry semantics.

Those remain independent questions rather than hidden obligations of correction
or reversal.
-/

end Loam.Observation278
