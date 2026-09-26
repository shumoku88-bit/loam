# Actual Journal Sort Pressure Harvest — 2026-09-26

Status: **research-qualified / production candidate**

This note records R4 from the repository-wide mathematical compression survey:
measure long-journal sorting pressure before changing the production algorithm.

## Existing production shape

ActualJournalProjection first constructs dated current entries from the already
admitted Actual image, then orders them by:

1. current validity date;
2. EventId token as the tie-breaker.

The current sorter is a left fold of ordered insertion:

```text
current entries
    -> insert first entry into sorted accumulator
    -> insert second entry into sorted accumulator
    -> ...
    -> final ordered journal
```

This is intentionally simple, but repeated insertion into a growing List has a
quadratic-shaped comparison/traversal cost in the long-frontier case.

## Candidate

The candidate keeps the exact journal key and changes only the sorting
mechanics:

```text
same dated current entries
    -> List.mergeSort
    -> same date / EventId ordering
```

No persistence, Actual authority, correction selection, validity selection,
description semantics, Entry shape, or presentation contract changes.

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

## Production decision boundary

A production change is earned, but it should be narrow.

The next production PR may:

- replace only ActualJournalProjection's private sorting mechanics;
- retain the current date-then-EventId order exactly;
- bridge EventMemory.idNodup to Observation 335's no-distinct-ties condition;
- retain existing public Entry and Error shapes;
- retain current fail-closed validity lookup;
- add regression coverage for same-date EventId ordering and ordinary mixed-date
  order;
- measure the production implementation against the qualified benchmark shape.

Do not:

- introduce a retained index;
- persist sorted journal state;
- change Actual authority;
- change correction or validity selection;
- make journal ordering depend on source List position;
- generalize this into a repository-wide sorting abstraction merely because the
  theorem is generic.

## Verdict

**R4 is mathematically and empirically qualified.**

The current journal sort has measured long-frontier pressure, and the candidate
has a general exact-output refinement theorem with an explicit tie boundary.

The earned next move is a small production substitution inside
ActualJournalProjection, after locally discharging the existing EventId
uniqueness invariant.
