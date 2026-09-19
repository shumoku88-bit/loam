import Loam.Core.BalancedMovement

namespace Loam.Observation276

open Loam.Core

set_option autoImplicit false

/-!
# Observation 276 — proof-carrying ledger conservation

LOAM does not make every Core Event balanced. Practical callers may instead
cross the stronger `BalancedMovement` boundary when exact conservation is part
of the operation being modeled.

Before introducing a new ledger DSL or payment-specific production type, this
observation asks the smaller question:

> If a ledger-like transition sequence contains only proof-carrying
> `BalancedMovement` values, can exact global conservation be obtained without
> any repeated runtime balance check?

The observation deliberately models only the scalar net change contributed by
the complete represented movements. It does not yet model account balance
policies, idempotency keys, settlement state, external payment rails, or
cryptographic tamper evidence.
-/

/--
The aggregate signed change contributed by a sequence of already-admitted
balanced movements.
-/
def ledgerNet {Coordinate : Type} :
    List (BalancedMovement Coordinate) -> Int
  | [] => 0
  | movement :: rest =>
      movementTotalQuanta movement.changes + ledgerNet rest

/--
A successful runtime entrance through `BalancedMovement.ofChanges?` establishes
the exact zero-total fact that later code may trust.
-/
theorem successful_admission_closes
    {Coordinate : Type}
    (measure : MeasureId)
    (changes : List (MovementChange Coordinate))
    (movement : BalancedMovement Coordinate)
    (hAdmission : BalancedMovement.ofChanges? measure changes = some movement) :
    movementTotalQuanta changes = 0 := by
  by_cases hZero : movementTotalQuanta changes = 0
  · exact hZero
  · simp [BalancedMovement.ofChanges?, hZero] at hAdmission

/--
Every finite sequence of proof-carrying balanced movements has zero aggregate
signed change.

No induction step re-validates a movement. Each step consumes the balance proof
already carried by that value.
-/
@[simp] theorem ledgerNet_zero
    {Coordinate : Type}
    (movements : List (BalancedMovement Coordinate)) :
    ledgerNet movements = 0 := by
  induction movements with
  | nil =>
      rfl
  | cons movement rest ih =>
      simp [ledgerNet, ih]

/--
Apply the aggregate movement net to one scalar opening invariant.

This is intentionally not an account-balance implementation. The scalar stands
for any already-established global conserved total.
-/
def conservedTotal
    {Coordinate : Type}
    (opening : Int)
    (movements : List (BalancedMovement Coordinate)) : Int :=
  opening + ledgerNet movements

/--
A sequence containing only `BalancedMovement` values cannot change an
already-established global conserved total.
-/
@[simp] theorem conservedTotal_eq_opening
    {Coordinate : Type}
    (opening : Int)
    (movements : List (BalancedMovement Coordinate)) :
    conservedTotal opening movements = opening := by
  simp [conservedTotal]

/--
Appending one more admitted balanced transaction preserves the same global
conserved total.

This is the small transition-preservation shape needed before considering a
stronger verified-ledger state type.
-/
theorem append_balanced_preserves_conservation
    {Coordinate : Type}
    (opening : Int)
    (existing : List (BalancedMovement Coordinate))
    (next : BalancedMovement Coordinate) :
    conservedTotal opening (existing ++ [next]) =
      conservedTotal opening existing := by
  simp

/-!
## Finding

For the bounded question asked here, no new ledger ontology is needed:

```text
arbitrary runtime changes
    -> BalancedMovement.ofChanges?
    -> proof-carrying BalancedMovement
    -> finite sequence
    -> exact global conservation
```

The important boundary is negative as well as positive.

This observation does **not** establish:

- that every LOAM Core Event should be balanced;
- debit/credit as Core concepts;
- nonnegative per-account balances;
- semantic duplicate-payment prevention;
- correction or reversal preservation;
- immutable or cryptographically tamper-evident persistence;
- authorization, clearing, settlement, retry, or external payment semantics.

Those remain separate questions. If later observations earn them, they can be
layered above the neutral Core rather than narrowing what an Event is allowed to
observe.
-/

end Loam.Observation276
