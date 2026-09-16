#!/usr/bin/env python3
from pathlib import Path

ledger = Path('docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md')
text = ledger.read_text()
text = text.replace(
    'Status: **MGA-015 IN QUALIFICATION — ScheduledCompletionSession narrow effect-shell experiment; PR #974**',
    'Status: **MGA-015 COMPLETE — ScheduledCompletionSession KEEP_BOUNDARY / SPLIT_QUALIFIED; PR #974 ready for merge**',
    1,
)

start = text.index('## Refreshed inventory\n')
end = text.index('## MGA-001', start)
refreshed = '''## Refreshed inventory

The module-granularity inventory was rerun on the PR #974 merge candidate after extracting
`Loam.Tui.ScheduledCompletionSession`.

```text
Lean modules: 334
Modules <= 80 lines: 91
Modules with exactly one local consumer: 54
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

The raw module, small-module, and one-consumer counts each increased by one from MGA-014,
exactly as expected for one focused Session extraction. No production-like surface became
unreachable. Current focused metrics are:

```text
Loam.Tui.Cli                          1116 lines / 30 declarations / fan-out 57
Loam.Tui.RecordSession                  48 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.CorrectionSession              49 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.ScheduledReplacementSession    51 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.ScheduledCompletionSession     50 lines /  1 declaration  / fan-in 1 / fan-out 5
Loam.Tui.ScheduledCompletion           144 lines /  9 declarations / fan-in 3 / fan-out 3
```

MGA-014 left `Tui.Cli` at 1143 lines / 31 declarations / fan-out 56. MGA-015 therefore
removes another object-local effect loop and one declaration from the composition root,
while adding one explicit dependency edge to the new Session. The fan-out increase is not
treated as a regression: responsibility ownership, reachability, and change independence
decide the boundary rather than raw file or edge counts.

The qualified dependency seams are now explicit:

```text
Tui.Cli -> RecordSession                -> Record + HouseholdCommand
Tui.Cli -> CorrectionSession            -> Correction + HouseholdCommand
Tui.Cli -> ScheduledReplacementSession  -> ScheduledReplacement + HouseholdCommand
Tui.Cli -> ScheduledCompletionSession   -> ScheduledCompletion + HouseholdCommand
```

'''
text = text[:start] + refreshed + text[end:]

text = text.replace(
    'Classification checkpoint: **SPLIT_CANDIDATE — IMPLEMENTATION UNDER QUALIFICATION (PR #974)**',
    'Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — PR #974 ready for merge**',
    1,
)

final_marker = '### MGA-015 final qualification\n'
if final_marker not in text:
    text += '''

### MGA-015 final qualification

The narrow extraction qualifies as a durable physical boundary rather than naming symmetry:

- the same effect shell is entered from both HRA Scheduled and SelectedDay;
- `ScheduledCompletion` retains editor state, validation, transitions, preview, draft construction,
  refusal restoration, and view;
- `ScheduledCompletionSession` owns only key reads, dirty redraws,
  `HouseholdCommand.completeScheduled` delegation, refusal retry, and the Boolean session result;
- the Boolean result remains the explicit stop line before optional next-Scheduled creation and
  routing inheritance, so continuation semantics were not absorbed into the Session;
- publication authority remains outside TUI;
- the new 50-line module is reachable, has fan-in 1 / fan-out 5, and no production-like module
  became unreachable;
- `Tui.Cli` fell from 1143 lines / 31 declarations to 1116 lines / 30 declarations while keeping
  continuation orchestration visible at the two caller sites.

Qualification on PR #974 succeeded:

- Production TUI #812 — SUCCESS;
- Compression Audit #950 — SUCCESS;
- Module granularity inventory #20 — SUCCESS;
- Selected Lean Observations #1194 — SUCCESS;
- Purpose Catalog Boundary #331 — SUCCESS.

The result is therefore **KEEP_BOUNDARY / SPLIT_QUALIFIED**. Any future attempt to deduplicate
completion continuation creation/routing is a separate audit question and is not implied by this
Session boundary.
'''
ledger.write_text(text)

builder = Path('docs/drakon/build_tui_scheduled_session_audit_map.py')
b = builder.read_text()
name = 'MGA.015.2 Qualified Scheduled Completion Session Seam'
if name not in b:
    insertion = '''    "MGA.015.2 Qualified Scheduled Completion Session Seam": {
        "description": "Record the narrow Completion terminal/effect split after production, inventory, and continuation-boundary qualification.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledCompletion.lean; Loam/Tui/ScheduledCompletionSession.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; PR #974",
        "audit": "PR #974 extracted only the reusable Completion terminal/effect shell. ScheduledCompletion still owns editor semantics; ScheduledCompletionSession owns key reads, dirty redraws, HouseholdCommand.completeScheduled delegation and refusal retry, and returns Bool only. HraScheduled and SelectedDay retain optional next-Scheduled creation, routing inheritance, canonical reload and destination refresh. Production TUI #812, Compression Audit #950, module inventory #20, Selected Lean Observations #1194 and Purpose Catalog Boundary #331 all succeeded. Inventory reports the new Session at 50 lines / one declaration / fan-in 1 / fan-out 5 / reachable, with zero production-like unreachable modules. The boundary therefore graduates to KEEP_BOUNDARY / SPLIT_QUALIFIED without absorbing continuation semantics.",
        "nodes": [
            ("action", "ScheduledCompletion.State / validation / preview / view"),
            ("insertion", "ScheduledCompletionSession.run"),
            ("action", "read terminal key + update + dirty redraw"),
            ("decision", "Step publishes completion draft?", "YES"),
            ("insertion", "HouseholdCommand.completeScheduled"),
            ("decision", "publication refused?", "YES -> same editor retry"),
            ("action", "Session returns Bool only"),
            ("decision", "completion published?", "NO -> cancellation notice"),
            ("action", "caller retains optional creation + routing inheritance + reload + workspace refresh"),
            ("action", "inventory: 50 lines / fan-in 1 / fan-out 5 / reachable"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
        ],
    },
'''
    marker = '}\n\n\ndef build() -> None:'
    if b.count(marker) != 1:
        raise SystemExit('unexpected DRAKON builder shape')
    b = b.replace(marker, insertion + marker, 1)
    builder.write_text(b)
