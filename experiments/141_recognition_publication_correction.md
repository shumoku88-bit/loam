# Observation 141 — Recognition correction across a published horizon

Status: **experiment under qualification**

## Question

Observation 140 qualified that accounting recognition can be a projection over time coordinates rather than one scalar `RecognitionTime`.

Observation 096 had already qualified a separate temporal law:

```text
append-only fact history
+ append-only correction relation
+ learned-time filtering
    -> current answer
    -> historical as-known answer
```

The next pressure is where those two lines meet:

> If a recognition definition is later corrected after a period view was already published, can LOAM preserve both the old published answer and the current restated answer without mutating old evidence or introducing a canonical `ClosedPeriod` / lock state?

This observation uses TLA+ because the relevant distinction is not only static independence. Publication happens, then later knowledge arrives, then the admitted current projection changes while the prior published answer must remain reconstructable.

## Minimal specimen

One recognition quantity is fixed at 12.

The selected query range is the first half of the service horizon.

At knowledge time 1, LOAM learns experiment-local recognition fact `r0`, mirroring Observation 140's immediate shape:

```text
whole service quantity = 12
selected query amount  = 12
```

At knowledge time 2, an experiment-local publication receipt `p0` records that the selected view was published using knowledge through time 2.

At knowledge time 3, LOAM learns replacement recognition fact `r1` plus correction `c0 : r0 -> r1`, mirroring Observation 140's spread shape:

```text
whole service quantity = 12
selected query amount  = 6
```

The old and new recognition facts are both retained. The correction changes the admitted frontier; it does not delete `r0`.

The model intentionally does not distinguish whether the replacement arose because the service range was corrected, the recognition definition was corrected, or both. That taxonomy is not the question yet. The first question is whether a published historical projection and a later restatement can coexist over one retained history.

## Projection shape

For knowledge horizon `k`:

```text
KnownFactsAt(k)
  = retained recognition facts learned by k

KnownCorrectionsAt(k)
  = retained corrections learned by k

FrontierAt(k)
  = KnownFactsAt(k) minus correction targets known by k

QueryAmountsAt(k)
  = selected recognition amount from that frontier
```

The publication receipt carries an experiment-local `knownThrough = 2` coordinate, so its answer is always derived as:

```text
PublishedQueryAmounts(p0)
  = QueryAmountsAt(2)
```

The current restated answer is:

```text
QueryAmountsAt(now)
```

After the correction is learned at time 3, the intended pair is therefore:

```text
as published at horizon 2 = 12
current restated           = 6
```

## Positive safety claims

The positive TLC configuration checks:

- type safety;
- no retained fact, correction, or publication before its learned time;
- closed correction references;
- replacement learned with the correction and after the target;
- publication horizons do not point into future knowledge;
- at most one admitted recognition fact at each knowledge horizon;
- the published view remains reconstructable as 12;
- after correction, the current restated view is 6;
- published and current-restated answers can coexist without contradiction;
- the whole-service quantity remains 12 for every admitted recognition frontier;
- retained facts, corrections, and publication receipts are append-only.

## Deliberately too-strong boundaries

### 1. Published answer always equals current answer

The first negative configuration checks the deliberately too-strong invariant:

```text
PublishedProjectionAlwaysEqualsCurrent
```

Expected: **TLC counterexample** after `c0` is learned.

The useful result is not that one answer is more true than the other. They answer different coordinate questions:

```text
what was published using knowledge through K2?
what is the restated answer using knowledge through K3?
```

A mutable ledger often expresses this conflict through locks, reopenings, discrepancy workflows, or rewritten rows. This specimen asks whether LOAM can instead preserve both projections.

### 2. Final current frontier is enough to reconstruct publication

The second negative configuration checks:

```text
CurrentFrontierCanReconstructPublished
```

Expected: **TLC counterexample**.

After correction, the final frontier contains only `r1`. Filtering that final frontier back to knowledge time 2 yields no recognition fact because `r1` was not learned until time 3.

The full retained history still contains `r0`, so `FrontierAt(2)` reconstructs the published amount 12.

This should reinforce Observation 096's boundary in a recognition/publication setting:

```text
current frontier
    !=
historical retained knowledge
```

## Interpretation gate

If all expected results qualify, the bounded candidate is:

```text
append-only recognition evidence
+ append-only correction provenance
+ publication/query knowledge horizon
+ time-coordinate projection
    -> historical as-published view
    -> current restated view
```

without requiring truth-preserving mutation of old rows.

The result may also show why a lock flag is not necessary **for preserving truth**. A product may still choose lock permissions for workflow, tax, governance, or operational safety. That is a separate authority question.

## What publication evidence means here

`p0` is experiment-local evidence that a view was actually published at a known horizon.

This observation does **not** yet prove that a canonical `PublicationReceipt` belongs in Practical Core. If a caller already supplies a historical knowledge horizon, LOAM can ask an `as-known` query without a publication object.

But the question:

> "what did I actually sign off / publish then?"

contains provenance beyond merely knowing that horizon existed. If future dogfood needs that question, some evidence equivalent to publication provenance may become independently meaningful.

## Not earned by this observation

Even if the expected result qualifies, it does not establish:

- canonical `ClosedPeriod`;
- mutable lock state;
- canonical `PublicationReceipt`;
- canonical `RecognitionSchedule`;
- canonical `RecognitionTime`;
- a production recognition-policy identity;
- invoice, accrual, deferred-expense, or deferred-revenue objects;
- tax filing semantics;
- user permissions around locked periods;
- reopening workflow;
- correction conflict resolution beyond the one bounded replacement;
- persistence, CLI/TUI, or Practical Core changes.

## Tool choice

**TLA+ / TLC.**

Alloy was enough for Observation 140's information-independence question. Observation 141 adds ordering and retained-history pressure:

```text
learn old recognition
-> publish view
-> learn correction
-> preserve historical projection while current projection changes
```

That transition structure earns TLA+ here.
