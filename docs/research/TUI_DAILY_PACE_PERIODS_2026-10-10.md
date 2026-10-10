# Daily Pace daily periods and provisional layout — 2026-10-10

Scope: #1868 Daily Pace slice; related #1861/#1863. Baseline main `67f69ec1`.
Actual (#1871), Reports (#1872/#1873) and Calendar (#1869/#1870) are merged.
At investigation time no PRs were open; all three latest-main workflows subsequently
passed. This record does not claim completion of the broader tracking issues.

## Stable meaning and resolved boundaries

Daily Pace remains integer `availableThroughEnd.quanta / remainingDays` for the
explicit JPY pool used by the existing TUI reader. Display windows are inclusive
`start`/`through`, independent of the half-open cycle governing each daily point.
10d/30d are calendar days, Month is calendar month-to-date, Cycle is explicit
cycle-to-date, Previous Cycle is the immediately preceding explicit completed
interval from the same uniquely selected current boundary preset.

`BoundaryPresetConfig.currentWindowFor?` owns unique current-preset resolution;
`windowForDate?` resolves each historical day and the predecessor. No recurrence,
month-based cycle guess, predecessor from another preset, or extrapolation is used.
A cycle may differ from a calendar month or contain thousands of days.

Existing history reconstructed end-of-day pool quantities via HistoricalBalanceReview
at next-day start, then applied retained Scheduled completion dates and the same
CycleSpendingPaceReview deduction/arithmetic kernel. That supports the five windows
when explicit boundaries and historical support exist. It does **not** supply
saved past observations or historical query-configuration versions.

Known refusal conditions remain visible:

- no/ambiguous current preset, absent predecessor or missing historical boundary;
- opening-only support, missing/competing historical support, before certified start,
  missing/stale anchor or current-quantity disagreement;
- pool-affecting Scheduled retirement/replacement lacking transition time;
- unsupported/malformed/unreadable configuration or admitted read failure.

A window with a refused day is refused as a whole, with date/cause, not silently
clipped, connected across missing samples, or filled with zero. Independent usable
presets remain usable. Existing known-zero, missing pace, Measure mismatch and huge
axis handling remain separate. Delta is between adjacent days in the selected
window; unlike Measures are never subtracted/plotted together.

## Local composition and cost

Daily Pace entry selects one fresh Household/Actual generation and derives Scheduled
and support from it. Prepared periods are read-only, process-local and discarded on
re-entry/reload. Existing Home's short optional history entrance is unchanged.
Tests remove the physical household after admission and still prepare all periods;
a later generation produces updated values, not old cached points.

All overlapping display days are reconstructed once. The HistoricalBalanceReview
batch entrance groups admitted current effects by date once per coordinate and
uses the **same** support router and current-anchor inspector at every boundary.
Its batch answers/refusals are tested against ordinary `projectStartOfDay` for
mixed zero/bounded routes, duplicate/reordered coordinates, support edges, stale
anchors, conflicts, invalid dates, correction and date refinement.

Work changes from repeated per-day Event/index preparation to approximately
`coordinates × (Events + days × represented date buckets)`. Scheduled reconstruction
still follows the original per-day kernel. Very large coordinate/Scheduled vocabularies
and extreme boundary spans remain unqualified; no universal latency guarantee is made.

Shared Chart sampling indexes an Array for raster cells, with exhaustive bounded
sample parity against the original List sampler (including 1,500 points, signed
values, empty/single-point and endpoint cases). Chart scale/interpolation/markers
are unchanged. Cursor/page input reconstructs no accounting values and performs no
household IO; history renders only visible rows, detail only the selected point.

## Native phase specimen

Immutable synthetic 10,000 additional Events / 500 date buckets; admitted image;
1,500 explicit daily questions; three native runs on this macOS host:

| phase | samples (ms) | median (ms) |
|---|---|---|
| Household selection + Actual admission | 105, 101, 95 | 101 |
| independent singleton daily questions | 30,031, 28,652, 28,611 | 28,652 |
| batch of identical daily questions | 39, 40, 42 | 40 |

Exact results/refusals matched and all fixture bytes remained unchanged. This is
**not** a before/after measurement of the old seven-day TUI: singleton questions
also repeat Actual-record/Scheduled preparation. It demonstrates why per-day full
read preparation must not be used to extend a cycle. Pure work is delayed through
thunks until after the first clock. A separate final run measured selection/admission
101ms, singleton questions 31,219ms, batch 41ms, and **20 shared chart raster + cell
expansions at 140×18 in 40ms**. That is chart-only work, not whole TUI frame/input cost.

Native probe build (after product build):

```sh
lake env lean -c /tmp/loam-pace-profile.c tools/DailyPaceProfile.lean
python3 - <<'PY'
import shlex, subprocess
from pathlib import Path
args = [a for a in shlex.split(Path('.lake/build/bin/loamTui.rsp').read_text())
        if not a.endswith('/Loam/Tui/Executable.c.o.export')]
subprocess.run(['lake', 'env', 'leanc', '-O3', '-o', '/tmp/loam-pace-profile',
                '/tmp/loam-pace-profile.c', *args], check=True)
PY
# Supply only an immutable synthetic fixture with sufficient explicit boundaries:
/tmp/loam-pace-profile /tmp/SYNTHETIC-ROOT 1500
```

Construct that specimen with `tests/test_daily_pace_pty.py::fixture(root, 10000, 500)`
and explicit boundaries `today-1535`, `today-1499`, `today+30`; digest before/after.
This does not read or modify operational loam-data.

## Compiled PTY specimens

Three rounds per input type; temporary synthetic authority with one seeded
completion Event plus the additional Events below. Fresh Daily Pace entry includes
read admission and all five periods, not merely chart drawing. Ordered `i` sentinel
follows every entire input burst; final selected date is asserted. Wheel batching
preserves counts; keyboard actions are not coalesced/dropped. After the sentinel,
idle output is zero. Reverse/pages, period changes, narrow/idle resize, Home return
and fresh re-entry are checked; every fixture remains byte-identical.

| additional Events / date buckets / current-cycle days | entry | 20 keys | 20 wheel | 20 down + 20 up | pages reversal | preset switch |
|---|---:|---:|---:|---:|---:|---:|
| 10,000 / 500 / 31 | 170.6 | 240.4 | 51.1 | 471.8 | 62.9 | 17.4 |
| 50,000 / 2,500 / 31 | 1,352.7 | 263.4 | 52.7 | 505.1 | 64.1 | 17.4 |
| 50,000 / 2,500 / 1,500 | 1,244.2 | 278.7 | 56.3 | 523.0 | 69.8 | 19.8 |

Milliseconds; input/switch columns are medians, entry is one sample. Fresh re-entry
was 166.8 / 1,334.7 / 1,376.5ms respectively. Cache/OS/scheduling are not controlled;
no cold/warm universal claim or hours-long leak claim. The slow fresh 50k read remains
#1863's pressure, not hidden by input dropping or weakening admission.

```sh
python3 tools/benchmark-daily-pace.py --check --events 10000 --days 500 --rounds 3
python3 tools/benchmark-daily-pace.py --check --events 50000 --days 2500 --rounds 3
python3 tools/benchmark-daily-pace.py --check --events 50000 --days 2500 --cycle-days 1500 --rounds 3
```

The initial combined two-large-specimen harness call exceeded its 180-second wall
limit during synthetic fixture/setup work. No result was inferred from that timeout;
the long-cycle specimen was rerun independently to successful exit 0.

## Qualification surfaces

- Product builds: `loam`, `loamTui`, `terminalProbe`.
- `DailyPacePeriods`: five ranges, month/year/leap edges, explicit cycle boundaries,
  ambiguity/missing predecessor; month/cycle are distinct.
- `CycleSpendingPaceReview`: old calculation parity, daily grain across cycles,
  predecessor final day/remaining horizon, bounded support and undated retirement.
- `HistoricalBalanceReview`, `TuiChart`: batch/sampling parity and existing neighbors.
- `TuiDailyPaceTrend`: five keys, date preservation/clamping/refused anchor, full-width
  upper chart and lower panels, exact quantities/Measures, missing/zero and tiny resize.
- `TuiHomeActualGeneration`: paired generation, no reopen and stale-cache invalidation.
- `TuiScheduled`, `TuiScheduledContinuation`, CurrentBalance/CalendarMoney neighbors.
- `lake test -- tui-representative`: all 17 tests passed (exit 0; background
  execution retained `/tmp/loam-daily-representative.log` and exit status).
- Synthetic Daily Pace, native terminal, Balances, Reports,
  Record reload, Actual detail and Cycle Budget/Home/Selected Day/Reports/Scheduled/
  Actual viewport PTYs. New five-period and long-cycle specimens run in PR/main CI.

No canonical data/representation, publication path, revision pin or accounting
calculation definition changes. No arbitrary range editor, overlay/comparison,
cycle-traversal engine or generic layout framework. No merge is authorized here.
