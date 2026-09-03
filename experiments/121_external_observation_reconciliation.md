# Observation 121 — Is a bank/import record an Actual fact or external evidence about one?

## Household question

LOAM can already retain Actual household Events with stable identity and can preserve explicit realization relations when another semantic family points at those Events.

A different pressure appears when an external system later reports something that appears to describe the same household occurrence:

```text
manual household Actual
    +
later bank / card observation
```

Many personal-finance systems ingest the external record directly into their transaction table and then try to merge or deduplicate it later.

LOAM should not assume that architecture is necessary.

The narrower question is:

> If Actual household facts and external source records are both retained, can the external records remain a distinct evidence family linked to Actual identity, or must they themselves become additional Actual occurrences?

A second question follows immediately:

> Can the reconciliation link be reconstructed from date / quantity / shape matching, or does the correspondence itself carry independently observable information?

## Why Alloy

This is a static distinguishability and sufficiency question.

Two worlds can retain the same Actual records and the same external source records while varying only which external record supports which Actual identity.

If household answers change, content matching alone is too small.

No publication order, pending-to-posted transition, retry protocol, or concurrent import behavior is being asked yet, so Alloy is the smallest instrument that gives a distinct answer.

## Candidate A — promote imported records to Actual

A common representation is effectively:

```text
manual record       -> transaction row
bank import         -> transaction row
card import         -> transaction row
```

followed by matching / merge logic.

The pressure is that multiple independent source observations may describe one household occurrence.

The specimen contains one Actual card-payment occurrence and two external observations of it, one from a bank feed and one from a card feed.

If both observations are naively promoted into occurrence rows, one household occurrence is represented by three occurrence-shaped records:

```text
1 retained Actual
+ 2 source observations
```

The observation does not claim that every existing PFM literally implements this exact row count. It asks whether source evidence has to share the semantic authority of Actual in LOAM.

## Candidate B — separate external observation evidence

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

The relation is therefore evidence about correspondence, not an assertion that every observation is already household truth.

## Synthetic specimens

### Manual Actual without feed evidence

```text
ManualCash Actual
    no external observation required
```

This asks whether externally observed status is necessary for Actual existence.

### One source record with timing drift

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

The explicit reconciliation relation may connect them despite source timing differing from the household occurrence coordinate.

### Exact-content ambiguity

Two distinct Actual identities deliberately occupy the same observable coordinates:

```text
CoffeeA  quantity 5, morning, coffee shape
CoffeeB  quantity 5, morning, coffee shape

BankCoffee quantity 5, morning, coffee shape
```

The external record exactly matches both Actual records.

Two worlds retain every record unchanged but reconcile `BankCoffee` to different Actual identities.

If both worlds are reachable, exact content does not identify the correspondence.

### Two feeds observing one Actual

```text
BankPayment --------+
                     +-> CardPayment Actual
CardPaymentObs ------+
```

The two source observations have distinct source authority but support the same household occurrence.

This is the direct pressure against treating every source observation as another Actual occurrence.

## Qualification target

The workflow requires the following result set:

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

For `check` commands, SAT means Alloy found a counterexample to the asserted sufficiency law.

The final interpretation should be accepted only after exact-head Alloy CI confirms this complete result set.

## Expected finding if qualified

If the target results hold, the current evidence boundary will be:

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

The reconciliation correspondence itself then carries observable information, just as earlier LOAM observations found for Scheduled realization.

A likely minimal decomposition would be:

```text
Actual occurrence evidence

External observation evidence
    |
    +-- explicit reconciliation --> Actual identity

projection:
  externally supported?
  which sources support this Actual?
  which observations remain unresolved?
```

This would **not** earn a mutable `cleared`, `matched`, or `imported` flag on Actual.

It would also not imply that every external record must be persisted forever. Source adapters may later deduplicate or normalize their own records. The semantic point is only that external observation authority and household Actual authority need not collapse into one fact family.

## Neighboring boundaries

Observation 063 already showed that expected/Actual realization cannot be inferred from matching content because identity-distinct candidates can occupy the same coordinates.

Observation 120 tests a richer Scheduled realization pressure where endpoint topology alone can lose apportionment information.

Observation 121 is intentionally independent of Observation 120. It asks a different question:

```text
semantic-family correspondence
vs
external-source corroboration
```

If both survive, LOAM gains a more general pattern without introducing a generic relation framework:

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
