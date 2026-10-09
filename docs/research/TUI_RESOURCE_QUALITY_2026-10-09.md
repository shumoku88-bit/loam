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

## Fresh Record / Balance entrance: physical framing

A compiled phase probe on an immutable synthetic 50,000-Event / 2,500-date
Household measured file IO at 17ms, outer framing at 191–193ms, normalized Actual
parse/construction/admission at 594–601ms and separate re-admission at 175–182ms.
Full household selection was 802–812ms; fresh Movement world loading 842–846ms.
Balance projection from a selected generation was 61–65ms. Re-admission is a
separate experiment on already-decoded evidence, not an additional production
phase or an exact subtraction-based estimate of parsing alone.

The outer decoder split/rejoined the entire unread suffix to obtain each framing
line, then repeatedly counted/copied it. It now uses slices and first-newline
search, advances exactly the declared Unicode code-point count once, and rejects
truncation instead of clamping. Byte-size bounds protect fuel and obviously
impossible declarations; they do **not** change payload lengths to byte units.
No format version, family qualification, missing/present-empty semantics, section
order or opaque body content changes. Writer and recovery qualification still
uses the same complete known-family checks and exact stale wire comparison.

On the same fixture, framing became **41–42ms**, full household selection
668–671ms and fresh Movement world loading 691–699ms. Actual admission remained
intact (separate re-admission measured 185–189ms). The real PTY three-round probe
measured 1,566ms startup, **717ms median Record open / 809ms Balances open**,
versus 902ms / 1,002ms in the preceding wide-date run. Startup/cache/scheduling
are not controlled. FDs stayed seven, retained descendants zero, idle output
zero, and fixture bytes unchanged. RSS was 125,680–125,696 KiB across the rounds.

Qualification includes a bounded old-decoder oracle with Unicode names/bodies,
length spellings, embedded framing lines, trailing garbage, duplicate names,
section reversal and every code-point truncation of small multi-section images.
HouseholdAuthority installation/publication/stale refusal/recovery/unknown
preservation, HouseholdActualAuthority and Record publication/activation PTY
regressions passed. Blueprint review: no retained facts/defaults, weaker admission,
format migration or authority changes are introduced. Bounded parity is not a
universal equivalence proof.

### Follow-up: qualify the actual hot path before changing it

The probe now prints the Actual header: the ordinary fixture is **v1**, not v4.
A candidate first-field-only dispatch change affected only v2–v4 settlement
parsing, so it was withdrawn rather than retained as an unearned repair to this
workload. Version/Unicode/empty-field/refusal-precedence regression coverage was
kept. The helper also reports isolated retained-date validation (34–37ms here);
like re-admission, this is a separate experiment, not another production phase.

A short native sample found shared `validToken` on the transaction parser's hot
path. Its three separate delimiter searches now become one character traversal,
with exactly the same nonempty / no-tab / no-newline / no-CR predicate. It does not
trim text, normalize Unicode, infer identity, or restrict other controls. Bounded
old-predicate parity tests cover ASCII controls, Unicode, empty and long tokens.
`bash tools/test-product actual-validity`, normalized Actual v1–v4 settlement
qualification, household publication/recovery/stale refusal and Record/Scheduled
publication PTYs passed after the change. Complete semantic admission is retained.

Two alternating saved-baseline/candidate phase trials measured normalized
parse/construction/admission at 699 / 724ms before and 625 / 581ms after. These are
noisy phase observations, not a promised end-to-end percentage. The full three-
round 50,000-Event / 2,500-date PTY measured **698ms Record / 802ms Balances**,
only a modest further change from 717 / 809ms after the framing repair. The first
startup after rebuilding was 3,204ms; cold startup remains unqualified separately.
At **10,000 Events / 500 dates** (also 20/day), the probe measured 336ms startup,
117ms Record and 133ms Balances. Both fixtures remained unchanged, FDs stayed
seven, retained descendants zero and idle surfaces quiet. This is short-run
qualification, not leak freedom or representative correction/settlement pressure.

### Reproduce the compiled phase probe

Run from the code repository; this creates and removes its own synthetic household.
Do not use the Lean interpreter for production latency claims. The phase helper
accepts a thunk so pure decoding occurs **after** the start clock; `phase label
(pure (decode wire))` would evaluate decoding before entering the timed function.

```sh
lake build loam loamTui
lake env lean -c /tmp/loam-actual-read-profile.c tools/ActualReadProfile.lean
python3 - <<'PY'
import importlib.util, shlex, subprocess, tempfile
from pathlib import Path
args = [a for a in shlex.split(Path('.lake/build/bin/loamTui.rsp').read_text())
        if not a.endswith('/Loam/Tui/Executable.c.o.export')]
subprocess.run(['lake', 'env', 'leanc', '-O3', '-o', '/tmp/loam-actual-read-profile',
                '/tmp/loam-actual-read-profile.c', *args], check=True)
spec = importlib.util.spec_from_file_location('probe', 'tools/benchmark-tui-resources.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
with tempfile.TemporaryDirectory(prefix='loam-phase-probe-') as temp:
    root = Path(temp) / 'synthetic'
    probe.fixture(root, 50000, 2500)
    before = probe.digest(root)
    for _ in range(2):
        subprocess.run(['/tmp/loam-actual-read-profile', str(root)], check=True)
    assert probe.digest(root) == before
PY
```

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

Performance work is paused after implementation checkpoint `91991df9`.
Remaining priorities, reproduction conditions and acceptance boundaries are tracked
in [GitHub issue #1863](https://github.com/shumoku88-bit/loam/issues/1863).
The observations above are chronological checkpoints, not a claim that every
remaining pressure shape is qualified. Creating the issue does not authorize
pushing pending commits or advancing operational household revision pins.

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
