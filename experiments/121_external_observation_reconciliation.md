# Observation 121 — Is a bank/import record an Actual fact or external evidence about one?

## Household question

LOAM can already retain Actual household Events with stable identity and can preserve explicit relations when another evidence family points at those Events.

A different pressure appears when an external system later reports something that appears to describe the same household occurrence:

```text
manual household Actual
    +
later bank / card observation
```

Many personal-finance systems ingest the external record into transaction-shaped storage and then perform matching, merge, or deduplication work around it. LOAM should not assume that architecture is necessary.

The narrower questions are:

> If Actual household facts and external source records are both retained, can the external records remain a distinct evidence family linked to Actual identity, or must they themselves become additional Actual occurrences?

and:

> Can the reconciliation link be reconstructed from date / quantity / shape matching, or does the correspondence itself carry independently observable information?

## Why Alloy

This is a static distinguishability and sufficiency question.

Two worlds can retain the same Actual records and the same external source records while varying only which external record supports which Actual identity. If household answers change, record content alone is too small.

No publication order, pending-to-posted transition, retry protocol, or concurrent import behavior is being asked yet, so Alloy is the smallest instrument that gives a distinct answer.

## Competing candidates

### Candidate A — promote imported records to Actual

A common representation is effectively:

```text
manual record       -> transaction-shaped row
bank import         -> transaction-shaped row
card import         -> transaction-shaped row
```

followed by matching / merge logic.

The pressure is that multiple independent source observations may describe one household occurrence.

The specimen contains one Actual card-payment occurrence and two external observations of it, one from a bank feed and one from a card feed. If both source observations are treated as additional occurrence rows, one household occurrence is represented by three occurrence-shaped records:

```text
1 retained Actual
+ 2 source observations
```

This observation does not claim that every PFM literally uses this storage shape. It tests whether external source authority has to collapse into Actual authority in LOAM.

### Candidate B — separate external observation evidence

The competing decomposition is:

```text
ExternalObservation identity
  + source
  + observed quantity / time / shape

Actual identity
  + household occurrence content

reconciles : ExternalObservation -> lone Actual
```

Multiple external observations may support one Actual.

An Actual may have no external observation at all, such as cash or a manually known household occurrence.

An external observation may remain unreconciled while the household has not yet identified the corresponding Actual.

The relation is therefore evidence about correspondence, not an assertion that every observation is already household Actual truth.

## Synthetic specimens

### Manual Actual without feed evidence

```text
ManualCash Actual
    no external observation required
```

### Reconciliation with timing drift

```text
Household Actual
  quantity 20
  evening
  transfer shape

Bank observation
  quantity 20
  morning
  transfer shape
```

The explicit relation can connect them even though the source time differs from the household occurrence coordinate.

### Exact-content ambiguity

Two distinct Actual identities deliberately occupy the same observable coordinates:

```text
CoffeeA  quantity 5, morning, coffee shape
CoffeeB  quantity 5, morning, coffee shape

BankCoffee quantity 5, morning, coffee shape
```

The external record exactly matches both Actual records.

Two worlds retain every record unchanged but reconcile `BankCoffee` to different Actual identities.

### Two feeds observing one Actual

```text
BankPayment --------+
                     +-> CardPayment Actual
CardPaymentObs ------+
```

The source observations have distinct source authority but support the same household occurrence.

## Executed result

Alloy 6.2.0 + Sat4j on exact head `1aa85380101b724039c8e845215933c4f9954dbb` produced the complete expected result set:

```text
reconciliationCanLinkTimingDrift               SAT
manualActualCanExistWithoutExternalObservation SAT
externalObservationCanRemainUnreconciled       SAT
twoSourcesCanObserveOneActual                  SAT
exactContentCanBeAmbiguous                     SAT
sameRecordsDifferentReconciliationWitness      SAT
separateObservationAvoidsPromotionDoubleCount  SAT

ExactContentIdentifiesAtMostOneActual           SAT counterexample
RecordsAloneDetermineSupportedActuals           SAT counterexample
ReconciliationRelationDeterminesSelectedAnswers UNSAT counterexample
```

For `check` commands, SAT means Alloy found a counterexample to the asserted law.

The solver execution and expected-result checker both completed **SUCCESS**.

## Interpretation

### 1. Actual does not require external corroboration

The model admits a manual/cash Actual with no external observation.

Observed: **SAT**.

So being seen by a bank/card feed is not necessary for an occurrence to be Actual in the selected vocabulary.

### 2. External observation does not automatically become Actual

The model admits an external observation that remains unreconciled.

Observed: **SAT**.

This preserves the distinction between "a source reported this" and "the household has identified the Actual occurrence this evidence belongs to".

### 3. Reconciliation need not mean exact field equality

The timing-drift specimen links a morning bank observation to an evening household Actual while quantity and broad shape agree.

Observed: **SAT**.

So reconciliation cannot be defined as simple equality of every observed coordinate.

### 4. Exact content still does not identify the Actual

`BankCoffee` exactly matches both `CoffeeA` and `CoffeeB`.

Observed: **SAT**, and `ExactContentIdentifiesAtMostOneActual` has a **SAT counterexample**.

Stable identity plus explicit correspondence preserves a distinction that exact date / quantity / shape matching cannot recover.

### 5. Same records can require different support answers

`Left` and `Right` retain the same Actual atoms and the same ExternalObservation atoms. Only `reconciles` varies.

Observed: **SAT**, and `RecordsAloneDetermineSupportedActuals` has a **SAT counterexample**.

Therefore the record sets alone do not determine which Actual occurrence has external support.

### 6. Several sources can corroborate one Actual without creating several Actuals

The model admits both a bank-feed observation and a card-feed observation pointing to one `CardPayment` Actual.

Observed: **SAT**.

The selected specimen has exactly one transfer-shaped Actual and two transfer-shaped external observations. Keeping the evidence families separate preserves one household occurrence while retaining both source provenance paths.

### 7. Explicit reconciliation determines the selected projections

When `Left.reconciles = Right.reconciles`, Alloy finds no bounded counterexample where supported-Actual membership or unreconciled-observation membership differs.

Observed: **UNSAT counterexample**.

## Finding

The bounded evidence boundary is:

```text
external source record
    !=
household Actual occurrence
```

and:

```text
Actual records
+ ExternalObservation records

    do not determine

which observation supports which Actual
```

The reconciliation correspondence carries independently observable information.

For the selected questions, the smaller decomposition is sufficient:

```text
Actual occurrence evidence

External observation evidence
    |
    +-- explicit reconciliation --> Actual identity

projection:
  externally supported?
  which source observations support this Actual?
  which observations remain unresolved?
```

This gives no reason to add a mutable `cleared`, `matched`, or `imported` flag to Actual merely to answer those questions.

It also gives no reason to promote every bank/card record into household Actual authority merely because it arrived from an external source.

This does **not** mean imported evidence can never cause a writer to create a new Actual. That is an operation/policy question left for later. The semantic result is narrower: external observation and household occurrence are distinguishable authorities, and their correspondence is not recoverable from record content alone.

## Neighboring boundaries

Observation 063 already showed that expected/Actual realization cannot be inferred from matching content because identity-distinct candidates can occupy the same coordinates.

Observation 120 tests a richer Scheduled realization pressure where endpoint topology alone can lose apportionment information.

Observation 121 is intentionally independent of Observation 120. It asks a different question:

```text
semantic-family correspondence
vs
external-source corroboration
```

Together they suggest a recurring LOAM pressure without yet earning a generic relation framework:

> distinct evidence authorities may share mechanics while preserving explicit correspondence when later questions observe provenance.

The pattern should remain local until another concrete seam earns abstraction.

## Boundaries

This observation does not establish:

- a production `ExternalObservation` type;
- a bank API or import file format;
- that imported records can never create a new Actual through a writer workflow;
- pending -> posted lifecycle semantics;
- source-record supersession or correction;
- duplicate delivery / retry handling;
- fuzzy matching policy;
- automatic reconciliation heuristics;
- statement-balance reconciliation;
- card authorization versus settlement semantics;
- transfer pairing across two financial institutions;
- split / merged source observations;
- foreign-exchange or valuation differences;
- whether reconciliation itself needs stable identity or correction history;
- whether source evidence belongs in the Practical Core or an application boundary.

The stop condition remains LOAM's normal one:

> If two worlds agree on all retained evidence but require different household answers, the missing distinction has earned investigation.
