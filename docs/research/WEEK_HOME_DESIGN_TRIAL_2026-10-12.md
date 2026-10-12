# Week Home visual trial (2026-10-12)

Status: **design evidence and UI-only calendar-coordinate foundation, not yet a Home-mode cutover**.

Owner: [Home evolution issue #1861](https://github.com/shumoku88-bit/loam/issues/1861).
This note compares presentation approaches and documents deliberately bounded next
steps. Existing accounting, Scheduled, Daily Pace and DateJump authority remain unchanged.

## Why a week-first Home

Real use after PR #1952 exposed a useful change in scale: a visible seven-day
context is often enough for routine household questions, while a six-week
monthly money grid demands space that would be better given to the selected
day's Actual and Scheduled details. **Do not interpret weekly recorded money
movement as available-to-spend capacity.** Daily Pace remains its own derived
answer and its `d` entrance is retained.

The target interaction is **Week -> Month -> Year** through `z`, preserving the
selected ISO date and returning to a detailed selected day on Enter.
This requires an explicit migration plan because current LOAM naming is not
identical to the proposed user-facing hierarchy:

- existing `ZoomLevel.day`: a selected-day detail with *six-week monthly money grid*;
- existing `ZoomLevel.month`: *12 month cells*, not a full one-month day grid;
- existing `ZoomLevel.year`: *five year overview*.

A blind `week` case added to the old cycle would skip or mislabel Month/Year.
Do not ship such an intermediate navigation behavior.

## Source studies (behavioral design references, not copied code)

| Project | Observable UI choice | Candidate lesson for LOAM | Limitation |
| --- | --- | --- | --- |
| [calcurse](https://github.com/lfos/calcurse) ([homepage](https://calcurse.org/)) | Calendar / appointments / todo panes; a distinct weekly calendar, configurable layout and compact-panel history | Make small calendar context subordinate to daily details; retain discoverable focus | Appointment timeline is not a ledger and cannot decide what counts as income or an available balance. |
| [khal / ikhal](https://github.com/pimutils/khal) ([view settings](https://github.com/pimutils/khal/blob/master/khal/settings/khal.spec)) | Selected calendar date and event list move together; light/dark palettes and low-ornament framing | Use selected date as the single source for both ribbon and detail; visual focus must agree with keyboard focus | Event colors are not equivalent to read-state completeness or multiple currency Measures. |
| [Calcure](https://github.com/anufrievroman/calcure) ([3.3 release](https://github.com/anufrievroman/calcure/releases)) | Generous typography and spacing; weekly view added in 3.3 | Make seven dates aligned and aesthetically quiet; consider restrained weekend indication | Beautiful empty space at 150x45 will not transfer to 32x9. |
| [lazygit](https://github.com/jesseduffield/lazygit) ([layout config](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md)) | Flexible responsive pane split, focused panes and scrollable detailed content | Reflow and densify rather than discarding details | Not itself a calendar. |

No external styling system, dependency, data model, keybindings or code is imported.

## Three explicitly testable layout hypotheses

All examples use fictitious data. Labels represent a UI design trial, **not**
a claim that any household evidence or Scheduled obligations exist.

### A. Selected-week ribbon + daily details (preferred first trial)

```text
 LOAM Home    Week 2026-10-12 .. 2026-10-18
 ╭─ Week ──────────────────────────────────────╮
 │ Mo 12  Tu 13  We 14  Th 15  Fr 16  Sa 17  Su 18│
 │   [today]                  !                  │
 ╰──────────────────────────────────────────────╯
 ╭─ Selected Day / Actual & Scheduled ──────────╮
 │ Actual:  <selected record with exact effects>  │
 │ Scheduled: <due/unknown/unavailable evidence>  │
 ╰──────────────────────────────────────────────╯
```

Fewer borders and no redundant headline in terminals shorter than 20 lines.
The week ribbon is a **navigation coordinate**, not a composite monthly sum.

### B. Compact context rail + agenda (ikhal-like)

```text
 [Mon 12] [Tue 13] [Wed 14] [Thu 15] [Fri 16] [Sat 17] [Sun 18]
  Selected day record rows and Scheduled details
```

More room for long descriptions in 48-column terminals; risks making other
weekdays too subtle. Compare against A with selected-day focus and status.

### C. Seven soft day-cards (Calcure-inspired, spacious terminals only)

```text
 [Mon 12] [Tue 13] [Wed 14] [Thu 15] [Fri 16] [Sat 17] [Sun 18]
 [small   ] [      ] [      ] [due   ] [       ] [       ] [      ]
  focus and selected-day details below
```

Useful for 120–150+ columns only, **if** multiple-Measure, partial,
not-requested and read-error behavior remains honest and no amount is shown
clipped into a misleading value.

## Acceptance criteria before promoting an experiment

Test on isolated synthetic Home snapshots and real PTY at 32x9, 48x14,
80x24, 119x20, 120x30, 150x45. Compare normal and extreme data: long Japanese
names, huge signed quanta, 0/1/multiple Measures, unclassified roles, read
failed/unknown/unavailable, overdue and no-coverage Scheduled, leap and
year-end weeks, no records, small height, resize while Detail is focused.

Qualify **three independent questions**:

1. **Correctness**: one selected date, exactly seven Monday-first dates including
   adjacent months, no new period authority; actual/posting and Scheduled evidence
   unchanged, no guessed daily pace or spendable balance.
2. **Information priority**: seven-date context and the *first Actual record*
   are visible on normal terminals; on very short terminals, a truthful
   summary and a reliable Tab/Esc path to exact details remain.
3. **Mechanical quality**: `z` really means Week/Month/Year; `h/l` day,
   `j/k` week in Week mode, `/` jump, `t` today, `Enter`, Tab/w and
   focused scrolling behave at every breakpoint with no extra writes or CI
   test suite proliferation.

Do not turn full-period totals into a week total by merely changing a label.
The existing `Month Flow` aggregation must retain its calendar-month
window and be accessible through the Month view.

## Proposed small PR sequence

1. **This PR**: reuse Gregorian month grid to expose a pure Monday-first
   selected-week projection and retain these visual study hypotheses. No user
   behavior or data changes.
2. **Week rendering prototype**: a dedicated Week Home projection using the
   same admitted Snapshot and existing Actual/Scheduled detail source. Try A
   at several widths and compare with B/C on synthetic fixtures. No default
   cutover before the visual and navigation contract is coherent.
3. **Zoom + navigation cutover**: expose Week, Month, Year as the user-facing
   `z` cycle with proper one-month daily grid and 12-month overview, preserving
   explicit jump/date target semantics and migration of existing Home tests.
4. **Polish**: manage short-terminal footer pressure, focus/border hierarchy,
   multiple Measures, diagnostic overflow and actual PTY before/after reviews.

Re-evaluate or retire the losing presentation variants after actual use.
The world-class aspiration is a testable design goal, not a measured ranking.
