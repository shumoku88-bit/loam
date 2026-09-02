# Observation 098 — Can a later Resolution preserve an earlier unresolved temporal view?

## Question

Observation 097 showed that a later learned sibling Correction does not automatically become authoritative. Once both siblings are known, the temporal frontier can truthfully remain unresolved:

```text
{t1, t2}
```

Observation 023 already showed structurally that a whole-frontier Resolution can settle a generic correction conflict append-only.

The new temporal question is:

> If a temporal conflict is unresolved at one knowledge time and later resolved explicitly, can LOAM preserve both the new settled current answer and the historical fact that the earlier `as-known` view was unresolved?

## Pressure case

One Event `e0` accumulates temporal knowledge:

```text
knowledge time 1
  t0: e0 -> d0

knowledge time 2
  c1: t0 -> t1
  t1: e0 -> d1

knowledge time 3
  c2: t0 -> t2
  t2: e0 -> d2
```

At knowledge time 3:

```text
frontier = {t1, t2}
state    = unresolved
```

At knowledge time 4, a Resolution is admitted over the whole conflict frontier:

```text
h0.parents = {t1, t2}
r0: e0 -> d1
```

The intended current frontier becomes:

```text
{r0}
```

The earlier alternatives remain retained provenance.

## Why TLA+ is earned

The key property spans multiple knowledge moments:

```text
time 3  unresolved
   |
   | later explicit Resolution
   v
time 4  settled
```

The same retained history must support both an `as-known at 3` projection and a current `as-known at 4` projection.

## Model

`TemporalConflictResolutionHistory.tla` keeps only:

- one Event identity;
- four temporal fact identities: `t0`, `t1`, `t2`, `r0`;
- two sibling Correction identities: `c1`, `c2`;
- one Resolution identity: `h0`;
- three abstract valid-day values;
- bounded learned time `0..4`;
- append-only retained fact, Correction, and Resolution sets.

The Resolution is admitted only when the current temporal frontier is exactly:

```text
{t1, t2}
```

and it names that whole frontier as its parents.

## Projections

For any knowledge time `k`:

```text
KnownFactsAt(k)
KnownCorrectionsAt(k)
KnownResolutionsAt(k)
```

filter the one retained history by learned time.

A fact leaves the frontier when it is consumed by either:

```text
a known Correction target
or
a known Resolution parent relation
```

So the same retained final history should derive:

```text
FrontierAt(3) = {t1, t2}
FrontierAt(4) = {r0}
```

## Expected positive boundary

The positive model asks TLC to preserve:

- type safety;
- no retained knowledge before its learned time;
- closed same-Event Correction references;
- closed whole-frontier Resolution references;
- `{t1}` after the first Correction alone;
- `{t1, t2}` after both sibling Corrections and before Resolution;
- `{r0}` after Resolution;
- historical `FrontierAt(3) = {t1, t2}` even after Resolution is retained;
- all conflicting facts and Corrections remain retained after Resolution.

## Deliberate boundary

The stronger claim is:

```text
retain only the final current frontier
  -> enough to reconstruct the earlier unresolved view
```

The boundary configuration asks TLC to reject it.

At the resolved final state:

```text
final frontier = {r0}
```

Filtering only that final frontier back to knowledge time 3 yields no candidate because `r0` is learned at time 4.

But the complete append-only retained history should still reconstruct:

```text
FrontierAt(3) = {t1, t2}
```

If this counterexample is reachable, then:

```text
resolved current frontier
  != historical unresolved knowledge
```

and conflict history itself is information worth retaining when `as-known` questions matter.

## Interpretation boundary

A successful receipt would support only this qualified statement:

```text
append-only temporal facts
+ append-only Corrections
+ append-only whole-frontier Resolution
+ learned-time filtering
  can preserve both
    past unresolved view
    later settled view
```

It would not establish where Resolution authority comes from or whether `r0` carries the objectively correct valid day.

## Non-goals

Observation 098 does not earn:

- a production temporal fact type;
- a production temporal Correction or Resolution type;
- source authority or trust ranking;
- automatic conflict resolution;
- a production Date/Time type;
- timestamps, timezones, or total chronology;
- persistence, CLI, wire-format, or CurrentQuantity changes;
- private household data changes.

## Practical Core impact

None.
