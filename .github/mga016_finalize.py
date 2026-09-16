#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import sqlite3
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run_inventory() -> tuple[dict[str, str], dict[str, dict[str, str]], str]:
    tsv = Path('/tmp/loam-mga016.tsv')
    dot = Path('/tmp/loam-mga016.dot')
    md = Path('/tmp/loam-mga016.md')
    proc = subprocess.run(
        [
            'python3', 'tools/module_granularity_audit.py',
            '--history', '200',
            '--tsv', str(tsv),
            '--dot', str(dot),
            '--markdown', str(md),
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    print(proc.stdout, end='')
    summary: dict[str, str] = {}
    patterns = {
        'modules': r'Lean modules: (\d+)',
        'small': r'Modules <= 80 lines: (\d+)',
        'one_consumer': r'Modules with exactly one local consumer: (\d+)',
        'roots': r'Declared Lake roots: (\d+)',
        'unreachable': r'Production-like modules unreachable from declared roots: (\d+)',
    }
    for key, pattern in patterns.items():
        match = re.search(pattern, proc.stdout)
        if not match:
            raise SystemExit(f'missing inventory summary: {key}')
        summary[key] = match.group(1)

    rows: dict[str, dict[str, str]] = {}
    with tsv.open(newline='') as handle:
        for row in csv.DictReader(handle, delimiter='\t'):
            rows[row['module']] = row
    return summary, rows, md.read_text()


def metric(row: dict[str, str], *, fan_in: bool = True) -> str:
    parts = [f"{row['lines']} lines", f"{row['declarations']} declarations"]
    if fan_in:
        parts.append(f"fan-in {row['fan_in']}")
    parts.append(f"fan-out {row['fan_out']}")
    parts.append(f"reachable={row['reachable_from_declared_root']}")
    return ' / '.join(parts)


def update_ledger(summary: dict[str, str], rows: dict[str, dict[str, str]]) -> None:
    path = ROOT / 'docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md'
    text = path.read_text()
    text = text.replace(
        'Status: **MGA-015 COMPLETE — ScheduledCompletionSession KEEP_BOUNDARY / SPLIT_QUALIFIED; PR #974 ready for merge**',
        'Status: **MGA-016 COMPLETE — ScheduledContinuationSession KEEP_BOUNDARY / SPLIT_QUALIFIED; PR #977 ready for merge**',
        1,
    )

    cli = rows['Loam.Tui.Cli']
    continuation = rows['Loam.Tui.ScheduledContinuationSession']
    record = rows['Loam.Tui.RecordSession']
    correction = rows['Loam.Tui.CorrectionSession']
    replacement = rows['Loam.Tui.ScheduledReplacementSession']
    completion = rows['Loam.Tui.ScheduledCompletionSession']

    start = text.index('## Refreshed inventory\n')
    end = text.index('## MGA-001', start)
    refreshed = f'''## Refreshed inventory

The module-granularity inventory was rerun on the PR #977 merge candidate after extracting
`Loam.Tui.ScheduledContinuationSession`.

```text
Lean modules: {summary['modules']}
Modules <= 80 lines: {summary['small']}
Modules with exactly one local consumer: {summary['one_consumer']}
Declared Lake roots: {summary['roots']}
Production-like modules unreachable from declared roots: {summary['unreachable']}
```

MGA-016 adds one explicit TUI coordinator while removing two duplicated continuation corridors
from the composition root. The refreshed focused metrics are:

```text
Loam.Tui.Cli                          {metric(cli, fan_in=False)}
Loam.Tui.RecordSession                {metric(record)}
Loam.Tui.CorrectionSession            {metric(correction)}
Loam.Tui.ScheduledReplacementSession  {metric(replacement)}
Loam.Tui.ScheduledCompletionSession   {metric(completion)}
Loam.Tui.ScheduledContinuationSession {metric(continuation)}
```

MGA-015 left `Tui.Cli` at 1116 lines / 30 declarations / fan-out 57. MGA-016 therefore
removes duplicated post-completion orchestration from the root while adding one explicit
Session dependency. Raw module count, small-module count, and one-consumer count remain
candidate signals rather than verdicts; the decisive evidence is the shared two-caller
workflow, independent semantic authorities, derived-state removal, history, and reachability.

The qualified Scheduled dependency seam is now:

```text
Tui.Cli
  -> ScheduledCompletionSession       -> ScheduledCompletion + HouseholdCommand
  -> ScheduledContinuationSession
       -> ScheduledCreation + ScheduledCreationSession
       -> HouseholdCommand.inheritScheduledRouting
  -> canonical reload + HraScheduled/SelectedDay refresh
```

'''
    text = text[:start] + refreshed + text[end:]

    if '## MGA-016 — `Loam.Tui.ScheduledContinuationSession`' not in text:
        text += f'''

## MGA-016 — `Loam.Tui.ScheduledContinuationSession` post-completion coordinator

Classification: **KEEP_BOUNDARY / SPLIT_QUALIFIED — PR #977 ready for merge**

MGA-016 followed the explicit stop rule recorded by MGA-015: completion publication remains
behind `ScheduledCompletionSession`'s Boolean result, and only the workflow on the far side of
that result was reconsidered.

DRAKONview, the dedicated obligation DAG, source inspection, and history found one repeated
post-completion corridor in both HRA Scheduled and SelectedDay:

```text
seed optional next Scheduled
-> acquire display catalog
-> run ScheduledCreationSession
-> if created, inherit predecessor routing
-> compose final notice
```

The extraction is justified by more than textual duplication:

- PR #712 had already promoted routing semantics into presentation-neutral
  `ScheduledContinuationRouting`, yet both TUI callers then required the same parallel adaptation;
- PR #796 later changed that routing boundary independently of TUI workspace ownership;
- MGA-015 qualified completion as a separate effect session with a Boolean stop line;
- the old callers re-encoded one derived state by checking the literal
  `"Scheduled creation cancelled."` after `runWithScheduledId` had already returned `none`;
  the creation session returns `none` only on cancellation, so that string branch was not an
  independent semantic distinction.

`ScheduledContinuationSession.runAfterCompletion` now owns only the common continuation
composition. It deliberately does not own completion publication, Locus-catalog loading policy,
routing semantics/authority, canonical reload, or destination-workspace refresh. The caller
passes catalog acquisition as a lazy `IO Catalog`, preserving the old effect order: catalog I/O
still occurs only after `initialFromScheduled?` can seed the editor.

Refreshed inventory evidence:

```text
ScheduledContinuationSession: {metric(continuation)}
Tui.Cli: {metric(cli, fan_in=False)}
production-like unreachable: {summary['unreachable']}
```

Initial production qualification on the implementation + obligation-DAG head succeeded:

- Production TUI #820 — SUCCESS, all 62 production steps;
- Compression Audit #958 — SUCCESS;
- Selected Lean Observations #1204 — SUCCESS;
- Purpose Catalog Boundary #341 — SUCCESS.

The result is therefore **KEEP_BOUNDARY / SPLIT_QUALIFIED**. Canonical reload and the
`HraScheduled.refreshed` / `SelectedDay.refreshed` fork are the next explicit stop line. They
remain caller-owned and are not candidates merely because the preceding corridor is now shared.
'''
    path.write_text(text)


def update_drakon(summary: dict[str, str], rows: dict[str, dict[str, str]]) -> None:
    path = ROOT / 'docs/drakon/build_tui_scheduled_session_audit_map.py'
    text = path.read_text()
    name = 'MGA.016.1 Qualified Scheduled Continuation Coordinator'
    continuation = rows['Loam.Tui.ScheduledContinuationSession']
    cli = rows['Loam.Tui.Cli']
    if name not in text:
        insertion = f'''    "{name}": {{
        "description": "Record the shared post-completion continuation coordinator after two-caller, history, DAG, production, and reachability evidence converge.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledContinuationSession.lean; Loam/Tui/ScheduledCreation.lean; Loam/Tui/ScheduledCreationSession.lean; Loam/HouseholdCommand.lean; Loam/ScheduledContinuationRouting.lean; docs/research/SCHEDULED_CONTINUATION_SESSION_OBLIGATION_DAG.md; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md; PR #712; PR #796; PR #974; PR #977",
        "audit": "MGA-016 starts beyond MGA-015's Boolean completion stop line. HraScheduled and SelectedDay duplicated the same next-editor -> creation-session -> optional routing-inheritance -> notice corridor, and PR #712 provides historical parallel co-change evidence. The old none branch also re-tested a cancellation string even though runWithScheduledId returns none only on cancellation. ScheduledContinuationSession now owns only that common TUI composition; completion publication, catalog policy, routing semantics, canonical reload and workspace refresh remain outside it. Initial PR #977 qualification passed Production TUI #820 62/62, Compression Audit #958, Selected Lean Observations #1204 and Purpose Catalog Boundary #341. Inventory reports {continuation['lines']} lines / fan-in {continuation['fan_in']} / fan-out {continuation['fan_out']} / reachable={continuation['reachable_from_declared_root']}; Tui.Cli is {cli['lines']} lines / {cli['declarations']} declarations / fan-out {cli['fan_out']}; production-like unreachable={summary['unreachable']}.",
        "nodes": [
            ("action", "ScheduledCompletionSession returns Bool stop line"),
            ("decision", "completion published?", "NO -> caller cancellation notice"),
            ("insertion", "ScheduledContinuationSession.runAfterCompletion"),
            ("decision", "next editor seed representable?", "NO -> completion + unavailable notice"),
            ("action", "execute caller-owned lazy Locus catalog action"),
            ("insertion", "ScheduledCreationSession.runWithScheduledId"),
            ("decision", "continuation created?", "NO -> completion + no-next notice"),
            ("insertion", "HouseholdCommand.inheritScheduledRouting"),
            ("action", "format creation + routing outcomes"),
            ("action", "return final notice to caller"),
            ("action", "caller retains canonical reload + workspace-specific refresh"),
            ("decision", "Independent coordinator boundary qualified?", "YES - KEEP_BOUNDARY / SPLIT_QUALIFIED"),
        ],
    }},
'''
        marker = '}\n\n\ndef build() -> None:'
        if text.count(marker) != 1:
            raise SystemExit('unexpected Scheduled DRAKON builder shape')
        text = text.replace(marker, insertion + marker, 1)
    text = text.replace('post-MGA-014 Scheduled TUI session/continuation audit map',
                        'post-MGA-014 Scheduled TUI session/continuation audit map')
    text = text.replace('LOAM MGA.014-015 - Scheduled session and continuation seams',
                        'LOAM MGA.014-016 - Scheduled session and continuation seams')
    text = text.replace('MGA.014-015 Scheduled session seams',
                        'MGA.014-016 Scheduled session seams')
    path.write_text(text)


def update_permanent_ci() -> None:
    path = ROOT / '.github/workflows/module-granularity-audit.yml'
    text = path.read_text()
    text = text.replace(
        '              assert diagram_count == 3\n'
        '              assert source_count == diagram_count\n'
        '              assert db.execute("select count(*) from diagrams where name=\'MGA.015.2 Qualified Scheduled Completion Session Seam\'").fetchone()[0] == 1\n',
        '              assert diagram_count >= 4\n'
        '              assert source_count == diagram_count\n'
        '              assert db.execute("select count(*) from diagrams where name=\'MGA.015.2 Qualified Scheduled Completion Session Seam\'").fetchone()[0] == 1\n'
        '              assert db.execute("select count(*) from diagrams where name=\'MGA.016.1 Qualified Scheduled Continuation Coordinator\'").fetchone()[0] == 1\n',
        1,
    )
    path.write_text(text)


def build_and_verify_drakon() -> None:
    subprocess.run(['python3', 'docs/drakon/build_tui_scheduled_session_audit_map.py'], cwd=ROOT, check=True)
    path = ROOT / 'docs/drakon/loam-tui-scheduled-session-audit.drn'
    with sqlite3.connect(path) as db:
        assert db.execute('pragma integrity_check').fetchone()[0] == 'ok'
        diagrams = db.execute('select count(*) from diagrams').fetchone()[0]
        sources = db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0]
        assert diagrams >= 4
        assert sources == diagrams
        assert db.execute(
            "select count(*) from diagrams where name='MGA.016.1 Qualified Scheduled Continuation Coordinator'"
        ).fetchone()[0] == 1
    print(f'Scheduled-session DRAKON diagrams: {diagrams}; sources: {sources}; integrity: ok')


def main() -> None:
    summary, rows, _ = run_inventory()
    for required in [
        'Loam.Tui.Cli',
        'Loam.Tui.RecordSession',
        'Loam.Tui.CorrectionSession',
        'Loam.Tui.ScheduledReplacementSession',
        'Loam.Tui.ScheduledCompletionSession',
        'Loam.Tui.ScheduledContinuationSession',
    ]:
        if required not in rows:
            raise SystemExit(f'missing focused inventory row: {required}')
    continuation = rows['Loam.Tui.ScheduledContinuationSession']
    if continuation['reachable_from_declared_root'] != 'True':
        raise SystemExit('ScheduledContinuationSession is not reachable')
    if continuation['sole_consumer'] != 'Loam.Tui.Cli':
        raise SystemExit(f"unexpected continuation sole consumer: {continuation['sole_consumer']}")
    if summary['unreachable'] != '0':
        raise SystemExit('production-like unreachable modules are nonzero')

    update_ledger(summary, rows)
    update_drakon(summary, rows)
    update_permanent_ci()
    build_and_verify_drakon()


if __name__ == '__main__':
    main()
