import Loam.Observations.Observation250

namespace Loam.Observation380

open Loam.Core
open Loam.Observation250

set_option autoImplicit false

/-!
# Observation 380 — Ledger valuation-law correspondence at the LOAM balance boundary

Observation 250 established a direct Ledger/Pacioli-shaped balance projection
from LOAM's existing single-Measure movement evidence.

The current public `ledger/ledger-semantics` formalization makes three
valuation laws primitive:

```text
composition  -> addition
tensor       -> addition
aggregation  -> addition
```

and derives identity/zero and inverse behavior from those laws plus its richer
groupoid structure.

LOAM should not import that richer structure merely because its balance
projection is additive. This observation asks the smaller question:

> At the already-qualified Observation-250 balance boundary, do empty
> presentation, finite aggregation, and exact quantity negation obey the same
> zero / addition / additive-inverse equations?

The answer is stated only for the existing Ledger-shaped projection. No Account,
transaction, composition, tensor, category, groupoid, price, or external
dependency is added to production Core.
-/

/-- Observation-local exact negation of one retained change presentation. -/
def negateChanges
    (changes : List (MovementChange LocusId)) :
    List (MovementChange LocusId) :=
  changes.map fun change =>
    ({ coordinate := change.coordinate, quantity := -change.quantity } :
      MovementChange LocusId)

/-- Empty presentation has zero flow at every Ledger-shaped coordinate. -/
@[simp] theorem ledgerFlowQuanta_nil
    (measure : MeasureId)
    (account : LedgerAccountShadow) :
    ledgerFlowQuantaAtChanges measure [] account = 0 := by
  rfl

/--
The Observation-250 integer-quanta denotation is additive under finite
presentation concatenation.

This is the balance-level homomorphism law LOAM actually owns. It does not claim
that list concatenation is Ledger composition, tensor, or hom-set addition.
-/
theorem ledgerFlowQuanta_append
    (measure : MeasureId)
    (left right : List (MovementChange LocusId))
    (account : LedgerAccountShadow) :
    ledgerFlowQuantaAtChanges measure (left ++ right) account =
      ledgerFlowQuantaAtChanges measure left account +
        ledgerFlowQuantaAtChanges measure right account := by
  induction left with
  | nil =>
      simp [ledgerFlowQuantaAtChanges]
  | cons change rest ih =>
      by_cases hAccount :
          accountOf change.coordinate measure = account
      · simp [ledgerFlowQuantaAtChanges, hAccount, ih, Int.add_assoc]
      · simp [ledgerFlowQuantaAtChanges, hAccount, ih]

/-- Quantity-valued additive form of `ledgerFlowQuanta_append`. -/
theorem ledgerFlowAtChanges_append
    (measure : MeasureId)
    (left right : List (MovementChange LocusId))
    (account : LedgerAccountShadow) :
    ledgerFlowAtChanges measure (left ++ right) account =
      ledgerFlowAtChanges measure left account +
        ledgerFlowAtChanges measure right account := by
  change
    Quantity.ofQuanta
        (ledgerFlowQuantaAtChanges measure (left ++ right) account) =
      Quantity.ofQuanta
        (ledgerFlowQuantaAtChanges measure left account +
          ledgerFlowQuantaAtChanges measure right account)
  rw [ledgerFlowQuanta_append]

/--
Exact quantity negation becomes additive inversion at every Ledger-shaped
coordinate, not merely at the global zero-total observer.
-/
theorem ledgerFlowQuanta_negated
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (account : LedgerAccountShadow) :
    ledgerFlowQuantaAtChanges measure (negateChanges changes) account =
      -ledgerFlowQuantaAtChanges measure changes account := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases hAccount :
          accountOf change.coordinate measure = account
      · simp [negateChanges, ledgerFlowQuantaAtChanges, hAccount, ih, Int.neg_add]
      · simp [negateChanges, ledgerFlowQuantaAtChanges, hAccount, ih]

/-- Quantity-valued additive-inverse form of `ledgerFlowQuanta_negated`. -/
theorem ledgerFlowAtChanges_negated
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (account : LedgerAccountShadow) :
    ledgerFlowAtChanges measure (negateChanges changes) account =
      -ledgerFlowAtChanges measure changes account := by
  change
    Quantity.ofQuanta
        (ledgerFlowQuantaAtChanges measure (negateChanges changes) account) =
      Quantity.ofQuanta
        (-ledgerFlowQuantaAtChanges measure changes account)
  rw [ledgerFlowQuanta_negated]

/--
Observation 159's vector-equivalence quotient remains the semantic equality of
this balance projection. Thus presentation rearrangement/splitting that
preserves every coordinate also preserves the Ledger-shaped image.
-/
theorem ledgerFlowAtChanges_respects_vector_equivalence
    (measure : MeasureId)
    (left right : List (MovementChange LocusId))
    (hEquivalent : Loam.Observation159.VectorEquivalent left right)
    (locus : LocusId) :
    ledgerFlowAtChanges measure left (accountOf locus measure) =
      ledgerFlowAtChanges measure right (accountOf locus measure) :=
  ledger_flow_respects_vector_equivalence
    measure left right hEquivalent locus

/-!
## Finding

The shared balance algebra is now explicit:

```text
empty presentation -> zero flow
concatenation       -> addition of flows
exact negation      -> additive inverse
vector equivalence  -> equal projected flow
```

That is enough to explain the concrete overlap between LOAM's Observation-250
bridge and the additive valuation layer of `ledger-semantics`.

It does **not** earn the converse architectural import.

LOAM has not retained distinct operators corresponding to Ledger's categorical
composition, tensor product, and hom-set addition. At the selected balance
boundary they may all share an additive denotation while carrying different
meaning in Ledger's richer model.

So the safe correspondence is:

```text
LOAM retained movement evidence
        |
        | additive balance denotation
        v
finite coordinate flow

Ledger semantic morphism
        |
        | valuation / Pacioli denotation
        v
finite account flow
```

The lower algebra corresponds. The upper evidence structures are not thereby
identified.
-/

end Loam.Observation380
