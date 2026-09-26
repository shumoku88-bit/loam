# Actual Journal Sort Pressure Harvest — 2026-09-26

Status: **research-qualified / production promoted**

This note records R4 from the repository-wide mathematical compression survey:
measure long-journal sorting pressure before changing the production algorithm.

## Production shape

ActualJournalProjection constructs dated current entries from the already
admitted Actual image and orders them by:

1. current validity date;
2. EventId token as the tie-breaker.

The original production sorter was a left fold of ordered insertion. The
qualified replacement keeps the exact journal key and now uses:

```text
same dated current entries
    -> List.mergeSort
    -> same date / EventId ordering
```

PR #1326 promoted this substitution after Observation 335 and the paired
benchmark qualified it. No persistence, Actual authority, correction selection,
validity selection, description semantics, Entry shape, or presentation
contract changed.

## Observation 335

Observation 335 isolates the algorithmic refinement from Actual semantics.

For an arbitrary decidable relation, it proves:

- the current fold-of-insertion mechanics is a permutation of the input;
- merge sort is a permutation of the input;
- the current mechanics is pairwise ordered when the relation is transitive and
  total;
- merge sort is pairwise ordered under the same laws;
- the two complete output Lists are exactly equal when, among selected input
  elements, two-way comparison can only hold for the same element.

The last condition is important.

The current insertion mechanics inserts before an existing equal key, while
merge sort is stable. Therefore an arbitrary List containing distinct payloads
with one identical comparison key is not a valid unconditional refinement
domain.

LOAM has a stronger reachable-state boundary: EventMemory carries EventId
uniqueness as the type invariant idNodup. Actual journal entries are built
one-for-one from current EventMemory Events and use EventId as the final
tie-breaker.

A production promotion should discharge that final bridge locally in
ActualJournalProjection rather than weaken Observation 335 into an assumption
about arbitrary Lists.

## Paired benchmark

The temporary benchmark compared:

```text
baseline
    current foldl + ordered insertion

candidate
    List.mergeSort

shared
    identical Entry values
    identical validOn / EventId ordering
```

The timed result Lists were retained. Their complete ordered
(validOn, EventId) signatures were compared after timing and had to be exactly
equal.

Qualified benchmark commit:

    09defa8ba62dc2e9edc29e082bf2167eff59a34f

GitHub Actions run:

    36215703323 — SUCCESS

Runner:

    ubuntu-24.04

Five paired repetitions were taken with alternating execution order.

| Current entries | Insertion sort | mergeSort | Insertion / merge |
| ---: | ---: | ---: | ---: |
| 250 | 6.7 ms | 581 µs | 11.58x |
| 500 | 26.1 ms | 1.3 ms | 19.65x |
| 1,000 | 105.2 ms | 3.0 ms | 34.62x |
| 2,000 | 395.2 ms | 7.0 ms | 55.99x |
| 4,000 | 1.6 s | 16.8 ms | 96.18x |
| 8,000 | 6.5 s | 36.6 ms | 178.90x |

## Interpretation

The pressure is not marginal.

The insertion path grows from 6.7 ms at 250 entries to 6.5 s at 8,000 entries,
while merge sort remains at 36.6 ms at the largest measured case.

The widening ratio is consistent with the structural expectation:

```text
repeated insertion into growing List
    -> quadratic-shaped work

divide-and-merge ordering
    -> n log n-shaped work
```

The useful result is not merely that merge sort is faster on one runner. The
experiment confirms that R4 identified a real algorithmic scaling boundary in a
production path, and Observation 335 supplies the general refinement theorem
needed to keep the semantic question separate from the implementation choice.

## Production promotion

PR #1326 (`perf(actual): promote qualified journal merge sort`) replaced only
the private ActualJournalProjection sorting mechanics.

Production now uses `List.mergeSort` with the same date-then-EventId relation.
The reachable Actual domain retains EventId uniqueness, which is the local
bridge required by Observation 335's exact-output theorem.

The promotion introduced no retained index, persistent sorted state, authority
change, or repository-wide sorting abstraction.

## Verdict

**R4 is mathematically, empirically, and operationally harvested.**

The long-frontier pressure was measured, Observation 335 qualified the exact
refinement boundary, and PR #1326 promoted the narrow merge-sort substitution.

Observation 335 remains live because it continues to document the theorem behind
the production refinement.
