# Long-history Actual read pressure — 2026-09-20

Status: **measured production-path checkpoint / million-event probe complete**

## Question

Can LOAM keep normalized Actual authority as the source of truth while large
histories remain fast enough for ordinary review?

The pressure is specifically against this failure mode:

```text
slow projection
    -> introduce a cached/read-model authority
    -> cache drift becomes household meaning
```

The preferred shape is instead:

```text
canonical Actual evidence
    -> full fail-closed admission
    -> transient acceleration indexes
    -> disposable projection
```

## Prior benchmark

PR #1052 established a production-path benchmark using `loam review`.

The original correction-free fixture measured:

| Events | Original median |
| ---: | ---: |
| 1,000 | 0.115 s |
| 5,000 | 1.900 s |
| 10,000 | 7.746 s |
| 50,000 | 180.490 s |

PRs #1055–#1059 then removed the dominant quadratic work while preserving the
same proof-carrying Core boundaries.

The final historical 50k result was about 0.322 s.

## Current-main regression check

On 2026-09-20, current main was remeasured on `ubuntu-latest` using the same
production `loam review` path.

Plain fixture:

| Events | Median |
| ---: | ---: |
| 1,000 | 0.044 s |
| 5,000 | 0.069 s |
| 10,000 | 0.092 s |
| 50,000 | 0.346 s |

This shows no material regression from the earlier Stage-5 result.

## Hidden shape problem

The existing benchmark used `NODESC` Events and no Corrections.

That is not representative of the current household Actual history.

At the time of this audit, current `loam-data/actual.loam` contained:

```text
638 Events
637 described
1 without description
5 REPLACES rows
```

A description-heavy synthetic history exposed another superlinear path.

Before the fix:

| Events | Description-heavy median |
| ---: | ---: |
| 1,000 | 0.059 s |
| 5,000 | 0.481 s |
| 10,000 | 1.776 s |

Static inspection found two independent causes:

1. `EventDescriptionMemory.ofEntries?` used direct large-list `List.Nodup`;
2. `ActualReview.recordsFromActualImage` performed a linear description lookup
   for every Event.

## Selected optimization

The production change is deliberately narrow.

### Description admission

`EventDescriptionMemory.ofEntries?` now uses the existing proof-producing
hash-backed duplicate admission.

The transient HashSet is not retained authority.

The resulting Core field remains exactly:

```lean
(entries.map EventDescription.event).Nodup
```

So duplicate-description refusal and representation semantics are unchanged.

### Review projection

Canonical Actual review builds one transient:

```text
EventId token -> description text
```

HashMap from already-admitted description evidence and uses it only while
constructing review records.

The map is neither persisted nor independently trusted.

## Result

Same-runner qualification after the change:

| Events | Plain median | Description-heavy median |
| ---: | ---: | ---: |
| 1,000 | 0.046 s | 0.042 s |
| 5,000 | 0.065 s | 0.068 s |
| 10,000 | 0.086 s | 0.099 s |
| 50,000 | 0.331 s | 0.411 s |

The description-heavy 10k path improved from:

```text
1.776 s -> 0.099 s
```

and 50k described history completes in about 0.41 s on the selected runner.

The optimization therefore removes the newly measured description-specific
quadratic layer without changing authority.

## Correction-heavy pressure remains open

A separate fixture where every odd Event replaces the preceding Event measured:

| Events | Correction-heavy median |
| ---: | ---: |
| 1,000 | 0.088 s |
| 5,000 | 1.170 s |
| 10,000 | 4.436 s |

That shape is intentionally **not** fixed in this change.

Likely contributors include:

- direct `EventCorrectionMemory` duplicate admission;
- replacement frontier endpoint uniqueness;
- list-based replacement traversal;
- per-Event correction lookup during ActualReview.

Correction-heavy history has different semantic obligations from description
lookup and deserves a separate measured change.

## Correction-heavy follow-up: resolved

Issue #1134 subsequently qualified and promoted the correction-heavy optimization.

PR #1148 linearized the measured repeated-work layers while preserving the
existing fail-closed semantics:

- raw Correction duplicate admission uses proof-producing hash-backed admission;
- Correction frontier admission/reference/cycle checks use a transient indexed
  representation;
- Actual Review replacement lookup uses transient indexing;
- general equivalence theorems preserve correspondence with the legacy
  specification.

A later current-main remeasurement on the production `loam review` path reported:

| Events | Run 1 median | Run 2 median |
| ---: | ---: | ---: |
| 1,000 | 0.0110 s | 0.0136 s |
| 5,000 | 0.0340 s | 0.0426 s |
| 10,000 | 0.0659 s | 0.0748 s |
| 50,000 | 0.4249 s | 0.4075 s |

The old 10k correction-heavy result was 4.436 s. The measured quadratic bend
was therefore removed without turning the transient index into household
authority. Issue #1134 was closed after this qualification.

## Million-event long-horizon probe — 2026-09-25

PR #1317 ran a measurement-only probe on one `ubuntu-24.04` GitHub-hosted
runner at commit `4acdba90b0be5242d5974ce2c9d2dd63c27b1b45`.

The benchmark reused `tools/benchmark-actual-read.py` and the production
`loam review` entrance. Build time and fixture generation were outside the
timed region. Each size was measured three times and the median retained.

All three history shapes completed through one million Events:

| Events | Plain median | Description-heavy median | Correction-heavy median |
| ---: | ---: | ---: | ---: |
| 50,000 | 0.401 s | 0.543 s | 0.622 s |
| 100,000 | 0.935 s | 1.231 s | 1.507 s |
| 250,000 | 2.655 s | 3.360 s | 3.974 s |
| 500,000 | 5.678 s | 7.207 s | 8.457 s |
| 1,000,000 | 11.938 s | 15.073 s | 16.951 s |

The high end remains close to linear in this measured range:

- Plain, 500k -> 1M: 2.10x wall time for 2x Events.
- Description-heavy, 500k -> 1M: 2.09x.
- Correction-heavy, 500k -> 1M: 2.00x.
- From 250k -> 1M, 4x Events cost 4.50x / 4.49x / 4.27x respectively.

This is an empirical scaling result, not an asymptotic-complexity proof. Across
the full 50k -> 1M range, wall time grows somewhat faster than the 20x Event
increase, so the result should not be described as perfectly linear.

The important observation is narrower: no renewed quadratic bend appears
through one million Events, including the correction-heavy shape, and the
production read/review path remains practical at a history size far beyond
ordinary household use.

The measurement does not earn a new production optimization. PR #1317 therefore
remains measurement-only evidence rather than a change to household semantics.

## Architectural finding

This pressure test supports the existing boundary:

```text
authority
    = retained normalized evidence + proof-carrying admission

performance structure
    = transient, rebuildable, derived index
```

A performance problem did not require a materialized-view authority, a database
cache contract, or a second household truth.

That is the property worth preserving as further long-history bottlenecks are
measured.
