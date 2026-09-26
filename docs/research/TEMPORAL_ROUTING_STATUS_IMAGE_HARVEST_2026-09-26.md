# Temporal Routing Fixed-Time Status Image Harvest — 2026-09-26

Status: **research-qualified / production deferred**

This note records the temporal change-point result from the repository-wide
mathematical compression survey.

## Existing focused specification

`RoutingHistory.statusAt history subject validOn` is deliberately simple:

```text
one subject + one time
    -> fold the retained RoutingHistory
    -> select the latest visible assertion
    -> managed / unmanaged / unrouted
```

List representation order is already proved not to determine the answer.

That direct function remains an excellent focused semantic specification.

## Repeated bulk pressure

Some production readers ask many subjects at one shared observation coordinate.

Examples include:

- `ActualRoutingReview.partitionApproved`, which asks admitted Loci at one
  `observedAt`;
- Scheduled pressure classification, which asks many Scheduled routing subjects
  at one `observedAt`.

Repeated focused calls have the shape:

```text
subject A -> scan entire routing history
subject B -> scan entire routing history
subject C -> scan entire routing history
...
```

A candidate fixed-time image instead has the shape:

```text
routing history + observedAt
    -> scan history once
    -> transient latest-visible map
    -> many subject lookups
```

The retained RoutingHistory remains authority. The image is derived only.

## Observation 334

Observation 334 qualifies the Actual-routing / `LocusId` case.

For generic ordered Time, it builds:

```text
LatestIndex Time
    = HashMap String (RoutingEntry LocusId Time)
```

where the String key is exactly `LocusId.token`.

For each visible entry, the image retains only the latest effective assertion
for that Locus at the fixed query coordinate.

A general theorem proves pointwise equality between transient-image lookup and a
research latest-visible specification mirroring the production selection rule.

The production `combineLatest` helper is file-private, so the observation does
not pretend to prove a cross-file general theorem against that hidden helper.
Closed executable pressure compares the image against public `statusAt` across:

- managed;
- unmanaged;
- unrouted;
- before the first change;
- exact change coordinates;
- after later changes.

If this candidate is ever promoted, the final general bridge should live inside
`HistoricalRouting.lean`, where the private helper is visible.

## Paired benchmark

The benchmark compared:

```text
baseline
    statusAt for every queried subject
    -> history rescanned per subject

candidate
    build fixed-time LatestIndex once
    -> HashMap lookup per subject
```

The actual timed status lists were retained and compared for exact equality
after timing.

Expanded qualified benchmark commit:

    3f7e0df7f22c7a99fd73976881a4557a14bc1a00

GitHub Actions run:

    36214696087 — SUCCESS

Runner:

    ubuntu-24.04

Five paired repetitions were taken with alternating execution order.

| Subjects | Changes / subject | History entries | Focused statusAt | Status image | Focused / image |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4 | 4 | 3 µs | 7 µs | 0.42x |
| 1 | 64 | 64 | 24 µs | 55 µs | 0.43x |
| 4 | 1 | 4 | 8 µs | 11 µs | 0.72x |
| 4 | 4 | 16 | 21 µs | 21 µs | 1.00x |
| 4 | 16 | 64 | 75 µs | 61 µs | 1.22x |
| 8 | 2 | 16 | 39 µs | 31 µs | 1.25x |
| 8 | 4 | 32 | 74 µs | 42 µs | 1.76x |
| 16 | 4 | 64 | 272 µs | 97 µs | 2.80x |
| 16 | 16 | 256 | 1.0 ms | 258 µs | 4.09x |
| 64 | 16 | 1,024 | 16.4 ms | 1.0 ms | 15.00x |
| 64 | 64 | 4,096 | 64.1 ms | 3.5 ms | 17.87x |
| 256 | 16 | 4,096 | 252.8 ms | 4.2 ms | 58.81x |
| 256 | 64 | 16,384 | 1.0 s | 14.3 ms | 70.53x |

An earlier large-shape run (36214268855) showed the same trend. The expanded run
above is the retained decision measurement because it also covers small routing
histories.

## Interpretation

The crossover is real.

### Focused lookup should remain direct

For one subject the transient image is more than twice as expensive in these
measurements.

At four subjects with one change each it is still slower, and at four subjects
with four changes each the paths are effectively equal.

Therefore replacing every `statusAt` call with an index would be a regression
for the small focused case and would obscure a very good direct specification.

### Bulk lookup has a strong scaling candidate

As both subject count and historical change count grow, repeated full-history
scans become dominant.

The fixed-time image becomes increasingly effective:

- 8 subjects / 32 entries: ~1.76x;
- 16 subjects / 64 entries: ~2.80x;
- 64 subjects / 4,096 entries: ~17.87x;
- 256 subjects / 16,384 entries: ~70.53x.

This is exactly the expected factorization:

```text
many fixed-time questions
    -> share temporal selection once
    -> reuse compact latest-visible image
```

## Production decision boundary

**Do not promote yet.**

The current production routing workloads have not been measured as large enough
to justify another transient representation or a threshold/hybrid mechanism.

The qualified future move is narrow:

```text
focused routing question
    -> keep statusAt

bulk same-time routing question under measured pressure
    -> build transient fixed-time status image once
    -> lookup subjects from the image
```

Do not:

- persist the image;
- make it routing authority;
- replace focused `statusAt`;
- add a cardinality threshold without production pressure;
- merge Actual and Scheduled routing authorities merely because their temporal
  selection algebra is similar.

## Verdict

**Harvest #3 is mathematically and empirically qualified, but production
promotion is deferred.**

The useful result is not “HashMap is faster.” It is the discovered temporal
factorization:

```text
same observation time + many subjects
    -> temporal selection is shareable
```

while:

```text
one subject
    -> the direct historical fold remains the better representation
```

This distinction should be retained for a future pressure-driven optimization.
