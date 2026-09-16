#!/usr/bin/env python3
from pathlib import Path

LEDGER = Path("docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md")
MAP = Path("docs/drakon/build_tui_cli_granularity_audit_map.py")

ledger = LEDGER.read_text()
ledger = ledger.replace(
    "Status: **MGA-012 CLOSED — ActualDateCorrection terminal loop stays inline; physical Session symmetry rejected**",
    "Status: **MGA-013 COMPLETE — Scheduled loops classified individually; Replacement selected for one narrow split experiment**",
)

marker = "## MGA-013 — remaining Scheduled local-loop topology\n"
if marker not in ledger:
    raise SystemExit("MGA-013 ledger marker missing")
ledger = ledger[: ledger.index(marker)] + '''## MGA-013 — remaining Scheduled local-loop topology

Classification: **MIXED VERDICT — NO BATCH EXTRACTION**

Three local Scheduled editor/effect loops remain in `Tui.Cli`, but DRAKON and
history do not support treating them as one naming family.

### ScheduledCompletion

Classification: **SPLIT_CANDIDATE — focused experiment justified**

The completion shell is stronger than the rejected ActualDateCorrection split:

- the same local loop is entered from both HRA Scheduled and SelectedDay;
- it carries reusable `world` and `known` catalog context;
- publication refusal returns to the same editor and redraws, matching the
  already-qualified Record/Correction session shape;
- the loop returns only a Boolean completion result, while continuation creation
  and routing inheritance deliberately remain in the caller;
- `ScheduledCompletion.lean` has changed independently after its introduction,
  including shared Record-shaped field rendering (#642) and catalog candidate
  projection cleanup (#646).

A physical session boundary is therefore plausible, but completion has an extra
continuation contract. It should not be the first Scheduled extraction while a
simpler positive control exists.

### ScheduledCancellation

Classification: **KEEP_INLINE / SPLIT_REJECTED**

Cancellation is the negative control inside the Scheduled family:

- it is a compact confirmation-only interaction with no editable household
  payload and no world/catalog context;
- publisher refusal exits immediately as a human-facing notice instead of
  returning to an editor retry loop;
- its presentation module has only the original #524 history so far, with no
  observed independent change pressure;
- although both HRA Scheduled and SelectedDay reuse the local loop, moving this
  tiny shell to another file removes little navigation burden from either caller.

Two callers are therefore useful candidate evidence, not an automatic split
reason. Cancellation stays inline.

### ScheduledReplacement

Classification: **SPLIT_CANDIDATE — SELECTED FOR MGA-014 IMPLEMENTATION EXPERIMENT**

Replacement is the cleanest next experiment:

- the same terminal shell is entered from both HRA Scheduled and SelectedDay;
- `ScheduledReplacement` owns a substantial presentation-only editor with date,
  posting rows, validation, preview, and publication-intent construction;
- the local shell owns key reads, dirty redraws, delegation to
  `HouseholdCommand.replaceScheduled`, and retry after publication refusal;
- the caller still owns selected-record lookup, initial editor construction,
  canonical reload, and destination refresh;
- the editor has independent history after introduction, including validity
  dependency narrowing (#710) and canonical `BalancedMovement` draft migration
  (#767).

This is materially closer to the already-qualified Correction session seam than
to the rejected ActualDateCorrection shell. MGA-014 should therefore extract only
`ScheduledReplacementSession`, then re-run Production TUI, Compression Audit,
module inventory, and the relevant Scheduled tests before deciding whether the
boundary graduates.

### MGA-013 stop rule

The Scheduled family now gives three different outcomes from superficially
similar local loops:

```text
Completion    -> SPLIT_CANDIDATE, defer until continuation seam is tested
Cancellation  -> KEEP_INLINE / SPLIT_REJECTED
Replacement   -> SPLIT_CANDIDATE, next narrow implementation experiment
```

This is the intended result of the granularity audit. Physical modules follow
ownership, reuse, continuation topology, navigation cost, and observed change
reasons. They do not follow suffix symmetry.
'''
LEDGER.write_text(ledger)

text = MAP.read_text()
text = text.replace(
    "but key grammars, snapshot/config loading, four local editor loops, Home/Actual/Scheduled/SelectedDay orchestration",
    "but key grammars, snapshot/config loading, one intentionally-inline date loop plus three local Scheduled loops, Home/Actual/Scheduled/SelectedDay orchestration",
)
text = text.replace(
    "run remaining local editor loops\\nDate / Completion / Cancellation / Replacement",
    "run remaining local editor loops\\nDate (KEEP_INLINE) / Completion / Cancellation / Replacement",
)

if '"MGA.013.1 Scheduled Loop Shape Comparison"' not in text:
    insertion = r'''
    "MGA.013.1 Scheduled Loop Shape Comparison": {
        "description": "Compare Completion, Cancellation, and Replacement by continuation and retry topology instead of by Scheduled naming symmetry.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledCompletion.lean; Loam/Tui/ScheduledCancellation.lean; Loam/Tui/ScheduledReplacement.lean; docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md",
        "audit": "The three Scheduled local loops are not one physical family. Completion and Replacement both have reusable editor/effect shells entered from HRA Scheduled and SelectedDay, while Cancellation is a tiny confirmation that exits on refusal. Completion additionally returns a Boolean into caller-owned continuation creation and routing inheritance. MGA-013 therefore rejects batch extraction and classifies each shape separately.",
        "nodes": [
            ("action", "three local Scheduled terminal loops in Tui.Cli"),
            ("decision", "retry editor after publication refusal?", "Completion + Replacement: YES / Cancellation: NO"),
            ("decision", "reused from HRA Scheduled + SelectedDay?", "YES - all three"),
            ("decision", "caller has post-publication continuation semantics?", "Completion: YES"),
            ("action", "Completion -> SPLIT_CANDIDATE, defer"),
            ("action", "Cancellation -> KEEP_INLINE / SPLIT_REJECTED"),
            ("action", "Replacement -> SPLIT_CANDIDATE / MGA-014"),
        ],
    },
    "MGA.013.2 Scheduled Cancellation Negative Control": {
        "description": "Keep the tiny confirmation shell inline even though two workspaces reuse it.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledCancellation.lean; PR #524",
        "audit": "ScheduledCancellation owns only presentation evidence for an explicit protective confirmation. The terminal loop has no reusable world/catalog context and no retry state: a publisher refusal immediately becomes a notice and fresh canonical evidence is loaded by the caller. The presentation module has only its original #524 history. Moving this tiny shell to another file would mostly add a physical module without removing meaningful workflow navigation, so MGA-013 keeps it inline.",
        "nodes": [
            ("action", "ScheduledCancellation.State / Step / view"),
            ("action", "tiny local confirmation loop"),
            ("decision", "publish target-only cancellation?", "YES"),
            ("insertion", "HouseholdCommand.cancelScheduled"),
            ("decision", "refusal returns to editor retry?", "NO - return notice"),
            ("action", "caller reloads canonical evidence"),
            ("decision", "physical Session materially improves navigation?", "NO"),
            ("action", "KEEP_INLINE / SPLIT_REJECTED"),
        ],
    },
    "MGA.013.3 Scheduled Replacement Candidate": {
        "description": "Select Replacement as the next narrow implementation experiment without pre-judging qualification.",
        "sources": "Loam/Tui/Cli.lean; Loam/Tui/ScheduledReplacement.lean; Loam/HouseholdCommand.lean; PR #710; PR #767",
        "audit": "ScheduledReplacement owns a substantial presentation-only editor, while the local Tui.Cli shell owns terminal reads, dirty redraws, HouseholdCommand.replaceScheduled delegation and retry after refusal. The same shell is entered from HRA Scheduled and SelectedDay. Its editor has independent change history after introduction, including dependency narrowing and BalancedMovement migration. This is materially closer to the qualified Correction session seam than to ActualDateCorrection, so MGA-014 will try one narrow ScheduledReplacementSession extraction and qualify it before any further split.",
        "nodes": [
            ("action", "ScheduledReplacement.State / validation / preview / view"),
            ("action", "shared local terminal/effect loop in Tui.Cli"),
            ("action", "read key + update + dirty redraw"),
            ("decision", "Step publishes draft?", "YES"),
            ("insertion", "HouseholdCommand.replaceScheduled"),
            ("decision", "publication refused?", "YES -> same editor retry"),
            ("action", "callers retain selection + canonical reload + destination refresh"),
            ("decision", "narrow extraction worth testing?", "YES -> MGA-014"),
        ],
    },
'''
    anchor = "\n}\n\n\ndef build() -> None:"
    if anchor not in text:
        raise SystemExit("DRAKON map insertion anchor missing")
    text = text.replace(anchor, insertion + "\n}\n\n\ndef build() -> None:", 1)
MAP.write_text(text)
