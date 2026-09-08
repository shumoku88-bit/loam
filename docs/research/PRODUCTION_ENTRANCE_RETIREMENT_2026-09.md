# Production entrance retirement audit — 2026-09

Status: **QUALIFIED FIRST SLICE + FOLLOW-UP PRESENTATION SUBTRACTION + EXECUTABLE RE-AUDIT**

Base: `f55e97a712375200c42672e1155027b2cf3fe0a4`

This audit follows the completed six-phase compression audit. The earlier audit removed unreachable practical code; this pass asks a different question:

> Which executable-reachable human entrances are still compiled even though current household authority and the production TUI have superseded them?

The unit of retirement is the human entrance. Shared publishers, projections, persistence, and Core/Application semantics are not retired merely because an old CLI is.

## Current entry surface at the audit baseline

`lakefile.lean` declared 15 executables. `tools/loam` additionally implemented a second no-argument interactive menu and dispatched several dedicated executables.

The production TUI is `loamTui`.

The no-argument shell menu was subsequently retired in favor of TUI-default dispatch. The custom wrapper build-cache layer was also retired after its own qualification showed that Lake could own freshness directly. Those later cuts preserve the baseline below as audit provenance rather than rewriting the sequence that exposed them.

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

## Review follow-up: keep query harness, retire browser

`Loam.ReviewCli` is not the same obsolete-authority case. `Loam.ActualReview.loadRecords` selects manifest authority when `LOAM_MOVEMENT_MANIFEST_ROOT` is present and falls back to sidecar only when it is absent.

The first audit therefore kept Review as a scriptable/read-only harness while identifying its interactive pagination/search browser as a separate presentation subtraction candidate.

That follow-up is now qualified:

- keep `ActualReview.loadRecords`, `Query`, `parseQuery`, correction-aware selection, search semantics, fail-closed admission, and the bounded ten-row result;
- keep `./tools/loam review ... [QUERY]` as a one-shot scriptable/read-only entrance;
- retire TTY branching, prompt input, `p` / `n`, `more` / `back`, numbered detail selection, raw `#EventId` navigation, reload, and recursive browser state;
- use the production TUI Actual workspace for interactive browse/detail;
- keep explicit lower-level `event-memory review` for unbounded raw inspection.

Decision: **KEEP semantic query harness; RETIRE second interactive UI.**

This is presentation subtraction, not authority retirement. No new external tool or replacement browser is introduced.

## Keep for now: Movement CLI

`Loam/Cli/MovementCli.lean` publishes through `MovementPublisher` under manifest authority. The production TUI uses the same publisher.

Decision: **KEEP scriptable entrance for now.**

Its interactive editor may later be evaluated separately from publication semantics.

## Qualified later: no-argument `tools/loam` menu

At this audit baseline the shell wrapper still implemented a second persistent interactive menu with Record, Review, Balance, Correction, Capacity, Scheduled, Effective, Integrity, and raw actions.

The production TUI now owns the household human workspace. The shell menu also contained manifest-mode branches that explicitly disabled obsolete sidecar actions.

Decision at baseline: **RETIREMENT CANDIDATE.**

This was subsequently completed: `./tools/loam` with no arguments now opens `loamTui`, while explicit named script/diagnostic commands remain.

## Qualified follow-up: line-CLI Locus completion

At the audit baseline `Loam/CompletionPrompt.lean` owned POSIX terminal state capture, raw character mode, byte-at-a-time input, backspace/Ctrl-C handling, ANSI redraw, prefix filtering, and candidate display.

A bounded `fzf` adapter was considered but never earned. After TUI-default entrance and interactive Review retirement, the remaining Movement CLI is more valuable as an explicit scriptable/diagnostic entrance than as a second terminal UI.

The follow-up therefore retires the custom line-CLI completion engine:

- `MovementEntry` returns to ordinary line input;
- Movement preflight keeps its fail-closed authority verification but no longer derives historical Locus hints for the line editor;
- `CompletionPrompt.knownLoci` remains as a pure recognition projection because the production TUI still consumes previously observed Loci as presentation hints;
- current `LocusAdmissionVocabulary` remains the separate new-write permission authority;
- no `fzf`, readline framework, generic completion abstraction, or replacement terminal state machine is introduced.

Decision: **RETIRE raw-terminal completion UI; KEEP pure observed-Locus hint projection.**

This leaves future TUI/CLI/GUI surfaces free to choose their own presentation mechanics while sharing current admission/publication boundaries. Historical recognition and new-write permission remain deliberately distinct.

## Re-audit of all 15 Lake executables

A fresh re-audit at main `9d7d76105f0816dfa8367ef5c7cdc37f45e8473a`, after production TUI Scheduled routing was wired through `ScheduledRoutingPublisher`, classified every Lake executable by its current independent role rather than by whether `tools/loam` directly dispatches it.

| Lake target | Decision | Current independent role |
| --- | --- | --- |
| `loam` | KEEP | explicit low-level and diagnostic command dispatcher |
| `loamMovement` | KEEP | scriptable manifest-aware Movement publication |
| `loamCapacity` | KEEP | explicit Capacity query/publication entrance |
| `loamActualRouting` | KEEP | scriptable Actual routing writer and practical qualification surface |
| `loamScheduledRouting` | KEEP | thin scriptable surface over shared `ScheduledRoutingPublisher`; TUI uses the same publisher |
| `loamBudgetWindow` | KEEP | scriptable read-only Budget Window projection useful outside TUI presentation |
| `loamDailyQuantity` | KEEP | explicit `balances` / `current` projection entrance |
| `loamOpenScheduled` | KEEP | explicit open-Scheduled read projection |
| `loamScheduledSuppression` | KEEP | targeted suppression/replacement diagnostic retained by current practical Scheduled reader qualification |
| `loamJournalExport` | KEEP | explicit readable-journal regeneration/export boundary with its own practical qualification |
| `loamShadowAudit` | KEEP | independent read-only external snapshot shape audit |
| `loamShadowQuantity` | KEEP | independent identity-renaming-invariant quantity research entrance |
| `loamShadowDay` | RETIRE | historical external-journal selected-day adapter from Application 012 |
| `loamShadowScheduledDay` | RETIRE | historical external plan/actual-journal selected-day adapter from Application 013 |
| `loamTui` | KEEP | default production human workspace |

The two retired day adapters are not current household authority and are not shared semantic boundaries. Each parses an external journal-shaped source directly and owns presentation-local reconstruction used only by the historical Application 012-014 experiments and their dedicated compositor/workflows.

Application 012-014 therefore graduate under the same research lifecycle already established by the compression audit:

- preserve `experiments/application_012_shadow_day_reader.md`, `application_013_shadow_scheduled_day_reader.md`, and `application_014_shadow_home_day_composition.md` as research evidence;
- preserve Git history for the exact executable implementations and synthetic qualification;
- retire `Loam/Cli/ShadowDayCli.lean` and `Loam/Cli/ShadowScheduledDayCli.lean`;
- retire `tools/shadow-home-day`;
- retire the three dedicated Application 012-014 workflows;
- remove only the two corresponding Lake targets;
- do not retire `loamShadowAudit` or `loamShadowQuantity`, whose external-snapshot questions remain distinct.

Decision: **RETIRE historical journal day-view execution apparatus; KEEP the research result in prose and history.**

This reduces executable count from 15 to 13 without collapsing CLI/TUI/possible future GUI boundaries or deleting a shared publisher/query semantic boundary.

## First subtraction order

1. retire `correct` and `correct-date` public dispatch/help;
2. delete the two sidecar-only CLI modules and unreachable standalone correction wrapper if no remaining caller exists;
3. graduate CI that protects only those retired human entrances while retaining publisher/TUI coverage;
4. replace the no-argument shell menu by TUI-default dispatch;
5. retire wrapper-private build-cache mechanics in favor of Lake freshness;
6. shrink Review from a second interactive browser to a one-shot bounded query harness;
7. retire line-CLI raw Locus completion while retaining the pure observed-Locus hint projection used by TUI;
8. re-audit all 15 Lake executables and graduate the historical Application 012-014 journal day-view apparatus.

This ordering intentionally prefers **whole-path deletion** over replacing code with an external dependency.
