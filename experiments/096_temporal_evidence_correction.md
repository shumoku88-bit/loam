# Observation 096 — Can temporal evidence be corrected append-only?

## Question

Observation 095 found that selected valid-day queries do not force time to be embedded inside `Event`; a later typed attachment to stable Event identity can carry the same selected temporal meaning.

The next pressure is correction:

> If LOAM first learns the wrong valid day and later learns a replacement day, can both the current temporal answer and the historical `as-known` answer be reconstructed without rewriting either the Event or the earlier temporal fact?

## Pressure case

One retained Event `E0` receives temporal evidence in two knowledge moments:

```text
knowledge time 1
  t0: E0 -> d2

knowledge time 3
  t1: E0 -> d1
  c0: t0 -> t1
```

The correction is about temporal evidence, not about the Event payload.

At the final state, two different questions should remain answerable:

```text
what did LOAM know at knowledge time 1?
  -> d2

what is the currently admitted temporal answer at knowledge time 3?
  -> d1
```

## Why TLA+ is earned

The new distinction is temporal in two senses at once:

- the temporal fact says when an Event is valid;
- the correction itself is learned later and changes the current admitted answer.

The experiment therefore needs transitions and an `as-known at k` projection over one append-only retained history.

## Model

`TemporalEvidenceCorrection.tla` keeps only:

- one stable Event identity;
- two temporal fact identities;
- one correction identity;
- two abstract valid-day values;
- bounded knowledge time `0..3`;
- append-only retained temporal facts;
- append-only retained temporal corrections.

Experiment-local meanings are fixed deliberately:

```text
t0
  target Event = e0
  valid day    = d2
  learned      = 1

t1
  target Event = e0
  valid day    = d1
  learned      = 3

c0
  target       = t0
  replacement  = t1
  learned      = 3
```

The correction publication atomically retains `t1` and `c0`, so there is no intermediate state in which two uncorrected current temporal answers compete for the same Event.

## Projections

For any knowledge time `k`:

```text
KnownFactsAt(k)
  = retained facts whose learned time <= k

KnownCorrectionsAt(k)
  = retained corrections whose learned time <= k

FrontierAt(k)
  = KnownFactsAt(k) minus correction targets known by k

DaysAt(k, event)
  = valid-day answers on that historical frontier
```

This is deliberately different from throwing away superseded facts and retaining only the final current frontier.

## Observed TLC 1.7.4 receipt

The positive configuration completed successfully:

```text
Model checking completed. No error has been found.
8 states generated
8 distinct states found
0 states left on queue
depth 6
```

The checked boundaries include:

- type safety;
- no retained knowledge before its learned time;
- closed correction references;
- target and replacement refer to the same Event;
- replacement is learned with the correction and after the target;
- at most one admitted temporal fact per Event at every knowledge time;
- fact and correction retention are append-only;
- after correction, current knowledge resolves to `d1`;
- the retained history still reconstructs `d2` at knowledge times 1 and 2 and `d1` at time 3.

The first CI attempt stopped on a bounded terminal branch that advanced to `now = 3` without learning any temporal fact. That was a TLC deadlock report, not a safety counterexample. The workflow was changed to use `-deadlock` for this bounded exploration; the TLA+ model and semantic claims were not changed.

## Deliberate boundary observed

The stronger claim was:

```text
retain only the final current frontier
  -> enough to reconstruct past knowledge
```

TLC rejected it as expected:

```text
Invariant CurrentFrontierCanReconstructPastKnowledge is violated.
```

The counterexample reaches:

```text
State 3
  now = 1
  retainedFacts = {t0}
  retainedCorrections = {}

State 6
  now = 3
  retainedFacts = {t0, t1}
  retainedCorrections = {c0}
```

At the final state the current frontier excludes `t0` and admits `t1`, so current knowledge answers `d1`.

But if only that final frontier were retained, filtering it back to knowledge time 1 yields no answer because `t1` was not learned until time 3. The full append-only retained history still reconstructs the historical `d2` answer.

So the observed boundary is:

```text
current frontier
  != historical retained knowledge
```

Dropping superseded temporal evidence can erase a fact about what LOAM previously knew even when the current answer remains correct.

## Interpretation boundary

The bounded observation supports this qualified statement:

```text
append-only temporal fact history
+ append-only correction relation
+ learned-time filtering
  can support both
    current valid-day answer
    historical as-known answer
```

It does not yet establish a production temporal correction type or persistence layout.

The model intentionally mirrors the already-earned correction shape only at the semantic level: retained targets remain historical facts while targets leave the admitted current frontier.

## Non-goals

Observation 096 does not earn:

- a production `TemporalFact` type;
- a production temporal correction type;
- a separate persistence stream;
- Event mutation;
- timestamps, timezones, or total chronology;
- automatic inference of learned time;
- correction chains longer than the bounded witness;
- conflict or multi-parent temporal resolution semantics;
- CurrentQuantity, CLI, or wire-format changes;
- any private household data change.

## Practical Core impact

None.
