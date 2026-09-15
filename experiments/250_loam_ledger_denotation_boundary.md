# Observation 250 — LOAM to Ledger denotation boundary

Status: **QUALIFIED by Lean 4.33.1 on PR #919**

Qualification:

```text
workflow: Selected Lean Observations
run:      34980860700
result:   SUCCESS
```

External reference inspected:

```text
ledger/ledger-semantics
main: 03abb3e91cf2cfbe2c77ff32ac2428e516458cd9
Lean: 4.30.0
```

LOAM baseline:

```text
shumoku88-bit/loam
main parent: d667fabd9bd2dd557b84648478c4d4b3078eda85
Lean: 4.33.1
```

## Question

Can one qualified LOAM `BalancedMovement LocusId` be projected into the
balance-level semantics used by `ledger-semantics` without first adding
`Account`, debit/credit, transaction kind, or another accounting noun to LOAM
Core?

More precisely, does the bridge preserve:

1. every same-Measure coordinate quantity;
2. isolation of unrelated Measures;
3. the exact zero-total law of one balanced movement?

## External semantic target

`ledger-semantics` defines its atomic account as:

```text
AccountName × Commodity
```

and its balance-level Pacioli carrier as:

```text
Account →₀ ℚ
```

where a journal/morphism is denoted by exact per-account net flow.

The repository explicitly says this balance skeleton forgets morphism identity:
it is adequate for balance queries, not register queries.

LOAM already has the nearby structure:

```text
EffectCoordinate = LocusId × MeasureId
```

and Observation 159 established that fixed-Measure movement changes admit a
free-Abelian-style coordinate-vector projection while retained evidence remains
richer than that projection.

## Why this observation does not import ledger-semantics

The current toolchains differ:

```text
LOAM             Lean 4.33.1
ledger-semantics Lean 4.30.0 + Mathlib
```

Pulling the external project into LOAM merely for this observation would add a
large dependency/toolchain pressure before the semantic boundary itself is
known to be useful.

Observation 250 therefore introduces only a local bridge *shape*:

```text
LedgerAccountShadow
    = LocusId × MeasureId
```

This intentionally preserves LOAM identities rather than converting them to
display strings. It is a statement about denotation shape, not a claim that a
LOAM `LocusId` is intrinsically an accounting Account or that `MeasureId` is
intrinsically a Ledger Commodity.

The external Ledger carrier uses rational values. LOAM's current exact quantity
kernel uses integer quanta. Observation 250 checks the integer-quanta subdomain
before the canonical integer-to-rational embedding. It does not add Mathlib
merely to prove that standard embedding.

## Qualified proof obligations

`Loam.Observations.Observation250` defines the finite bridge presentation and
proves four laws in the selected live Lean observation umbrella.

### O250-1 — presentation total is preserved

```text
ledgerPresentationTotalQuanta (map movement changes)
    =
movementTotalQuanta changes
```

Therefore an admitted `BalancedMovement` maps to exact total zero.

### O250-2 — same-Measure coordinate flow is preserved

For every Locus:

```text
ledgerFlowAt movement (locus, movement.measure)
    =
movement.quantityAt locus
```

The bridge does not reinterpret the sign as debit/credit or classify the Locus.
It only preserves the additive observation.

### O250-3 — other Measures remain zero

For `otherMeasure ≠ movement.measure`:

```text
ledgerFlowAt movement (locus, otherMeasure) = 0
```

A single-Measure LOAM movement cannot accidentally create another commodity
flow through the bridge.

### O250-4 — Observation 159 quotient still factors

If two movement presentations are `VectorEquivalent` in Observation 159, every
same-Measure Ledger-shaped account observes the same flow.

So the external connection does not require a new additive quotient:

```text
LOAM retained movement presentation
        ↓
Observation 159 additive vector
        ↓
Ledger-shaped balance observation
```

## Qualified result

The successful Lean qualification establishes a named semantics-preserving
bridge at the balance layer:

```text
LOAM BalancedMovement
        |
        | preserve coordinate quantities
        | preserve Measure separation
        | preserve zero total
        v
Ledger/Pacioli-shaped net-flow observation
```

The mapping requires no debit/credit tag, Account role, income/expense role, or
transaction kind in the neutral LOAM movement algebra.

This is narrower than "LOAM implements Ledger" and stronger than a vocabulary
analogy: the bridge obligations are executable theorems checked by the current
LOAM Lean toolchain.

## What is deliberately not claimed

Observation 250 does **not** connect or prove equivalence for:

- Ledger's symmetric monoidal/groupoid transaction structure;
- morphism identity or register rows;
- journal sequencing;
- automated transactions;
- lot/cost/booking semantics;
- prices or time-indexed valuation;
- rational quantities outside LOAM's integer-quanta image;
- parser/display conventions;
- accounting-role projection;
- Event identity, Effect identity, correction provenance, routing, or time
  authority.

Those omissions matter. In particular:

```text
same Pacioli balance image
    !=
same LOAM retained evidence
```

because Ledger's own balance skeleton intentionally forgets morphism identity,
and LOAM intentionally retains identity/provenance when another question can
observe it.

## Connection result

The useful interpretation is therefore not:

```text
LOAM = Ledger
```

but:

```text
LOAM evidence
    -- selected additive denotation -->
Ledger-compatible balance semantics
```

This qualifies the first edge in the proposed connection triangle:

```text
               LOAM
              /    \
             /      \
           REA ---- Ledger
```

REA is intentionally excluded from Observation 250. A successor observation
should ask which REA distinctions are derivable from the current LOAM evidence
and use counterexamples to identify the smallest additional interpretation
evidence where they are not.

## Stop condition

Do not add `ledger-semantics`, Mathlib, `Account`, `Commodity`, debit/credit, or
another production abstraction to LOAM as a consequence of this observation.

A stronger direct dependency is earned only if a later executable or research
question needs to reuse the external categorical/rational machinery itself.
