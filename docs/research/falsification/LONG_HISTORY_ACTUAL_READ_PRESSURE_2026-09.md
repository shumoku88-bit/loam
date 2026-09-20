# Long-history Actual read pressure — 2026-09-20

Status: **measured production-path checkpoint**

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
