# Native HouseholdImage probe: tagged vs ordered day-bucket knowledge history

Date: 2026-10-15  
Status: **reproduced on disposable synthetic households; research only**  
Related PR: #2006 (prior metadata-only comparison)  
Qualified CI run: [Production TUI, successful](https://github.com/shumoku88-bit/loam/actions/runs/38704582217)  
Owners: `tools/benchmark-household-knowledge.py` and `tools/BenchHouseholdKnowledge.lean`

## What was actually exercised

This follow-up embeds the previous synthetic learned-day encodings in a
**real version-2 `HouseholdImage` frame**, alongside an actual body made of
balanced dated synthetic Movement Events. A Lean runner performs:

1. `HouseholdAuthority.installInitial?` on a disposable test root, including
   full qualified Actual admission;
2. repeated `HouseholdAuthority.loadCurrent?` of the qualified image;
3. an intentionally refused mutation of the unrecognized research section;
4. one `HouseholdAuthority.publishObserved?` that appends one **real admitted
   Actual Event**, while preserving the unrecognized section unchanged;
5. `loadCurrent?` after publication, `.prev` equality, and a stale-generation
   rejection test.

The two encoding variants contain the same ordered synthetic knowledge
references, including versioned but hypothetical pool/cycle/anchor/support
updates. The corresponding actual Event rows are real codec inputs. The
`ResearchKnowledge` section is **unknown/unadmitted canonical data**; it is
read as opaque text by the HouseholdImage framing layer, not interpreted by
the Actual/Scheduled publisher. The producer **cannot yet publish a new
knowledge row atomically with the Event**. This is a meaningful remaining
implementation gap, not something established by this benchmark.

No actual household, user's `loam-data`, or production financial file is
opened or modified. CI first verified source compilability and tested the
fully synthetic roots.

## Reproduce

Full six-workload native test:

```bash
python3 tools/benchmark-household-knowledge.py --check --years 1 10 20 --per-year 50 730 --read-rounds 2
```

A cheap one-workload smoke test is retained in the existing Production TUI
CI; the six-workload command remains documented and explicit rather than
increasing the cost of **every** future TUI CI run.

The native runner uses LOAM's own typed codecs and real `HouseholdAuthority`
publication, not Python's guessed inner semantics. Synthetic references and
their day-bucket mapping are produced by the predecessor benchmark.

## Full-image bytes and qualified publication latency

For the middle workload, 730 synthetic Actual publications per year and
30 synthetic mutable-policy/support versions per year:

| Time window | Actual Event count | Tagged image bytes | Day-bucket image bytes | Full-image saving |
|---|---:|---:|---:|---:|
| 1 year | 730 | 96,095 | 90,954 | 5.35% |
| 10 years | 7,300 | 959,619 | 908,843 | 5.29% |
| 20 years | 14,600 | 1,919,083 | 1,817,165 | 5.31% |

For the sparse 50 Actual publications/year workload, the corresponding
savings are only 36 bytes at 1 year, 30 bytes at 10 years, and **negative
5 bytes** at 20 years. No-op calendar days have no canonical record in
either representation.

Exploratory **one-sample** qualified Actual publication timings from the
successful GitHub Actions run:

| Time window | Tagged publish | Day-bucket publish | Tagged qualified load | Day-bucket qualified load |
|---|---:|---:|---:|---:|
| 1 year, 730/y | 418 ms | 403 ms | 98 ms | 93 ms |
| 10 years, 730/y | 4,574 ms | 4,445 ms | 989 ms | 1,018 ms |
| 20 years, 730/y | 9,014 ms | 8,825 ms | 2,116 ms | 2,024 ms |

These values were observed in one CI run, **not** a statistically adequate
microbenchmark. The benchmark runs tagged before bucketed, reuses the
filesystem page cache, and measures full qualification/readback. Differences
of a few percent may be order/scheduling noise. Do not claim a reliable
performance victory for either encoding.

Each successful publish also retained an exact `.prev` equal to the prior
qualified image, refused stale observations, and preserved the unknown
metadata section exactly.

## The more important design signal

The material cost in the 20-year/730-per-year workload is the full
HouseholdImage qualification and republication of a large Actual history.
The around-nine-second publication, compared to around-two-second read,
is worth separately profiling on the user's actual supported target
hardware and production-equivalent workloads. This experiment does not
establish whether the cost is disk I/O, repeated typed decode/admission,
whole-image copy, re-encoding, locks, or stage qualification.

On this workload the full-image byte saving from day buckets is only
about **5.3%**, compared with about **16%** on metadata alone. Therefore
**per-reference learned-day association** remains the conservative
baseline for the initial semantic implementation, with day-bucket sharing
kept as a possible later physical optimization. A new source-time
ontology, daily snapshots and daily confirmation tasks are not justified.

## Required boundaries before as-known goes live

- Admit a real known-time source/version family with typed codec and qualified
  `HouseholdAuthority.knownSectionNames` integration. A research-only
  unknown section cannot be a new production authority.
- Ensure the *same committed generation* publishes the source change and
  its learned-day association across Actual, Scheduled, CurrentSupport and
  eventually versioned Daily Pace policies; also handle explicit restore.
- Retain the **old content** of overwritten pool/cycle/current-anchor/support
  versions, not merely the date on the latest value.
- Make local-day/clock ordering and offline external TSV policy adoption
  explicit. Never infer unobserved historical knowledge.
- Implement actual Daily Pace day-end replay, unknown gaps and consequence
  explanation through existing Review arithmetic. This test does not replay
  real policy or Scheduled lifecycle from qualified knowledge history.
- Measure production-representative 10- and 20-year publish performance and
  isolate repeated encode/readback costs before committing to a physical
  journal/index decision.

**No production schema, UI, household authority content or real data changes
were made by this research.**
