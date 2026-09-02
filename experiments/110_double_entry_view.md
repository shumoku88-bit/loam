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

This convention matches the representative ledger shapes already used by Observation 062:

```text
Asset +q / Expense +q / Liability repayment +q
    debit-side presentation

Asset -q / Income -q / Equity -q / liability creation -q
    credit-side presentation
```

The question is whether the debit / credit side adds any independently observable information once signed Effects are retained.

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

The expected pressure is that the quantity is forced by closure, while the semantic explanation is not.

## Probes

### 1. Representative derived accounting view

The specimen contains:

- balanced multi-Effect Movement;
- holding and non-holding Loci;
- explicit QuantityBasis;
- a derived closing boundary posting;
- one possible Equity interpretation of that boundary.

Expected: **SAT**.

### 2. Balanced Movement can change selected holdings

A whole Movement remains zero-total while the sum of its Effects on selected holding Loci is non-zero.

Expected: **SAT**.

This prevents confusing bookkeeping closure with conservation of one projection.

### 3. Debit / credit side can stay fixed while AccountingRole changes

Two worlds retain the same signed Effects and therefore the same debit / credit presentation, while assigning different accounting roles to Loci.

Expected: **SAT**.

This keeps the Observation 049 distinction visible:

```text
posting polarity
    !=
accounting statement meaning
```

### 4. Same physical basis can support different opening explanations

Two worlds have the same QuantityBasis and the same forced boundary quantity, but choose different accounting meanings for the boundary.

Expected: **SAT**.

A physical starting observation therefore need not contain the historical claim “this came from Equity”.

## Checks

Expected results:

```text
SignedEffectsDetermineDebitCreditSide              UNSAT counterexample
DebitCreditSidesPartitionMovementEffects           UNSAT counterexample
BasisDeterminesBoundaryQuantity                     UNSAT counterexample
PhysicalBasisDeterminesBoundaryAccountingMeaning    SAT counterexample
DerivedOpeningViewRemainsBalanced                   UNSAT counterexample
```

The first check asks whether faithful debit / credit presentation is already fixed by Effect sign.

The second checks that debit and credit sides partition the non-zero Movement Effects.

The third asks whether the quantity needed to close a basis-only accounting view is uniquely forced.

The fourth deliberately asks too much: physical basis quantities should not determine their accounting explanation.

The fifth preserves the derived closing equation.

## Compression boundary sought

If the expected result survives Alloy, the useful boundary would be:

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

That would make double-entry neither LOAM's rejected opposite nor its hidden ontology.

Instead it would be a strong derived view whose conservation structure can be recovered where the evidence earns it, while accounting explanation remains an explicit semantic overlay when later questions observe that distinction.

## Why this may matter later

This shape also leaves room for a more abstract observation without importing category-theory vocabulary into production code prematurely.

If several projections preserve the same conservation law, or if different projection paths are expected to produce the same answer, those can later be tested as composition / commutation questions. Observation 110 only establishes the concrete household boundary first.

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

The experiment asks only whether double-entry closure and posting polarity can be reconstructed from the selected practical evidence while preserving the already-earned distinction between physical starting observation and accounting explanation.
