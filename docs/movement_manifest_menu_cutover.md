# Movement manifest household entrance repair

> Historical cutover note. This document records the retired no-argument shell-menu repair and its then-open checklist. Current household entrance guidance lives in `README.md` and `docs/TUI.md`; `./tools/loam` now opens the production TUI by default.

## Observed seam

Private household dogfood retired the legacy Movement sidecars after selecting
`movement-authority/CURRENT`. The ordinary `tools/loam` menu still gated review
on `memory.loam` existence and loaded balances from that absent file. A populated
household consequently appeared unrecorded, with basis-only balances (zero in
the observed display). The menu's writer also lacked manifest selection.

This is an authority-routing defect, not evidence of zero quantity or lost
household history. Recreating frozen sidecars would introduce another authority
rather than repair the entrance.

## Focused correction

- The no-argument menu selects its data directory's `movement-authority` when
  present, unless `LOAM_MOVEMENT_MANIFEST_ROOT` was explicitly supplied.
- Directory presence selects the backend even when `CURRENT` is missing. Broken
  selected authority must refuse; it must not become an empty sidecar world.
- Review no longer checks sidecar existence in manifest mode. Its existing
  verified manifest reader supplies Events, dates, and descriptions.
- Daily `balances` and `current` load Events through the same verified manifest
  authority when selected. All five referenced families are verified. Existing
  correction-frontier, basis-correction, basis-cut, and view selection logic
  remains downstream; it is not replaced by raw summation.
- Menu recording inherits the selection and uses the already-existing manifest
  preflight/publication path. No conversion or new persistence is introduced.
- Menu `correct`, `raw`, `effective`, `integrity`, and `scheduled` currently have
  no manifest-aware implementation and explicitly refuse in this mode before
  invoking a sidecar reader or writer. This is a visible limitation, not a claim
  those household capabilities have been ported.

Direct CLI invocations still select the backend explicitly with
`LOAM_MOVEMENT_MANIFEST_ROOT`; automatic directory selection belongs to the
no-argument household menu. Isolated sidecar fixtures retain their old behavior.
Basis, corrections, and view configuration remain their separate evidence/config
files. This change does not claim an atomic snapshot across those files and the
Movement generation.

## Remaining work (open checklist)

The menu repair is complete; the manifest cutover of every practical entrance is
**not** complete. Keep the menu refusals until the corresponding paths below are
qualified. These are concrete gaps, not a requirement to redesign the whole core.

- [ ] **Movement and date correction (`correct`)**: select manifest evidence for
  review/preflight and publication. Qualify interrupted publication/recovery,
  correction-frontier review, historical dates, and correction-root basis cuts.
  Do not enable the menu action merely by changing its read source.
- [ ] **Raw/effective quantities and correction integrity (`raw`, `effective`,
  `integrity`)**: read the selected generation, preserve the distinction between
  raw evidence and corrected answers, and refuse malformed correction evidence.
- [ ] **Open scheduled view (`scheduled`)**: use selected Actual evidence alongside
  Scheduled lifecycle evidence. Qualify completed/open answers and missing or
  invalid referenced Actual evidence before removing the menu refusal.
- [ ] **Direct CLI authority selection/safety**: the menu selects the household
  backend automatically, but direct commands still require explicit
  `LOAM_MOVEMENT_MANIFEST_ROOT`, and not all command implementations honor it.
  Prevent sidecar-only direct readers/writers from silently using retired or
  absent files in a manifest household. Cover both environment-selected and
  data-path-based invocations, with no accidental second writer authority.
- [ ] **Visible availability in the menu**: mark or omit unported actions before
  selection, while retaining fail-closed dispatch checks for typed action names.

For each completed item, link the focused test/qualification and remove only its
corresponding refusal. Do not restore legacy sidecars as a shortcut.

## Executable qualification

`tests/test_record_review.py` runs in the existing practical-movement CI job.
Its manifest menu specimens cover:

- retired sidecars with nonempty selected Events, dates, and recognition text;
- correction-aware balances and a correction-root basis cut;
- corrupt referenced discharge evidence and missing CURRENT refusing without
  stale-sidecar fallback or a plausible balance;
- unported actions refusing without changing persistence;
- recording through the menu, then reviewing the published generation and its
  updated balance, without creating legacy Movement sidecars;
- empty/missing explicit manifest selection refusing in both quantity commands;
- the pre-existing sidecar review/correction and terminal navigation regressions.

Local qualification passed: all 13 Python regression tests, the five menu binary
build targets, and shell syntax checking. A private read-only menu run rendered
both review and balances, emitted no error or false empty-record message, and
left all non-Git data file contents unchanged. This verifies entrance recovery,
not independent numerical parity with another accounting system.

Private verification must capture household output locally and report only
structural success/failure, never public values or recognition text.
