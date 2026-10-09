# Incremental daily delta cost probe (2026-10)

Status: **manual research benchmark**, not product code or canonical state.
Parent research: [Incremental daily delta law](INCREMENTAL_DAILY_DELTA_LAW_2026-10.md)
(PR #1864). No new optimization has been promoted.

## Question

Does the conservative one-root comparison introduced in PR #1864 beat an
independent full read? Distinguish the arithmetic delta cost from **discovering
the changed root**, and keep normalized Actual admission separate.

## How to run

From the LOAM checkout (with Lean 4 toolchain installed):

```sh
lake build Loam.Tests.IncrementalCorrectedFrontier
lake env lean Loam/Tests/IncrementalDeltaCostProbe.lean
# Optional bounded sizes (comma-separated, no spaces):
LOAM_DELTA_BENCH_SIZES=100,300,600,1000 lake env lean Loam/Tests/IncrementalDeltaCostProbe.lean
```

The benchmark refuses sizes above 10,000 Events because the current root
matching algorithm uses a linear `List.find?` per root, which admits O(N²)
behavior. Avoid a million-event run of that path without changing the
algorithm or adding a resource guard.

The fixtures contain one balanced JPY movement per Event, one replacement
Event at the end, and one admitted correction from an old stable root to that
replacement. They are synthetic and **not household data**. Every pair of
images goes through existing `Loam.Persistence.admitActualImage?`. All
compared approaches must return exactly the same two-day results.

## Measured paths (same fixture, same process)

| Column | What it measures | What it excludes |
| --- | --- | --- |
| `admit_pair_us` | Construct and fully qualify both Actual images from synthetic data | Disk decode; CLI/TUI and household context |
| `full_read_us` | Reproject current records and sum two buckets from the *new* admitted image | Admission; file load |
| `root_scan_delta_us` | Call current `oneRootReplacement?` over *both* admitted images and apply delta to previously calculated old totals | Admission; precomputation of old totals |
| `known_delta_us` | Apply a pre-known old/new contribution to two precomputed old totals | Discovery, admission, cache validation, publication |

All are median of three trials in microseconds. The known-delta path is a
**lower-bound arithmetic scenario**, not a working end-to-end speedup.
Build/fixture setup is excluded from the three paired read timings. The
`admit_pair_us` path includes fixture construction and should not be
mistaken for startup or reload time.

## Evaluation gates

- If `root_scan_delta_us` is slower than `full_read_us`, do not install
  the existing scanned delta as a performance optimization.
- Even if root scanning wins, no cache is warranted unless real user-facing
  reports perform repeated same-generation queries and admission, invalidation,
  failure cases, memory use, and publication/recovery are accounted for.
- Separately use existing `tools/benchmark-actual-read.py` for real compiled
  `loam review` decode/qualification/review scaling. Do not add that figure to
  an in-memory microbenchmark as though workloads were identical.
- Larger 10k/100k/1M tests should benchmark **linear or indexed** change
  discovery only after a concrete hot report earns it. Never run the existing
  quadratic candidate blindly at those scales.

A CI smoke run, if present, qualifies compilation, non-refusal and answer
equality for bounded synthetic fixtures. Timing on shared CI machines is
descriptive, **not** a performance gate or a reliable MacBook speed claim.
