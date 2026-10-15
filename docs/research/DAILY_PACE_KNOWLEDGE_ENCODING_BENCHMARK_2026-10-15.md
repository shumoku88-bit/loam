# Daily Pace knowledge encoding: 1/10/20-year synthetic comparison

Date: 2026-10-15  
Status: **reproducible synthetic benchmark; no production codec or migration**  
Base main: `6568fb67a807a1aaabfc00f17321cf54753fbf86` (merged #2005)  
Companion: `tools/benchmark-daily-pace-knowledge.py`  
Relevant earlier evidence: Observation 381 (#2003), automatic knowledge protocol (#2005), independent writer inventory (open Draft #2004).

## Question

After qualifying that LOAM does **not** need a daily confirmation operation,
compare two lossless **physical representations** of newly admitted
knowledge-time associations, without making new Daily Pace quantities or
duplicating Actual/Scheduled movement amounts:

- **Tagged (A):** `K <day> <existing source ref>` or
  `V <day> <identified mutable policy/support revision> <minimum changed value>`.
- **Ordered day buckets (B):** `D <day>`, followed by the same
  source/revision rows **in accepted publication order**.

A source can be an Event or a Scheduled terminal. One accepted Scheduled
completion contributes *both* references but is counted as **one modeled
publication**, reflecting LOAM's existing cross-family atomic write. The
benchmark retains old identified versions of otherwise overwritten pool,
cycle, anchor and support configuration. It does not re-save bank amounts,
Scheduled amounts, graph points, quotient values or entire household images.

The representation B is **ordered**, not an unordered set.
`experiments/381_daily_pace_knowledge_minimality.als` already falsified
order-free last-writer selection. This experiment does not revisit that
semantic minimum.

## Exact reproducible command

```bash
python3 tools/benchmark-daily-pace-knowledge.py --check --years 1 10 20 --per-year 50 730 5000 --rounds 3
```

It uses only the Python standard library and synthetic temporary files.
Its RNG seed and generated text are deterministic; timings depend on
hardware, filesystem cache and process scheduling. It does **not** read
`loam-data`, open a real household, or require/build the Lean TUI.

The local qualifying run used Python 3.13.5 on Linux x86_64 (AMD EPYC 9V74),
three stage/readback rounds per result. The stage/readback sample performs
metadata-only `write -> readback -> rename`, **without** LOAM's typed
`HouseholdImage` decode, locks, staging of full source data or fsync
durability guarantees. Treat timing as exploratory, not a speed claim for
LOAM.

### Exact encoded metadata bytes

`per-year` represents the number of *Actual-like publications* per year,
with an additional 30 mutable-policy/support version publications per year
(12 pool, 6 cycle, 6 anchor, 6 support). A fraction of Actual publications
also contain the two reference IDs of one Scheduled completion.

| History | Actual publications/year | Total accepted publications | Tagged bytes | Ordered day-bucket bytes | B relative reduction |
|---|---:|---:|---:|---:|---:|
| 1 year | 50 | 80 | 3,266 | 3,230 | 1.10% |
| 1 year | 730 | 760 | 32,074 | 26,933 | 16.03% |
| 1 year | 5,000 | 5,030 | 212,816 | 156,115 | 26.64% |
| 10 years | 50 | 800 | 32,468 | 32,438 | 0.09% |
| 10 years | 730 | 7,600 | 320,356 | 269,580 | 15.85% |
| 10 years | 5,000 | 50,300 | 2,127,968 | 1,561,002 | 26.64% |
| 20 years | 50 | 1,600 | 64,936 | 64,941 | **-0.01%** |
| 20 years | 730 | 15,200 | 640,664 | 538,746 | 15.91% |
| 20 years | 5,000 | 100,600 | 4,255,936 | 3,122,004 | 26.64% |

The 20-year sparse workload is an important negative result:
day buckets cost *slightly more* than per-reference tagging in that exact
synthetic format. Date bucketing is therefore not an unconditional win.

### Correctness checks

For each of the nine workloads:

- Decoding A and B yields identical **ordered**
  `(learned day, source kind, stable ID, optional version difference)`
  sequences, including same-day revisions.
- Every end-of-day replay yields the same cumulative set/count of retained
  source references and the same *last accepted version* for the pool,
  cycle, anchor and support families. This is a representation check;
  it is **not** yet a proof of exact historical balances or Scheduled
  lifecycle projection in LOAM production.
- Empty calendar days produce no new record. One semantic publication may
  cover two retained source references.
- An explicit same-day pool-policy collision checks winner selection.

Benchmarked Python sequential replay of encoded references and policy
winners, not the real `CycleSpendingPaceReview` path. On the largest
20-year/5,000-per-year workload (111,712 rows), one 7,300-day scan was
approximately **25–29 ms** locally for either representation; these are
environment-specific exploratory measurements and not LOAM SLAs.

### Modeled rewrite traffic (not measured disk writes)

The tool also reports `modeled_rewrite_*_mib`: a sum of successive
metadata prefix sizes plus a fixed **artificial 4,096-byte base**, once
per accepted semantic publication, not once per reference. This shows
how full-image copy cost *scales* under each representation.

**It excludes the actual existing Household source payload growth.**
It is neither a production file size nor an estimate of real
`HouseholdAuthority.publishObserved?` disk traffic. It cannot settle
whether the fastest real implementation should append a journal, rewrite
whole images, or compact occasionally.

## Decision, with limits

The information-theoretic choice is already substantially resolved:
retain only the learned day associated with existing IDs and the genuinely
lost older versions of replaceable support/policy facts.

The physical encoding choice is **not** resolved by this synthetic test.

- Tagged is simpler, handles sparse updates well and can be carried on an
  already retained reference if that codec is chosen.
- Ordered buckets share dates when updates are dense, provided in-day
  order and atomic source/knowledge membership survive real publication.
- Neither encodes crash durability, qualified source selection,
  wall-clock/clock-skew admission, a real version migration, nor an
  independent historical `DailyPaceConfig` authority.
- Neither adds a daily close button, background worker or canonical
  day-by-day Daily Pace values.

**Next production-oriented research gate:** prototype both codecs *against
an actual disposable `HouseholdImage` fixture* with typed readback,
`publishObserved?` writer semantics, stale retry and explicit restore.
Measure source+metadata full-image writes and 10/20-year query rebuilds,
then decide whether date buckets justify the extra moving parts. Until
that test, a simple tagged association remains a sensible conservative
baseline rather than committing to the small synthetic percentage saving.
