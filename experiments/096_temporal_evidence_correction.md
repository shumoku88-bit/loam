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

## Expected positive boundary

The positive model asks TLC to preserve:

- type safety;
- no retained knowledge before its learned time;
- closed correction references;
- correction target and replacement refer to the same Event;
- replacement is learned with the correction and after the target;
- at most one admitted temporal fact per Event at every knowledge time;
- append-only fact and correction retention;
- after correction, current knowledge resolves to `d1`;
- after correction, historical `as-known` views still reconstruct `d2` at times 1 and 2 and `d1` at time 3.

## Deliberate boundary

The stronger claim is:

```text
retain only the final current frontier
  -> enough to reconstruct past knowledge
```

The boundary configuration asks TLC to reject that claim.

Once `t0` is removed from the current frontier and only `t1` remains, filtering the current frontier back to knowledge time 1 yields no temporal answer because `t1` was not learned until time 3.

The full append-only retained history can still answer `d2` at time 1.

So, if the expected counterexample is reachable:

```text
current frontier
  != historical retained knowledge
```

and dropping superseded temporal evidence would erase a fact about what LOAM previously knew.

## Interpretation boundary

If the expected receipt holds, it supports only this qualified statement:

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
