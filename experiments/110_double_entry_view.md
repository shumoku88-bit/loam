# Observation 110: Can double-entry be a derived closed view?

## Question

LOAM deliberately does not make conventional double-entry bookkeeping its Core ontology.

The current Practical entrance records balanced Movement as signed Effects, while Core itself keeps `Event`, `Effect`, `Locus`, `Measure`, and exact signed `Quantity` neutral. Earlier observations also established that a conventional Account object is not required for the selected physical questions, while an AccountingRole overlay is independently observable for Balance Sheet / Profit & Loss questions.

That leaves a deeper question before the next household implementation slice:

> Can the conservation and checking structure that makes double-entry bookkeeping attractive be recovered as a faithful accounting view over LOAM evidence, without making Account / debit / credit / opening-equity entries canonical physical facts?

This observation focuses on two seams:

1. ordinary balanced Movement;
2. `QuantityBasis`, which intentionally records quantity already present at the application origin rather than inventing a historical change.

## Existing evidence

This probe extends rather than repeats earlier work.

- Observation 031 separated neutral `Locus` from conventional Account identity.
- Observation 049 showed that Asset / Liability / Equity / Income / Expense interpretation is not determined by physical placement and may require an explicit accounting-role overlay.
- Observation 062 showed that representative real-ledger shapes can be recognized from signed Effects plus AccountingRole without restoring Account or EventKind, and that all eight selected bookkeeping-shaped specimens are zero-total.
- Application 008 established that starting `QuantityBasis` is not itself a Movement and should not be disguised as income or a fictional opening Event merely to make arithmetic close.
- The current Movement entrance requires FROM and TO totals to agree, but explicitly does not make a global Core conservation law.

Observation 110 therefore does **not** ask whether LOAM should adopt double-entry terminology. It asks what part of double-entry is already a projection of retained evidence and what part remains an independent interpretation.

## Candidate accounting view

### Balanced Movement

For this bounded specimen every admitted practical Movement is zero-total:

```text
sum signed Effects = 0
```

The model adds a deliberately presentational `PostingSide`:

```text
positive signed Effect -> Debit
negative signed Effect -> Credit
```

This convention matches the representative ledger shapes already used by Observation 062.

The question is whether debit / credit side adds any independently observable information once signed Effects are retained.

### Holding projection

The model also selects some Loci as holding Loci.

A whole Movement can be zero-total while the selected holding projection changes. For example, a non-holding source can contribute a negative Effect while a holding Locus receives the positive Effect.

This distinguishes:

```text
closed accounting movement across all admitted coordinates
    !=
zero change in the household holding projection
```

So conservation of the complete Movement need not mean that cash / asset holdings are conserved.

### QuantityBasis

`QuantityBasis` is kept as physical starting evidence, not an Event.

To ask whether a double-entry **view** can still close, the model introduces one non-physical `BoundaryPosting` per accounting world. It has only a quantity and is constrained so that:

```text
all QuantityBasis lines
+ derived boundary posting
= 0
```

The boundary posting is observation scaffolding for an accounting projection. It is not proposed as stored LOAM evidence.

The model then separates two questions:

1. Is the boundary **quantity** determined by the physical basis quantities?
2. Is the boundary **accounting meaning** such as Equity / Income / Liability determined by those physical quantities?

## Executed result

The first CI attempt stopped before solving because an exact scope was applied to subset signature `HoldingLocus`. Changing it from a subset signature to an ordinary `extends Locus` specimen changed only the scope declaration, not the research question or selected projections.

Alloy 6.2.0 + Sat4j then produced exactly the expected result set:

```text
representativeDerivedAccountingView                  SAT
balancedMovementCanChangeHoldingProjection            SAT
sameDebitCreditSidesDifferentAccountingRoles          SAT
sameBasisDifferentBoundaryMeaning                     SAT
SignedEffectsDetermineDebitCreditSide                 UNSAT counterexample
DebitCreditSidesPartitionMovementEffects              UNSAT counterexample
BasisDeterminesBoundaryQuantity                       UNSAT counterexample
PhysicalBasisDeterminesBoundaryAccountingMeaning      SAT counterexample
DerivedOpeningViewRemainsBalanced                     UNSAT counterexample
```

The complete expected-result checker passed in CI on executable head `87299d7d561683722c1974c810abbe45d3331d36`.

## Finding

The bounded result separates the mathematical closure from the semantic explanation.

### 1. Debit / credit polarity is a projection here

Once the selected signed-Effect convention is fixed:

```text
positive Effect -> Debit
negative Effect -> Credit
```

Alloy found no world in which the same signed Effects require different debit / credit sides. The two sides also partition the non-zero Movement Effects.

So a stored posting-side bit carries no additional information for this admitted view.

This does **not** make debit / credit intrinsic Core meaning. It says the accounting presentation is recoverable when that convention is selected.

### 2. Whole closure does not imply projection closure

All admitted Movements are zero-total, yet Alloy found a witness where the selected holding Effects have a non-zero sum.

Therefore:

```text
whole Movement is balanced
    does not imply
selected household holdings do not change
```

This is exactly what an income-like or expense-like movement needs: the complete recorded relation can close while the holding projection gains or loses quantity.

### 3. Basis determines the closing quantity

With physical QuantityBasis fixed, Alloy found no counterexample in which two derived accounting views require different boundary quantities.

The quantity needed to close the opening accounting view is therefore determined by the basis quantities in this bounded model.

That boundary amount need not be retained as another canonical fact.

### 4. Basis does not determine the accounting explanation

Keeping the same physical basis, same closing quantity, and same physical Locus roles, Alloy found a counterexample where the accounting meaning of the boundary differs.

So:

```text
physical starting quantity
    -> closing amount

physical starting quantity
    -/-> Equity meaning
```

A conventional opening Equity posting can be a valid accounting interpretation without becoming a historical claim that LOAM must pretend to have observed.

## Compression boundary

The useful result is:

```text
balanced signed Movement
    -> double-entry debit / credit presentation
       without stored posting-side facts

complete zero-sum Movement
    != zero change in selected holdings

QuantityBasis
    -> unique closing quantity for an accounting boundary view
    != unique accounting meaning for that boundary
```

Double-entry is therefore neither LOAM's rejected opposite nor its hidden ontology in this bounded result.

It can be a strong **derived accounting view** whose conservation and checking structure is recovered from evidence where possible, while accounting explanation remains an explicit semantic overlay when household questions observe that distinction.

## Why this matters for the next practical slice

The result lets practical Capacity / routing work continue without first converting LOAM into a conventional chart-of-accounts system.

At the same time, future accounting projections can preserve a very strong invariant:

```text
admitted balanced Movement
    -> closed signed accounting view
```

That invariant can later become a Lean law if a practical reusable boundary earns it.

It also leaves room for a more abstract observation later. If several projections preserve the same closure, or if different projection paths should yield the same answer, those can be tested as composition / commutation questions without importing category-theory vocabulary into production code prematurely.

## Important boundaries

Observation 110 does not establish:

- a global zero-sum law for every Core Event;
- that every future practical entrance must be a balanced Movement;
- production Debit / Credit types;
- a conventional Account object;
- one permanent sign convention for every external import format;
- period closing or retained earnings rules;
- accrual recognition;
- valuation or exchange-rate accounting;
- that Equity is the correct opening explanation for every basis;
- that a derived BoundaryPosting should be persisted;
- that AccountingRole is final or metaphysically primitive;
- a categorical model of LOAM.

The experiment establishes only the bounded separation between recoverable double-entry closure and independently chosen accounting meaning.
