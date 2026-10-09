# Incremental daily delta cost probe (2026-10)

Status: **measured research checkpoint; executable probe intentionally retired**. No product code, canonical state, retained runtime cache, or new permanent benchmark workflow.
Parent research: [Incremental daily delta law](INCREMENTAL_DAILY_DELTA_LAW_2026-10.md)
(PR #1864). No new optimization has been promoted.

## Question

Does the conservative one-root comparison introduced in PR #1864 beat a
simple same-generation recomputation? Distinguish arithmetic from **discovering
the changed root**, and compare against a straightforward single-fold read from
LOAM's existing hash-indexed ActualReview records. Keep normalized Actual
admission separate.

## Evidence and reproducing the experiment

The executable test and one-off GitHub Actions workflow were built and
qualified on a disposable PR branch, but **deliberately removed from the final
PR diff** because they do not establish a useful production optimization.
This avoids carrying ~240 lines of research code and a dedicated CI workflow
indefinitely.

- Archived measured source: [commit 76792407](https://github.com/shumoku88-bit/loam/commit/76792407fe8d0e89da1471e67b109ca6a6509dd5)
- Source run (exact root counts, original direct fold):
  [CI 37936221060](https://github.com/shumoku88-bit/loam/actions/runs/37936221060)
- Corrected test reusing the existing hash-indexed ActualReview projection:
  [CI 37936317081](https://github.com/shumoku88-bit/loam/actions/runs/37936317081)

To reproduce **in an isolated worktree**, use the archived commit, not today's
`main`:

```sh
git worktree add /tmp/loam-delta-probe 76792407fe8d0e89da1471e67b109ca6a6509dd5
cd /tmp/loam-delta-probe
lake build Loam.Tests.IncrementalCorrectedFrontier
LOAM_DELTA_BENCH_SIZES=40,100,200 lake env lean Loam/Tests/IncrementalDeltaCostProbe.lean
```

Remove the temporary worktree when finished. This is a diagnostic experiment,
not an operation on household data. The probe refuses sizes above 10,000
Events because repeated linear root lookups make larger trials impractical.
All fixtures are synthetic and pass LOAM's existing normalized Actual admission.

## Measured paths (same fixture, same process)

| Column | What it measures | What it excludes |
| --- | --- | --- |
| `admit_pair_us` | Construct and fully qualify both Actual images from synthetic data | Disk decode; CLI/TUI and household context |
| `full_read_ns` | Existing research full read: project records, select and sum each bucket separately | Admission; file load; **this microtiming is likely optimized/shared in interpreter and must not be treated as a quantitative baseline** |
| `simple_pass_ns` | Reuse ActualReview's hash-indexed transient records and fold once for both dates | Admission; file load |\n| `root_lookup_comparisons` | Exact number of root-ID equality probes made by nested list search over both admitted frontiers | Clock/compiler uncertainty; separately counts one root discovery only |\n| `root_scan_delta_ns` | Call current `oneRootReplacement?` over *both* admitted images and apply delta to previously calculated old totals | Admission; precomputation of old totals |
| `known_delta_ns` | Apply a pre-known old/new contribution to two precomputed old totals | Discovery, admission, cache validation, publication |

Admission is measured in microseconds. Other timings are median nanoseconds per call over three batches of ten complete result-checked calls. Treat timings as illustrative only, **not production speed ratios**. The known-delta path is a
**lower-bound arithmetic scenario**, not a working end-to-end speedup.
Build/fixture setup is excluded from the three paired read timings. The
`admit_pair_us` path includes fixture construction and should not be
mistaken for startup or reload time.

## Evaluation gates

- If `root_scan_delta_ns` is slower than `full_read_ns`, do not install
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

Archival CI qualified compilation, non-refusal and answer equality for bounded synthetic fixtures. Timing on shared CI machines is
descriptive, **not** a performance gate or a reliable MacBook speed claim.

## Step 2: simpler contender and deterministic algorithmic cost

Before introducing any index, cache or incremental engine, compare with a
**single fold** of the existing `ActualReview.recordsFromActualImage` projection.
This projection already uses temporary HashMaps for validity and correction
lookups. The candidate avoids writing a second currentness or temporal
authority, and it computes two requested dates together in the same fold.

An initial attempt to fold `image.currentEvents` and query
`image.currentValidities.findByEventId?` *per Event* inadvertently used a
linear list lookup at each iteration. It was replaced before interpreting any
performance results. The superficial appearance of “one loop” is not proof of
linear overall work.

The root-discovery research helper is structurally different: for each stable
root in the old admitted frontier it searches the new root list with
`List.find?`. With N unique roots and the same set of roots on both sides,
the exact number of ID comparisons is `N(N+1)/2`, regardless of root order.

Checked by [GitHub Actions run 37936317081](https://github.com/shumoku88-bit/loam/actions/runs/37936317081),
using synthetic, balanced, canonically admitted data:

| Events | Current events | Root ID comparisons | Single-fold sample | Full-root scan sample |
| ---: | ---: | ---: | ---: | ---: |
| 40 | 40 | 820 | 0.364 ms | 1.314 ms |
| 100 | 100 | 5,050 | 1.033 ms | 5.202 ms |
| 200 | 200 | 20,100 | 2.039 ms | 15.853 ms |

Each selected alternative returned the same date/Measure totals
(`[N-1, 2]`) and failed the run if it did not. The measured times are
microbenchmark observations, not an end-to-end proof, and in particular the
old “full read” timed nearly constant ~400 ns in the interpreter, suggesting
hoisting/thunk sharing or otherwise non-comparable execution. **Do not use
those values to compute speedups.** The deterministic comparison counts,
however, do demonstrate that the current root-discovery algorithm has
quadratic work even when data is valid.

## Simplification-first disposition

**Do not promote any persisted incremental cache, new index, or the scanned
`oneRootReplacement?` helper to production as a speed optimization.**
The project already has efficient transient hash indexes in ActualReview,
and a straightforward scan of admitted records can recompute these two physical
date/Measure totals without synchronizing additional state.

The proof of arithmetic delta equivalence in PR #1864 remains valuable but
does **not** establish that obtaining the delta is worthwhile.

There is no demonstrated user-visible slow report caused by full
recomputation in this experiment. Keep the benchmark as a bounded research
checkpoint, avoid frequent CI work for routine product changes, and only
reopen the question when an actual report latency problem is reproducible.
Before any product change, compare compiled read cost + authority loading +
semantic qualification + failure cases. The proper simplification might be
removing the unnecessary delta mechanism rather than improving it.

**Scope**: one physical Locus/Measure total over two specific dates. Purpose,
AccountingRole, merchant, budget, Scheduled, and anchored balances are separate
queries and must not inherit this conclusion without new evidence.
