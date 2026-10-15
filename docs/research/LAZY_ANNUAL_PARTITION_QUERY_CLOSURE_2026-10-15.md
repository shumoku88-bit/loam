# LOAM long-history research: lazy annual segments and query closure

Date: 2026-10-15
Status: **synthetic-only, falsifiable query planner, not a storage migration**
Issue: [#1969](https://github.com/shumoku88-bit/loam/issues/1969)
Related: #1970 (compiled long-horizon read/write), #2003 (bitemporal compression), #2005 (automatic knowledge publication), open #2004 (writer inventory) and #2006 (synthetic HouseholdImage knowledge encoding).

## Product decision and one clear limit

The leading **physical** candidate is an automatically maintained
**one-year publication/knowledge-history segment** plus one *logically
singular* household, with a small current writer and **on-demand** reusable
reader. Five- and ten-year segment widths remain counterproposals until the
same workloads and safety guarantees have been measured.

- No manual year-end closing, confirmation, daily snapshots or daemon.
- A year with no newly accepted records produces **no segment**.
- Events are grouped by **when the system admitted them**, *not* their
  historical date of occurrence.
- Annual segmentation is independent of LOAM's pension-cycle boundaries.
- A special **separate executable** is not required initially: a lazy
  library/module that resolves required partitions is sufficient. A separate
  process would need an evidenced UI responsiveness or resource-isolation
  reason.

A source created in 2025 and revised in 2027 stays a 2025 source with an
additional 2027-admitted revision. A 2027 entry backdated to 2025 belongs
physically in the **2027** publication segment. Moving the event's effective
date again must not modify a sealed 2025 segment.

## What the executable experiment does

`tools/research-lazy-year-reader.py --check` exercises a **deliberately small
abstract source grammar** in disposable directories only. This grammar is not
LOAM's actual normalized Actual/Scheduled codec and not an invented new
canonical source family.

The fixture includes:

- an original Actual source; a separate older original;
- a future Scheduled obligation, terminal cancellation on completion, and the
  completion's Actual entry;
- an Event inserted later with a backdated effective year;
- a 2025 Event revised in 2027 and three times in 2028, moving it between
  effective years and testing the last accepted revision;
- idle years 2024, 2029, 2030, which produce no year file.

For each of annual (B1), five-year (B5), and ten-year (B10) physical layouts,
test **30 combinations** of query effective year and admitted-knowledge
cutoff, for a total of 90 comparisons. Compare every selective reader result
with a full, order-respecting replay of the same synthetic source. Assert
an exact whole-prefix result too.

Synthetic segments are represented as immutable JSON files for this test.
A synthetic manifest provides:
- segment file ID, expected SHA-256, row count;
- affected **effective years** of every retained source or revision;
- touched source IDs that enable **dependency closure** across physical years.

A query for transactions in an effective year:
1. From the **qualified manifest** summaries, find publication segments that
   may affect that effective year by the requested knowledge cutoff.
2. Read and qualify those segments; identify matching stable source IDs.
3. Close the dependency set over **all** segments that mention those source
   IDs through the cutoff. This is essential when later revisions temporarily
   move an Event to a different effective year.
4. Replay only the selected identities in their retained publication order,
   applying the **knowledge-time cutoff**, then select the effective date.

The source-to-segments index is **derived**, not a second financial truth.
The synthetic `qualified_seal` checks accidental local manifest mutation,
but is **not a cryptographic signature or a filesystem atomicity proof**.
A production manifest would have to be admitted and versioned with real
generation qualification, recovery and a defensible seal/segment transition
protocol. The experiment trusts that its metadata was correctly generated
from complete source rows. It does **not** prove this assumption for LOAM.

### Result from the isolated reference execution

| Physical segment width | Query/cutoff combinations | Physical publication segments | Result |
| ---: | ---: | ---: | --- |
| 1 year | 30 | 6 | all equal to full reference replay |
| 5 years | 30 | 3 | all equal |
| 10 years | 30 | 2 | all equal |

An exact 2023-at-2023 transaction query in the annual layout reads **only
the 2023 segment**, not the other five. An absent needed 2027 correction
segment refuses; a manifest summary changed without updating its seal
refuses; no silent empty/zero substitution. These are deterministic,
synthetic semantic test outcomes, **not measured production reader times**.

## The critical distinction: selective transactions vs balances/Daily Pace

This probe provides an explicitly **conservative full-prefix** mode for
queries requiring historical totals and commitments.

A transaction-year query is not the same as an exact balance or Daily Pace:

- A present-day balance includes prior history or an independently qualified
  opening/current anchor and any relevant corrections;
- Daily Pace also depends on Scheduled obligations, the eligible pool and
  explicit pension-cycle/policy version *as then known*, potentially across
  an arbitrary calendar-year boundary;
- An apparent balance of zero because prior segments weren't read is
  **not** a justified exact zero.
- To safely read only a narrow span for Daily Pace, a future independently
  qualified **checkpoint/summary with its coverage and revision frontier**
  must be shown equivalent to the full prior relevant history. A cached
  total without amendment dependencies or completeness cannot be trusted.

Therefore **no claim is made** that Daily Pace or any balance question
already supports selective one-year reads. The initial safe planner may
load the complete admitted prefix for those queries. This preserves
correctness until a qualified checkpoint earns actual pruning.

## Safety obligations before any on-disk migration

1. **Current/archived single logical generation.** One authoritative
   manifest/current head names an exactly consistent segment set. Its
   atomic commit, pinned segment hashes, rollover, stale-writer and
   restore protocols must survive crash/kill/disk-full and partial restore.
   `household.loam.prev` retains one previous whole image today; it
   cannot be treated as archival provenance for many segments.
2. **Recorded-time identity across years.** Corrections, date revisions,
   reversals, Scheduled terminal/replacement, Settlement, FX and Current
   Quantity support must follow their actual source identities regardless
   of segment membership; preserve absent != empty and unknown != zero.
3. **As-known clock.** Admission time is not the event's original valid
   date. The first normal publication in a new year opens that year's
   segment *automatically*, with no annual maintenance action. A no-op,
   failed attempt or idle year adds no canonical event.
4. **Failure handling.** Reject missing, truncated, mixed-generation,
   wrong-version, duplicate, unsupported or stale requested evidence.
   A manifest saying a segment does not affect a query must be
   independently credible, otherwise refusing or reading more is safer
   than pruning.
5. **Performance experiment.** Reuse issue #1969's existing
   compiled 1/5/10/20/30-year LOAM benchmark harness. Compare one
   HouseholdImage (A), 1-year (B1), 5-year (B5), 10-year (B10) and
   immutable history + active writer (C) on identical record, late
   correction, Scheduled and restore workloads. Compare read/publish,
   peak RSS, disk bytes *including prev/manifest/backup* and recovery,
   not just a JSON microbenchmark.

### Stop conditions

Do not select annual partitions on aesthetics alone. Do not treat dates
as independent money authorities. Do not copy current derived balances as
new opening facts, and do not add a second journal of Daily Pace values.
No prod code, `loam-data`, migration, current schema, source truth or
release changes were made.

**Next research gate:** reconstruct the same target-year query using
actual admitted `ActualAuthority` + `Scheduled` fixture identities,
then compare an annual candidate with A/C under compiled native
publication and failure-injection. Only choose a physical topology once
the end-to-end correctness and durability story survives.
