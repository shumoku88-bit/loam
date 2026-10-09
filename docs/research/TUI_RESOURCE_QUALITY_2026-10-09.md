# Bounded TUI resource qualification — 2026-10-09

Status: **measured local repairs, not a long-duration leak-freedom claim**

## Scope and instrument

`tools/benchmark-tui-resources.py` drives the compiled production TUI through a
real PTY on a temporary synthetic HouseholdImage. No operational `loam-data` is
selected. Setup uses `ScheduledBatchReplacement`'s fixture and appends balanced,
dated Actuals, explicit synthetic role/zero-origin evidence and query configuration.
There is one seeded completion Event in addition to the requested Event count.

The workload warms up for five rounds, then repeatedly visits Summary, Calendar,
Actual, Record/cancel, Daily Pace, Balances and Reports. It records RSS, accumulated
process CPU time, numeric open FDs, retained descendant processes, operation times,
idle output, and ordinary exit terminal-control restoration. Fixture digests must
remain identical. The probe also exercises idle Daily Pace resize and checks
ordinary exit restores canonical/echo input modes. Resource sampling and fixture
generation are outside operation timing. Startup includes frame settling (about 20ms); other times end at the last
observed output byte and are PTY response times, not human display latency.

```sh
lake build loamTui
python3 tools/benchmark-tui-resources.py --check --events 100 --cycles 100 --idle-seconds 3
python3 tools/benchmark-tui-resources.py --check --events 10000 --cycles 5 --idle-seconds 3
```

`--check` checks quiet idle, unchanged evidence, stable sampled FD counts and no
retained descendants. CPU and RSS are reported, not given machine-independent
thresholds. Missing FD instrumentation reports `null`, never assumed zero.

## Observations and repairs

Measurements below were on macOS x86_64. Filesystem/cache state and scheduler load
were not controlled; startup figures are illustrative rather than universal budgets.

### Idle work

With 100 synthetic Actuals and 100 workload rounds:

| Surface | Before, 3s idle | After, 3s idle |
| --- | --- | --- |
| Record | 240 output bytes; 0.04 CPU seconds | 0 bytes; 0.00 CPU seconds at `ps` resolution |
| Daily Pace | 0 bytes; 0.13 CPU seconds | 0 bytes; 0.00 CPU seconds at `ps` resolution |

Short native read timeouts produced `.other`. Record rebuilt its editor and
repositioned the physical caret every tick; Daily Pace rebuilt its chart even
without a changed selection. Both now retain the existing frame on idle input.
Daily Pace's geometry refresh still happens before the idle fast path.

After the idle repairs, RSS after warm-up was 27,084 KiB and reached 27,700 KiB
at round 100. Most growth occurred before round 50; later samples were 27,672,
27,688 and 27,700 KiB. FD count stayed at seven; retained descendants stayed zero.
This is consistent with allocator warm-up/near plateau in this workload, not proof
that all longer-running or different workloads are leak-free.

### Data-volume pressure

10,000 synthetic Actuals exposed a startup bottleneck. A temporary **compiled**
phase probe measured about 8.14s in Pace+history, versus about 0.21s for Actual
admission, 0.13s for Scheduled, and 0.37s for a separate CurrentBalance load.

Historical reconstruction linearly searched the admitted date list for each
selected Event, for each reconstructed day. It now builds a transient hash index
from the admitted unique current validity memory. Missing/invalid dates still
refuse **when they affect the selected coordinate**. No historical completeness,
correction frontier, or support-family rule is weakened.

The next pressure was repeated whole-Household qualification for every support
family. Existing authority adapters now decode their existing contracts from a
caller-owned qualified generation. CurrentBalance's support, HistoricalBalance's
support, combined Pace/history, and production Movement world loading reuse a
qualified physical generation locally rather than reopening it for each family.
Explicit legacy Actual selection still loads its separately selected policy/support;
no legacy fallback or persistent cache was introduced. Writers still own fresh
read, admission, stale-generation refusal and publication.

| Observable, 10,000 added Actuals | Before | After |
| --- | ---: | ---: |
| PTY startup | 9,148ms | 880ms |
| Record open, median | 411ms | 248ms |
| Balances open, median | 665ms | 262ms |
| Native Pace+history phase | 8,140ms | 233ms |

Three further startup runs on the same synthetic fixture measured 873, 885 and
892ms. In the post-composition five-round probe, sampled RSS was 46,916–46,944 KiB;
FD count stayed seven and retained descendants stayed zero. All probed idle
surfaces emitted zero bytes. The larger-case five rounds do not establish a
long-duration memory plateau.

A final 100-round run after all composition changes measured RSS from 27,172 KiB
(after warm-up) to 28,364 KiB; rounds 25/50/75/100 were 28,344 / 28,348 / 28,356 /
28,364 KiB. Six separate three-second idle windows emitted zero bytes and had
unchanged sampled RSS. A final 10,000-Event run reproduced 881ms startup, 249ms
median Record open and 263ms median Balances open, with seven FDs and zero
retained descendants. Idle Daily Pace resize and ordinary exit mode restoration
also passed.

## Follow-up: 50,000 Events and retaining qualification's Actual result

The initial 50,000-Event probe measured 5,012ms startup, 1,588ms median Record open
and 1,685ms median Balances open. RSS was 129,800–129,820 KiB across five rounds;
FD count stayed seven, descendants zero, and all idle surfaces were quiet.

Household qualification already creates an admitted Actual image to validate the
Actual section. Production Actual consumers were immediately decoding that same
body a second time. `HouseholdAuthority.loadCurrentWithActual?` now returns the
fully qualified generation together with that already-admitted image (or `none`
when the section is absent). **Every other known section is still qualified before
returning either result.** Ordinary generation loads and writer/recovery paths
share the same qualification. This is not a persistent cache or an additional
field in `Generation`, so replacing a generation's image cannot leave a cached
Actual accidentally attached to it.

ActualAuthority, Movement world loading and same-root CurrentBalance reads use
this paired read result. Targeted tests check absent Actual stays absent, returned
Actual belongs to the selected wire, and malformed Actual **or another known
family** refuses the paired load. Existing publication, stale/refusal, `.prev`,
unknown-section and explicit legacy tests still pass.

Follow-up runs (five warm-up rounds, three measured rounds):

| Added Actuals | Startup | Record open median | Balances open median |
| --- | ---: | ---: | ---: |
| 10,000 | 821ms | 168ms | 187ms |
| 50,000 | 4,569ms | 955ms | 1,061ms |

These are not controlled cold-cache paired trials; they establish retained
correctness and useful operation improvements, not a universal startup speedup.
The 50,000-Event startup remains too slow. Separate Home branches still independently
open/qualify the same physical household generation, and larger/corrected workloads
need further profiling rather than assuming this repair completes scaling work.

## Follow-up: one Household generation for Home

Production Home startup/reload now keeps the generation paired with its selected
Actual image and supplies it to Scheduled lifecycle validation, canonical Attention,
current/historical Pace support and AccountingRole projection. This removes repeated
whole-household qualification from the Home branches. All family-specific absence,
refusal and lifecycle admission still runs. Query/presentation configuration is
loaded separately, so this is not a cross-file atomic configuration claim.

The existing caller-owned Actual-image entrance still supports independently refreshed
families when no generation is supplied. A regression advances both Actual and
Attention after selection, then hides the synthetic Household file: explicit paired
composition must still produce the original Scheduled/Pace/Attention/role answers,
while independent composition must consume refreshed **canonical** Attention.

During this work, Home Attention was found still using frozen `attention.loam`,
unlike production Attention administration. A separate corrective commit switched
Home to HouseholdImage Attention and tested a malformed stale legacy file against
valid canonical evidence. No retained household facts were changed.

At 50,000 added Events over the fixture's 180 dates, the three-round shared-Home
probe measured 1,811ms startup (previous paired-Actual-only run: 4,569ms), 968ms
median Record open and 1,072ms median Balances open. RSS was 126,268–126,288 KiB;
FD count stayed seven, retained descendants zero, and idle surfaces were quiet.
Fresh Record/Balance entrances still intentionally re-read authority and remain
separate optimization pressure. The dense 180-date fixture is not equivalent to
20 transactions/day over seven years; a wider date distribution needs qualification.

## Date-distribution pressure

`--days` selects the date-bucket count (default 180). At 20 retained Events/day,
50,000 Events span 2,500 days, about 6.8 years. Date/merchant refinements do not
necessarily create another Event; Movement correction/reversal/completion history
can increase retained Event counts beyond everyday recording counts.

```sh
python3 tools/benchmark-tui-resources.py --check --events 50000 --days 2500 --cycles 3 --idle-seconds 2
```

This wider fixture measured 2,825ms startup, 951ms median Record open and 1,120ms
median Balances open. FD count stayed seven, descendants zero, idle output zero;
RSS was 126,248–126,260 KiB across three rounds. A compiled isolated projection
probe measured **1,151ms in CalendarMoney projection** for 2,500 date rows: the
list accumulator linearly searched existing date/Measure buckets for each Effect.
This pressure was obscured by the earlier dense 180-date fixture.

CalendarMoney now accumulates a transient hash map keyed by the exact date and
Measure token, then sorts the same output rows deterministically. The compiled
projection on the same 50,000-Event / 2,500-date fixture fell from **1,151ms to 94ms**.
A test-only list oracle compares results across many dates, two Measures, unknown
roles, reversals, superseded/undated records and reversed input order. Neutral
Asset/Liability/Equity activity still creates no monetary day row. No new cache,
retained calendar state, classification guess or cross-Measure arithmetic is added.

The first full PTY run after rebuilding measured 3,446ms startup; three subsequent
starts on the same fixture measured **1,772 / 1,712 / 1,712ms**. Report both rather
than disguising cache/loader/scheduler effects as a universal latency guarantee.
The full run measured 902ms median Record open and 1,002ms median Balances open;
FDs stayed seven, descendants zero, and all idle surfaces remained quiet. These
fresh-read entrances and cold startup remain separate pressure points.

## Semantic neighbors checked

Existing qualifications exercised historical bounded/zero-origin routes,
correction/date refinement, unknown versus exact current quantities, absent versus
malformed support, required policy, legacy isolation, shared Actual generation,
atomic support publication, stale-generation refusal, and Record publication/
activation versus read-only cancellation. New resource probes check their read-only
workload leaves every fixture file unchanged.

All family decodes still follow full `HouseholdAuthority.loadCurrent?`
qualification. `Generation` is not promoted to a stronger proof-carrying type;
callers must not treat manually constructed instances as admitted authority.
The date index is process-local derived data, never persisted state.

## Residual work

- Hours-long soak, repeated successful publication/correction and Fava child
  lifecycle are outside this read-only workload. Existing writer/Fava tests are
  separate evidence, not coverage supplied by this probe.
- Cold-cache startup, multiple measures, many unique coordinates, and dense
  correction/date histories need separate pressure shapes. The wider 2,500-date
  calendar fixture is now qualified separately from the dense 180-date case.
- 50,000 Events are now measured, but startup and fresh writer/balance entrance
  remain slow. More Events and larger support/plan vocabularies remain unqualified.
- Record still uses its existing fixed session geometry; comprehensive modal
  resize, signal interruption, exact prior `stty` restoration and crash/disk-full
  behavior need their own qualification.
- Historical projections still rebuild a date index per requested boundary;
  sharing across an entire series is a possible later optimization if measured
  pressure justifies it. Avoid retaining another long-lived cache prematurely.
