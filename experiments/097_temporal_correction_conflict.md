# Observation 097 — Does later learned time settle a temporal correction conflict?

## Question

Observation 096 showed that temporal evidence can be corrected append-only while preserving both the current answer and historical `as-known` answers.

Observation 022 already established a more general correction boundary: sibling Corrections can remain an unresolved current frontier, and arrival chronology need not become authority.

The temporal case adds a tempting extra signal:

```text
learned time
```

The new question is:

> If two temporal Corrections target the same earlier temporal fact, and one sibling is learned later than the other, does the later learned time itself settle which valid-day interpretation is authoritative?

## Pressure case

One Event `e0` first has:

```text
knowledge time 1
  t0: e0 -> d0
```

Then two sibling Corrections appear:

```text
knowledge time 2
  c1: t0 -> t1
  t1: e0 -> d1

knowledge time 3
  c2: t0 -> t2
  t2: e0 -> d2
```

So:

```text
learned(t2) > learned(t1)
```

but structurally the retained correction graph is:

```text
       t1
      /
t0 --
      \
       t2
```

Both `t1` and `t2` are terminal candidates because both Corrections target `t0` rather than one correcting the other.

## Why TLA+ is earned

The static sibling shape is already known from Observation 022.

What is new is the transition through knowledge time:

```text
time 2
  one admitted terminal candidate

time 3
  later learned sibling appears
```

TLA+ can check whether the later observation should structurally erase the earlier sibling, or whether the frontier instead becomes an explicit conflict.

## Model

`TemporalCorrectionConflict.tla` keeps only:

- one Event identity;
- three temporal fact identities;
- two sibling correction identities;
- three abstract valid-day values;
- bounded learned time `0..3`;
- append-only retained fact and correction sets.

The model derives two different projections:

```text
EventFrontierAt(k, e0)
  = all terminal temporal facts known at k

LatestLearnedFrontierAt(k, e0)
  = only the terminal fact with greatest learned time
```

The second projection is deliberately treated as a candidate policy, not as built-in authority.

## Expected positive boundary

The positive model asks TLC to preserve:

- type safety;
- no retained fact or correction before its learned time;
- closed correction references;
- same-Event correction;
- replacement learned with its correction and after the target;
- after the first correction and before the sibling, the frontier is `{t1}`;
- after both sibling Corrections, the frontier is `{t1, t2}`;
- learned order does not remove `t1` from the frontier;
- the latest-learned selector can still identify `{t2}` as a separate derived candidate.

## Deliberate boundary

The stronger claim is:

```text
latest learned terminal candidate
  = structural current frontier
```

The boundary configuration asks TLC to reject that claim once the later sibling appears.

If the intended counterexample is reachable, the final state should have:

```text
structural frontier
  {t1, t2}

latest learned candidate
  {t2}
```

That would mean:

```text
learned later
  can identify a later-known sibling

learned later
  -/-> authority over a sibling conflict
```

unless LOAM explicitly adds a last-learned-wins policy or another authority/resolution fact.

## Interpretation boundary

A successful receipt would not prove that last-learned-wins is an invalid application policy.

It would show only that such a policy is **additional semantics**. The correction relation plus learned-time metadata do not need to erase the other terminal candidate by themselves.

This keeps the existing distinctions aligned:

```text
learned time
  = when LOAM could know a claim

correction graph
  = how interpretations revise one another

authority / resolution
  = a separate question
```

## Non-goals

Observation 097 does not earn:

- a production temporal fact type;
- a production temporal correction type;
- last-learned-wins or first-learned-wins policy;
- a production Resolution type for temporal conflicts;
- source authority or trust ranking;
- persistence, CLI, wire-format, or CurrentQuantity changes;
- timestamps, timezones, or total chronology;
- private household data changes.

## Practical Core impact

None.
