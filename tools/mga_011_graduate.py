#!/usr/bin/env python3
from pathlib import Path

ledger_path = Path('docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md')
ledger = ledger_path.read_text()

ledger = ledger.replace(
    'Status: **MGA-011 IMPLEMENTATION EXPERIMENT — Correction terminal session extraction under qualification**',
    'Status: **MGA-011 GRADUATED — Correction session split qualified; ActualDateCorrection selected as the next anti-symmetry control**',
    1,
)
ledger = ledger.replace(
    'The module-granularity inventory was rerun on the PR #961 head after extracting\n`Loam.Tui.RecordSession`.',
    'The module-granularity inventory was rerun on the PR #964 merge candidate after extracting\n`Loam.Tui.CorrectionSession`.',
    1,
)
ledger = ledger.replace(
    'Lean modules: 331\nModules <= 80 lines: 88\nModules with exactly one local consumer: 51\nDeclared Lake roots: 17\nProduction-like modules unreachable from declared roots: 0',
    'Lean modules: 332\nModules <= 80 lines: 89\nModules with exactly one local consumer: 52\nDeclared Lake roots: 17\nProduction-like modules unreachable from declared roots: 0',
    1,
)
ledger = ledger.replace(
    'The raw counts increased by one module, one small module, and one one-consumer\nmodule. That is expected: MGA-010 intentionally added a physical boundary.\nThe important result is that no production-like surface became unreachable and\nthat the new dependency direction is explicit:\n\n```text\nTui.Cli -> RecordSession -> Record + HouseholdCommand\n```\n\nCurrent focused metrics:\n\n```text\nLoam.Tui.Cli           1200 lines / 33 declarations / fan-out 54\nLoam.Tui.RecordSession   48 lines /  1 declaration  / fan-in 1 / fan-out 5\nLoam.Tui.Record          302 lines / 28 declarations / fan-in 7 / fan-out 6\n```',
    'The raw counts again increased by one module, one small module, and one\none-consumer module. MGA-011 deliberately tests whether that apparent metric\nregression can still represent a cleaner ownership boundary. No production-like\nsurface became unreachable. The two qualified dependency seams are now explicit:\n\n```text\nTui.Cli -> RecordSession     -> Record + HouseholdCommand\nTui.Cli -> CorrectionSession -> Correction + HouseholdCommand\n```\n\nCurrent focused metrics:\n\n```text\nLoam.Tui.Cli              1179 lines / 32 declarations / fan-out 55\nLoam.Tui.RecordSession      48 lines /  1 declaration  / fan-in 1 / fan-out 5\nLoam.Tui.CorrectionSession  49 lines /  1 declaration  / fan-in 1 / fan-out 5\n```',
    1,
)

heading = '## MGA-011 — `Loam.Tui.CorrectionSession` candidate'
if heading not in ledger:
    raise SystemExit('MGA-011 heading not found')
prefix = ledger.split(heading, 1)[0]
tail = '''## MGA-011 — `Loam.Tui.CorrectionSession` focused extraction

Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — CLOSED by PR #964**

PR #964 moved only the Correction terminal key-read/redraw/publication loop into
`Loam.Tui.CorrectionSession`:

- `Loam.Tui.Correction` still owns replacement-editor state, validation,
  transitions, publication-intent construction, and view;
- `CorrectionSession` owns terminal reads, dirty redraws, delegation to
  `HouseholdCommand.correctActual`, and retry-on-publication-error;
- `HouseholdCommand.correctActual` remains the authoritative production write
  entrance;
- `Tui.Cli` still owns selected-world loading, canonical reload, and destination
  workspace orchestration.

The PR head passed all focused qualification gates:

- Production TUI;
- Compression Audit;
- Module granularity inventory;
- Selected Lean Observations;
- Purpose Catalog Boundary.

The refreshed inventory reported 332 Lean modules, 89 modules at or below 80
lines, 52 one-consumer modules, and zero production-like modules unreachable from
Lake roots. Those first three counts rose by one again, but the semantic result is
positive: the change isolates one effect/change reason without creating another
state owner or authority boundary.

MGA-010 and MGA-011 together establish that a small one-consumer `*Session`
module can be justified when it owns an effect shell that changes for different
reasons from the pure editor/presentation module.

## MGA-012 — `Loam.Tui.ActualDateCorrection` anti-symmetry control

Classification: **NEEDS_DRAKON / SPLIT_CANDIDATE — DO NOT EXTRACT YET**

Four local editor/effect loops remain in `Tui.Cli`:

1. `actualDateCorrectionLoop`;
2. `scheduledCompletionLoop`;
3. `scheduledCancellationLoop`;
4. `scheduledReplacementLoop`.

`ActualDateCorrection` is the next useful control precisely because it is smaller
and more special-purpose than Record or Correction. Its current shape is strongly
session-like:

- `ActualDateCorrection` owns date-editor state, validation, transition, and view;
- the local loop owns terminal reads, dirty redraws, delegation to
  `HouseholdCommand.correctActualDate`, and retry after publication refusal;
- the loop returns only a human-facing notice;
- the caller retains canonical reload and workspace destination.

But that similarity is not itself permission to create another file. MGA-012 asks
a sharper question: **does this tiny effect shell have an independent change
reason, or would a separate `ActualDateCorrectionSession` merely copy the naming
pattern established by Record and Correction?**

This is the anti-symmetry control for the audit. Before any extraction, use the
DRAKON map to compare the two physical shapes:

```text
A. keep the tiny terminal loop in Tui.Cli
B. extract ActualDateCorrectionSession
```

Prefer B only if it improves ownership/navigation while preserving one semantic
owner and one authority owner. If the only argument is naming consistency with
Record/Correction, keep A.

The Scheduled loops remain deliberately deferred. `ScheduledCompletion` is still
more coupled because its Boolean result feeds continuation creation and routing
inheritance; cancellation and replacement should be judged from their own
workflow ownership rather than from `*Session` symmetry.
'''
ledger_path.write_text(prefix + tail)

map_path = Path('docs/drakon/build_tui_cli_granularity_audit_map.py')
drakon = map_path.read_text()
drakon = drakon.replace(
    'PR #961 removed the Record terminal/effect loop, but key grammars, snapshot/config loading, four local editor loops,',
    'PRs #961 and #964 removed the Record and Correction terminal/effect loops, but key grammars, snapshot/config loading, four local editor loops,',
    1,
)

start = drakon.find('    "MGA.010.2 Remaining Session Comparison": {')
end = drakon.find('    "MGA.010.3 Stop Rule": {', start)
if start < 0 or end < 0:
    raise SystemExit('comparison diagram block not found')
replacement = '''    "MGA.011.1 Qualified Correction Session Seam": {
        "description": "Record the second focused split and use it to calibrate the next anti-symmetry control.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/Correction.lean; Loam/Tui/CorrectionSession.lean; Loam/HouseholdCommand.lean; PR #964",
        "audit": "Correction owns replacement-editor state, validation, transitions and view. CorrectionSession owns key reads, dirty redraws, publication delegation and retry-on-publication-error. HouseholdCommand.correctActual remains authoritative, while Tui.Cli keeps canonical reload and workspace destination. PR #964 passed Production TUI, Compression Audit, Module granularity inventory, Selected Lean Observations and Purpose Catalog Boundary. The boundary therefore qualifies even though it adds another small one-consumer module.",
        "nodes": [
            ("action", "Correction.State / Step / view"),
            ("insertion", "CorrectionSession.run"),
            ("action", "read terminal key"),
            ("action", "Correction.update + dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.correctActual"),
            ("action", "publication refusal returns to same editor"),
            ("action", "caller reloads canonical evidence + chooses destination"),
            ("decision", "Independent effect/change boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT QUALIFIED"),
        ],
    },
    "MGA.012.1 Actual Date Anti-Symmetry Control": {
        "description": "Compare keeping the tiny ActualDateCorrection loop in Tui.Cli against extracting another Session module before making a symmetry-driven change.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ActualDateCorrection.lean; Loam/HouseholdCommand.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "ActualDateCorrection already owns date-editor state, validation, transitions and view. Its local Tui.Cli loop owns key reads, dirty redraws, HouseholdCommand.correctActualDate delegation and retry on refusal. That resembles the two qualified session seams, but the shell is especially small. MGA-012 is therefore an anti-symmetry control: compare INLINE versus SESSION and extract only if ownership and navigation improve for an independent reason, not merely because RecordSession and CorrectionSession exist.",
        "nodes": [
            ("action", "ActualDateCorrection.State / Step / view"),
            ("action", "current local loop in Tui.Cli"),
            ("decision", "Effect shell has independent change reason?", "TO TEST"),
            ("action", "Shape A: keep loop inline"),
            ("action", "Shape B: extract ActualDateCorrectionSession"),
            ("decision", "Only argument is naming symmetry?", "YES -> KEEP INLINE"),
            ("decision", "Ownership/navigation materially clearer?", "YES -> narrow extraction experiment"),
        ],
    },
'''
drakon = drakon[:start] + replacement + drakon[end:]
drakon = drakon.replace(
    'The current experiment is Correction only; the other local loops remain uncommitted candidates.',
    'Record and Correction are qualified; the next test is whether the much smaller ActualDateCorrection shell deserves a boundary at all.',
    1,
)
drakon = drakon.replace(
    '("action", "Current test: qualify Correction; otherwise return it to Tui.Cli"),',
    '("action", "Next test: compare INLINE vs SESSION for ActualDateCorrection"),',
    1,
)
drakon = drakon.replace('LOAM MGA.009-011 - TUI CLI module granularity', 'LOAM MGA.009-012 - TUI CLI module granularity', 1)
drakon = drakon.replace('MGA.009-011 TUI CLI module granularity', 'MGA.009-012 TUI CLI module granularity', 1)
map_path.write_text(drakon)
