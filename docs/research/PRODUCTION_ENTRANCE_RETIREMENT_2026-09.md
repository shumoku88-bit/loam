# Production entrance retirement audit — 2026-09

Status: **QUALIFIED FIRST SLICE**

Base: `f55e97a712375200c42672e1155027b2cf3fe0a4`

This audit follows the completed six-phase compression audit. The earlier audit removed unreachable practical code; this pass asks a different question:

> Which executable-reachable human entrances are still compiled even though current household authority and the production TUI have superseded them?

The unit of retirement is the human entrance. Shared publishers, projections, persistence, and Core/Application semantics are not retired merely because an old CLI is.

## Current entry surface

`lakefile.lean` declares 15 executables. `tools/loam` additionally implements a second no-argument interactive menu and dispatches several dedicated executables.

The production TUI is `loamTui`.

## Qualified retirement: sidecar-only correction entrances

### `Loam/Cli/CorrectionCli.lean`

The legacy movement-correction CLI is an interactive sidecar entrance. It is not manifest-aware.

Current production TUI correction uses `Loam.Tui.Correction` for presentation and publishes through `Loam.CorrectionPublisher.publishManifestCorrection`, which re-reads current manifest authority.

`tools/loam` already refuses its `correct` menu action when Movement manifest authority is present.

Decision: **RETIRE human entrance.**

Preserve `CorrectionPublisher`, correction semantics, correction-aware reads, and TUI/publisher tests.

### `Loam/Cli/ActualValidityCorrectionCli.lean`

The legacy date-correction CLI reads sidecar EventMemory and writes the sidecar-derived ActualValidity history directly. It does not use the manifest-aware `ActualValidityPublisher`.

Current production TUI date correction publishes through `Loam.ActualValidityPublisher.publishManifestDate`.

Direct `./tools/loam correct-date ...` remains callable today, so this stale path can mutate evidence outside current Movement manifest authority.

Decision: **RETIRE human entrance.**

Preserve `ActualValidityPublisher`, ActualValidity semantics, and TUI/publisher tests.

## Keep for now: Review

`Loam.ReviewCli` is not the same obsolete-authority case. `Loam.ActualReview.loadRecords` selects manifest authority when `LOAM_MOVEMENT_MANIFEST_ROOT` is present and falls back to sidecar only when it is absent.

Decision: **KEEP as scriptable/read-only harness for now.**

Its interactive pagination/search browser may later be replaced by smaller output plus optional `fzf`, but that is a presentation subtraction experiment rather than an authority retirement.

## Keep for now: Movement CLI

`Loam/Cli/MovementCli.lean` publishes through `MovementPublisher` under manifest authority. The production TUI uses the same publisher.

Decision: **KEEP scriptable entrance for now.**

Its interactive editor may later be evaluated separately from publication semantics.

## Strong next candidate: no-argument `tools/loam` menu

The shell wrapper still implements a second persistent interactive menu with Record, Review, Balance, Correction, Capacity, Scheduled, Effective, Integrity, and raw actions.

Current production TUI now owns the household human workspace. The shell menu also contains manifest-mode branches that explicitly disable obsolete sidecar actions.

Decision: **RETIREMENT CANDIDATE.**

A smaller wrapper could make `loamTui` the default human entrance while retaining explicit named script/diagnostic commands.

## Unix-tool subtraction candidate

`Loam/CompletionPrompt.lean` owns POSIX terminal state capture, raw character mode, byte-at-a-time input, backspace/Ctrl-C handling, redraw, prefix filtering, and candidate display.

This is presentation-only machinery. A bounded `fzf` adapter is a legitimate experiment if:

- LOAM still owns the candidate set and typed admission;
- `fzf` returns only selected/entered text;
- redirected/non-TTY input retains plain-line behavior;
- absence of `fzf` fails back to plain input rather than blocking production;
- no household semantics, authority selection, or publication policy move into shell/fzf.

Do not replace the persistent production TUI workspace with an fzf state machine.

## First subtraction order

1. retire `correct` and `correct-date` public dispatch/help;
2. delete the two sidecar-only CLI modules and unreachable standalone correction wrapper if no remaining caller exists;
3. graduate CI that protects only those retired human entrances while retaining publisher/TUI coverage;
4. separately measure replacement of the no-argument shell menu by TUI-default dispatch;
5. only after entrance retirement, determine whether `CompletionPrompt` still has a production caller. If it becomes unreachable, delete it instead of introducing `fzf`.

This ordering intentionally prefers **whole-path deletion** over replacing code with an external dependency.
