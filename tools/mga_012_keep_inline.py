#!/usr/bin/env python3
from pathlib import Path

ledger_path = Path("docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md")
ledger = ledger_path.read_text()

ledger = ledger.replace(
    "Status: **MGA-011 GRADUATED — Correction session split qualified; ActualDateCorrection selected as the next anti-symmetry control**",
    "Status: **MGA-012 CLOSED — ActualDateCorrection terminal loop stays inline; physical Session symmetry rejected**",
    1,
)
ledger = ledger.replace(
    "KEEP_BOUNDARY\nCOLLAPSE_CANDIDATE",
    "KEEP_BOUNDARY\nKEEP_INLINE\nCOLLAPSE_CANDIDATE",
    1,
)
heading = "## MGA-012 — `Loam.Tui.ActualDateCorrection` anti-symmetry control"
if heading not in ledger:
    raise SystemExit("MGA-012 heading not found")
prefix = ledger.split(heading, 1)[0]
tail = r'''## MGA-012 — `Loam.Tui.ActualDateCorrection` anti-symmetry control

Classification: **KEEP_INLINE / SPLIT_REJECTED**

MGA-012 deliberately tested the opposite conclusion from MGA-010 and MGA-011.
`ActualDateCorrection` already has a clean semantic boundary: the module owns
editor state, date validation, transition, publication intent, and view, while
`HouseholdCommand.correctActualDate` remains the authoritative write entrance.
The only question was whether the tiny terminal/effect loop still living in
`Tui.Cli` deserved another physical `*Session` module.

The comparison rejects that split for now:

- the loop has one caller and only one selected-day entrance;
- the caller must still own selected-record lookup, `initial?`, first editor
  redraw, canonical reload, `SelectedDay.refreshed`, and destination redraw, so
  extracting the inner loop removes little workflow-navigation burden;
- the effect shell carries no reusable world/catalog context and returns only a
  short notice;
- `Loam/Tui/ActualDateCorrection.lean` has only one repository-history commit,
  PR #519, where the editor, selected-day delegation, publication wiring, tests,
  and terminal loop were introduced together; there is no historical evidence
  yet that the shell changes independently;
- semantic ownership is already non-duplicated and authority remains outside the
  TUI, so leaving the shell inline does not create a second model or writer.

This differs from Record and Correction in an important way. Their extraction
removed a substantial object-local terminal session from the composition root and
made an independently useful call boundary. For ActualDateCorrection, creating a
new file would mostly turn a logically separable but tiny implementation detail
into another one-consumer module. Logical separability is therefore not enough by
itself to justify physical module ownership.

The anti-symmetry control is successful because it produces a negative result:

```text
same editor/session shape
!=
automatically same file split
```

The current dependency shape remains:

```text
Tui.Cli
  -> ActualDateCorrection   (state / validation / transition / view)
  -> HouseholdCommand.correctActualDate  (authoritative write entrance)
```

No production code changes are required for MGA-012.

## MGA-013 — remaining Scheduled local-loop topology

Classification: **NEEDS_DRAKON / NEEDS_HISTORY — NO BATCH EXTRACTION**

Three local Scheduled editor/effect loops remain in `Tui.Cli`:

1. `scheduledCompletionLoop`;
2. `scheduledCancellationLoop`;
3. `scheduledReplacementLoop`.

They must not be treated as a naming family. Their continuation semantics differ:
completion returns a Boolean into next-Scheduled creation and routing inheritance;
cancellation is a compact confirmation/publication path; replacement owns an
editor retry path closer to Correction. MGA-013 should compare those three
control-flow shapes before considering any further physical split.

The next audit therefore asks which, if any, of those loops has a durable
independent change/effect boundary that materially improves navigation when
extracted. A shared `Scheduled*Session` pattern is not an objective.
'''
ledger_path.write_text(prefix + tail)

map_path = Path("docs/drakon/build_tui_cli_granularity_audit_map.py")
text = map_path.read_text()
start = text.find('    "MGA.012.1 Actual Date Anti-Symmetry Control": {')
end = text.find('    "MGA.010.3 Stop Rule": {', start)
if start < 0 or end < 0:
    raise SystemExit("MGA-012 DRAKON block not found")
new_block = r'''    "MGA.012.1 Actual Date Anti-Symmetry Verdict": {
        "description": "Record the negative control: keep the tiny ActualDateCorrection terminal loop inline instead of copying the Session naming pattern.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ActualDateCorrection.lean; Loam/HouseholdCommand.lean; PR #519; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "ActualDateCorrection already owns state, validation, transitions, publication intent and view, while HouseholdCommand.correctActualDate remains authoritative. The local terminal loop has one selected-day caller and no reusable world/catalog context. Extracting it would not remove the surrounding selected-record lookup, initial editor construction, canonical reload, SelectedDay refresh, or destination redraw from Tui.Cli. File history shows the editor and terminal wiring were introduced together in PR #519 and have not shown an independent change history. MGA-012 therefore keeps the shell inline: logical separability alone does not justify another physical module.",
        "nodes": [
            ("action", "ActualDateCorrection.State / Step / view"),
            ("action", "tiny terminal/effect loop stays in Tui.Cli"),
            ("insertion", "HouseholdCommand.correctActualDate"),
            ("action", "caller reloads canonical evidence + refreshes SelectedDay"),
            ("decision", "Would Session extraction remove workflow coupling?", "NO"),
            ("decision", "Independent history / reuse / ownership pressure?", "NO EVIDENCE YET"),
            ("decision", "Split only for Record/Correction symmetry?", "REJECT"),
            ("action", "KEEP_INLINE / SPLIT_REJECTED"),
        ],
    },
'''
text = text[:start] + new_block + text[end:]

text = text.replace(
    '    "MGA.010.3 Stop Rule": {',
    '    "MGA.012.2 Physical Boundary Stop Rule": {',
    1,
)
text = text.replace(
    '"description": "Calibrate the coarse-file audit with the Record result and constrain the next experiment.",',
    '"description": "Calibrate physical module creation with two positive session splits and one deliberate negative control.",',
    1,
)
text = text.replace(
    '"sources": "docs/research/MODULE_GRANULARITY_AUDIT.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; Loam/Tui/Cli.lean; Loam/Tui/RecordSession.lean",',
    '"sources": "docs/research/MODULE_GRANULARITY_AUDIT.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; Loam/Tui/Cli.lean; Loam/Tui/RecordSession.lean; Loam/Tui/CorrectionSession.lean; Loam/Tui/ActualDateCorrection.lean",',
    1,
)
old_audit = '"audit": "MGA-010 demonstrates that a justified split may increase file count, small-module count, one-consumer count and composition-root fan-out. Those metrics remain useful detectors but are not verdicts. A split graduates only when it isolates a real ownership/effect/change boundary, preserves semantic and authority ownership, and passes focused qualification. Record and Correction are qualified; the next test is whether the much smaller ActualDateCorrection shell deserves a boundary at all.",'
new_audit = '"audit": "MGA-010 and MGA-011 show that justified effect/session boundaries can increase raw module counts while reducing responsibility coupling. MGA-012 supplies the necessary negative control: a logically distinct tiny effect shell can still remain inline when extraction does not materially improve navigation, reuse, ownership, or change independence. The next audit compares the three remaining Scheduled loops by their actual continuation topology rather than by naming symmetry.",'
if old_audit not in text:
    raise SystemExit("stop-rule audit text not found")
text = text.replace(old_audit, new_audit, 1)
old_nodes = '''            ("action", "Observe raw granularity metrics"),
            ("decision", "Metrics worsen after a split?", "NOT A VETO"),
            ("decision", "Independent ownership/effect boundary?", "YES"),
            ("action", "try one narrow extraction"),
            ("action", "qualify Production TUI + Compression + inventory"),
            ("decision", "Boundary stays coherent and navigation improves?", "YES -> graduate"),
            ("action", "Next test: compare INLINE vs SESSION for ActualDateCorrection"),'''
new_nodes = '''            ("action", "Observe semantic ownership + effect topology + history"),
            ("decision", "Logical responsibility is distinct?", "CANDIDATE ONLY"),
            ("decision", "Physical split materially improves navigation / reuse / change independence?", "REQUIRED"),
            ("action", "Record + Correction: split qualified"),
            ("action", "ActualDateCorrection: keep inline"),
            ("decision", "Naming symmetry alone?", "NEVER A SPLIT REASON"),
            ("action", "Next: compare Completion / Cancellation / Replacement topology"),'''
if old_nodes not in text:
    raise SystemExit("stop-rule nodes not found")
text = text.replace(old_nodes, new_nodes, 1)
text = text.replace(
    'LOAM MGA.009-012 - TUI CLI module granularity',
    'LOAM MGA.009-013 - TUI CLI module granularity',
    1,
)
text = text.replace(
    'MGA.009-012 TUI CLI module granularity',
    'MGA.009-013 TUI CLI module granularity',
    1,
)
map_path.write_text(text)
