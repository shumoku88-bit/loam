#!/usr/bin/env python3
"""Build the human-scale LOAM DRAKON system map.

The generated .drn file is an SQLite database understood by DRAKON Editor.
This map is an architecture/navigation artifact, not household-data authority
and not yet a code-generation source.
"""

from pathlib import Path
import sqlite3
import textwrap

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "loam-system-map.drn"

SCHEMA = """
create table diagrams(
  diagram_id integer primary key,
  name text unique,
  origin text,
  description text,
  zoom double
);
create table state(
  row integer primary key,
  current_dia integer,
  description text
);
create table items(
  item_id integer primary key,
  diagram_id integer,
  type text,
  text text,
  selected integer,
  x integer,
  y integer,
  w integer,
  h integer,
  a integer,
  b integer,
  aux_value integer,
  color text,
  format text,
  text2 text
);
create table diagram_info(
  diagram_id integer,
  name text,
  value text,
  primary key(diagram_id, name)
);
create table tree_nodes(
  node_id integer primary key,
  parent integer,
  type text,
  name text,
  diagram_id integer
);
create index items_per_diagram on items(diagram_id);
create unique index node_for_diagram on tree_nodes(diagram_id);
create table info(key text primary key, value text);
"""

SIMPLE_DIAGRAMS = [
    ("00 Overview", [
        "Human Entrances",
        "Commands / Questions",
        "Application",
        "Core Facts",
        "Authority / Persistence",
        "Projections / Answers",
    ], "LOAM at human-scale: interaction -> meaning -> authority -> answer."),
    ("01 Human Entrances", [
        "TUI: Home / Record / Actual / Scheduled / Capacity / Attention / Reports",
        "CLI: movement / review / focused diagnostic entrances",
        "Human-facing surfaces choose a path; they do not own household meaning",
    ], ""),
    ("02 Commands & Questions", [
        "Record Movement",
        "Correct Event / Occurrence Date",
        "Change Routing",
        "Observe Current Quantity",
        "Change Configuration",
        "Ask bounded review / report questions",
    ], ""),
    ("03 Application", [
        "Quantity inspection",
        "Actual validity / routing",
        "Scheduled inspection / commitment / open-world questions",
        "Capacity / consumption",
        "Attention / open relations",
        "Return answer or explicit refusal",
    ], ""),
    ("04 Core Overview", ["Movement", "Meaning", "Time & Truth", "Allocation", "Knowledge"], ""),
    ("04.1 Movement", ["Event", "Effect", "Quantity", "Measure", "Balanced Movement"], ""),
    ("04.2 Meaning", ["Locus admission", "Purpose", "Accounting Role", "Historical Routing"], ""),
    ("04.3 Time & Truth", ["Actual Validity", "Actual Validity History", "Event Correction", "Event Description"], ""),
    ("04.4 Allocation", ["Routing Effective", "Capacity", "Capacity Effective", "Capacity Memory"], ""),
    ("04.5 Knowledge", ["Attention", "Attention Memory", "Open Relation", "Zero-Origin Coverage", "Opening Support"], ""),
    ("05 Evidence & History", ["Event Memory", "Correction Memory", "Validity History", "Capacity Memory", "Attention Memory", "Coverage / Opening Support"], ""),
    ("06 Authority & Persistence", ["Household authority root", "actual.loam", "scheduled.loam", "Decode", "Validate", "Publish", "Configuration"], ""),
    ("07 Projections & Reports", ["Actual Review", "Balances / Accounting Role Balance", "Income & Expense", "Stock-Flow", "Transactions Flow", "Budget Window", "Other answers remain derived views"], ""),
    ("08 Formal Evidence", ["Lean: retained laws / practical Core", "Alloy: structures / counterexamples", "J: arrays / projection / loss / shape", "TLA+: temporal and operation-order questions", "Historical observations: evidence, not production authority"], ""),
]

FLOW_DIAGRAMS = {
    "00 Architecture Audit Gate": {
        "description": "Macro guardrail for every structural refactor before local compression is accepted.",
        "sources": "docs/drakon/ARCHITECTURE_LAWS.md; DESIGN_PHILOSOPHY.md; docs/research/ACCOUNTING_CAPABILITY_AUDIT_CHECKPOINT_2026-09.md; Loam/HouseholdCommand.lean",
        "audit": "Local simplification is accepted only when it does not spend LOAM's multi-Measure, frontend-neutral, authority-preserving, open-world, locale-neutral, additive-extension capabilities.",
        "nodes": [
            ("decision", "Minimal independent evidence preserved?", "Redesign\ndo not retain derivable state or erase needed evidence"),
            ("decision", "Measure separation preserved?", "Redesign\nno implicit cross-Measure arithmetic or valuation"),
            ("decision", "Semantics remain presentation-neutral?", "Move concern outward\nTUI / GUI / AI must not define Core truth"),
            ("decision", "Frontends remain authority-neutral?", "Move authority inward\nno canonical paths / locks / identity in frontend"),
            ("decision", "Independent semantic authorities remain distinct?", "Redesign\nshare mechanics without merging authority"),
            ("decision", "Unknown / incomplete remains explicit?", "Redesign\ndo not collapse uncertainty to zero / empty / false"),
            ("decision", "Writes fail closed and continuity is qualified?", "Redesign\nprotect current authority and operational facts"),
            ("decision", "Derived answers remain projections?", "Redesign\ndo not canonicalize a report convenience"),
            ("decision", "Any new shared primitive earned by independent pressure?", "Keep it local\nrepeated independent use must precede promotion"),
            ("decision", "Future capability preserved without speculative framework?", "Redesign\nkeep room without inventing hypothetical abstraction"),
            ("decision", "Locale-specific policy stays at the edge?", "Move concern outward\nJapan-friendly must not become Japan-bound"),
            ("decision", "Extension is additive rather than semantic distortion?", "Add explicit evidence / policy / adapter\ndo not weaken an existing law"),
            ("action", "MACRO GATE PASSED\ncontinue local proof / tests / review"),
        ],
    },
    "09 Write Path Comparison": {
        "description": "Cross-path comparison before promoting repeated write mechanics inward.",
        "sources": "Loam/MovementPublisher.lean; Loam/CorrectionPublisher.lean; Loam/ScheduledTerminalPublisher.lean; Loam/ActualAuthority.lean; Loam/Persistence/ScheduledLifecyclePersistence.lean",
        "audit": "Repeated shape is evidence to investigate, not proof of one abstraction. Record and Correction share one-Actual publication topology; Scheduled Completion has two authorities and a distinct retry law.",
        "nodes": [
            ("action", "RECORD MOVEMENT\nActual + current Locus policy"),
            ("action", "pure Movement admission\nfresh Event identity"),
            ("action", "publish one complete Actual generation"),
            ("action", "CORRECTION\nActual + current Locus policy"),
            ("action", "correction-specific admission\ncurrent target + replacement Event"),
            ("action", "publish one complete Actual generation"),
            ("action", "SCHEDULED COMPLETION\nScheduled lifecycle + Actual + Locus policy"),
            ("action", "completion-specific admission\nstable completion Event identity"),
            ("action", "publish Scheduled terminal first\nthen publish Actual generation"),
            ("action", "COMMON MECHANICS CANDIDATES\nownership, authoritative reload, typed complete-image publication"),
            ("action", "DO NOT MERGE BY SHAPE\nauthority topology, semantic admission, crash / retry law"),
        ],
    },
    "10.0 Record Movement": {
        "description": "End-to-end production path. Detailed diagrams split collection, pure admission, and atomic publication.",
        "sources": "Loam/Tui/Record.lean; Loam/Tui/Cli.lean; Loam/HouseholdCommand.lean; Loam/MovementPublisher.lean; Loam/MovementAdmission.lean; Loam/ActualAuthority.lean",
        "audit": "Preview may use an earlier world; publication never trusts it. Authoritative evidence is re-read under writer ownership.",
        "nodes": [
            ("insertion", "Collect presentation-neutral draft\nTUI or line CLI"),
            ("action", "Optional preview against loaded world\nobservational only"),
            ("insertion", "Select canonical command path\nHouseholdCommand.record"),
            ("insertion", "MovementPublisher\nacquire Actual writer ownership"),
            ("insertion", "MovementAdmission.admit?\npure semantic transition"),
            ("insertion", "ActualAuthority.publishActual?\nstage, decode, atomic rename"),
            ("action", "Return fresh EventId"),
        ],
    },
    "10.1 TUI Record Session": {
        "description": "Interactive TUI editor and preview. The preview is not publication authority.",
        "sources": "Loam/Tui/Record.lean; Loam/Tui/Cli.lean; Loam/HouseholdCommand.lean",
        "audit": "The editor calls validateDraft and admit? for preview, then HouseholdCommand.record re-enters the publisher which re-reads authority and admits again.",
        "nodes": [
            ("action", "Edit date / description / signed posting rows"),
            ("decision", "Local draft syntax valid?", "Keep editing\nshow validation notice"),
            ("insertion", "Preview with MovementAdmission.admit?\nusing currently loaded world"),
            ("decision", "Preview admitted?", "Keep editing\nshow semantic refusal"),
            ("decision", "User chose Publish?", "Edit or Cancel\nno write"),
            ("insertion", "HouseholdCommand.record\nsurface-neutral command port"),
            ("decision", "Authoritative publication succeeded?", "Return to editor\nshow publisher refusal"),
            ("action", "Report fresh EventId\ncaller reloads canonical evidence"),
        ],
    },
    "10.2 Authoritative Movement Publish": {
        "description": "Production write seam for one already-collected Movement draft.",
        "sources": "Loam/HouseholdCommand.lean; Loam/MovementPublisher.lean; Loam/ActualAuthority.lean; Loam/LocusAdmissionAuthority.lean",
        "audit": "Historical Actual evidence and current Locus new-write policy remain separate authorities. The publisher is presentation-neutral; EventId is returned only after authoritative publication succeeds.",
        "nodes": [
            ("decision", "Data root non-empty?", "Refuse\ninvalid data root"),
            ("insertion", "Acquire writer ownership\nactual.loam writer lock"),
            ("insertion", "Load authoritative ActualEvidence\nfrom actual.loam"),
            ("decision", "Actual authority decoded?", "Refuse\nmissing or malformed Actual"),
            ("insertion", "Load current Locus admission policy\nfrom locus-admission.loam"),
            ("decision", "Locus policy decoded?", "Refuse\nmissing or malformed policy"),
            ("action", "ActualAuthority.movementWorld\nevidence + current policy"),
            ("insertion", "MovementAdmission.admit?\nagainst authoritative world"),
            ("decision", "Draft admitted?", "Refuse\nsemantic admission failed"),
            ("action", "Build updated ActualEvidence\npreserve correction / reversal evidence"),
            ("insertion", "ActualAuthority.publishActual?\ncomplete generation"),
            ("decision", "Atomic publication succeeded?", "Refuse\nexisting authority remains intact"),
            ("action", "Return admitted EventId"),
        ],
    },
    "10.3 Movement Admission": {
        "description": "Pure semantic admission of one Movement draft against one typed world.",
        "sources": "Loam/MovementAdmission.lean; Loam/Core/BalancedMovement.lean; Loam/Application/OpenRelationFrontier.lean; Loam/Application/RelationDischargeFrontier.lean",
        "audit": "Collector-local Effect identity is canonicalized here. Only Relation-referenced EffectKeys earn durable identity; preview and publication share the same draft semantics.",
        "nodes": [
            ("action", "Canonicalize collector-local EffectKeys\nretain only Relation sources"),
            ("insertion", "validateDraft\ncalendar date, tokens, nonzero JPY, balanced totals"),
            ("decision", "Draft valid?", "Refuse\ninvalid practical draft"),
            ("decision", "Every Effect Locus currently admitted?", "Refuse\nLocus not approved for new write"),
            ("action", "Allocate fresh EventId\nand RelationUnit ids"),
            ("decision", "Fresh identities available?", "Refuse\nidentity allocation failed"),
            ("insertion", "Event.ofEffects?\nmaterialize RelationUnits / Discharges"),
            ("decision", "Generated evidence structurally admissible?", "Refuse\nEvent or relation materialization failed"),
            ("action", "Append description, Event,\nbase ActualValidity fact"),
            ("decision", "Append preserves typed memories?", "Refuse\nhistory append failed"),
            ("action", "Extend relations and discharges"),
            ("decision", "Open relation frontier justified?", "Refuse\nsource-local frontier not justified"),
            ("decision", "Discharge target frontier justified?", "Refuse\ncurrent target frontier not justified"),
            ("action", "Return Admitted\nupdated world + EventId"),
        ],
    },
    "10.4 Atomic Actual Publish": {
        "description": "Crash-resilient switch of one complete normalized Actual generation.",
        "sources": "Loam/ActualAuthority.lean; Loam/Persistence/NormalizedActualPersistence.lean; Loam/WriterOwnership.lean",
        "audit": "The authoritative file is untouched until the final rename. Stage bytes are compared and typed-decoded before the switch.",
        "nodes": [
            ("insertion", "Encode complete ActualEvidence"),
            ("decision", "Production encoder accepted evidence?", "Refuse\nno authority change"),
            ("action", "Create parent directory if needed"),
            ("action", "Write actual.loam.loam-stage"),
            ("action", "Read staged bytes back"),
            ("decision", "Staged bytes equal encoded bytes?", "Refuse\nno authority change"),
            ("insertion", "Decode staged file through\nproduction typed decoder"),
            ("decision", "Staged typed decode succeeds?", "Refuse\nno authority change"),
            ("action", "Atomic rename\nstage -> actual.loam"),
            ("action", "Publication complete"),
        ],
    },
    "10.5 Line CLI Record Entrance": {
        "description": "Scriptable Movement entrance sharing the same household command path as the TUI.",
        "sources": "Loam/Cli/MovementCli.lean; Loam/Cli/Movement/Entry.lean; Loam/Cli/Movement/RelationEntry.lean; Loam/Cli/Movement/DischargeEntry.lean; Loam/HouseholdCommand.lean",
        "audit": "The preflight is observational only. Human think time owns no lock. Publication goes through HouseholdCommand.record; CLI rendering happens only after authoritative success.",
        "nodes": [
            ("insertion", "Preflight loadSelectedWorld?\nobservational only"),
            ("decision", "Current world readable?", "Refuse before input"),
            ("action", "Collect occurrence date\nand optional description"),
            ("insertion", "Collect signed Movement Effects\nFROM then TO"),
            ("decision", "Collector produced balanced movement?", "Refuse\ninput incomplete or unbalanced"),
            ("insertion", "Collect optional Relation drafts"),
            ("insertion", "Collect optional Discharge drafts"),
            ("action", "Build MovementAdmission.Draft"),
            ("insertion", "HouseholdCommand.record\nshared household-root write path"),
            ("decision", "Authoritative publication succeeded?", "Print refusal\nexit 2"),
            ("action", "Render admission details and result\nexit 0"),
        ],
    },
    "11.0 Correct Actual": {
        "description": "End-to-end replacement correction of one selected current Actual Event.",
        "sources": "Loam/Tui/Correction.lean; Loam/Tui/Cli.lean; Loam/HouseholdCommand.lean; Loam/CorrectionPublisher.lean; Loam/ActualAuthority.lean",
        "audit": "The original Event stays retained. Correction appends a replacement Event plus explicit EventCorrection and reuses the target's current occurrence date.",
        "nodes": [
            ("action", "Select one visible current Actual"),
            ("insertion", "Seed correction editor\nfrom selected Actual"),
            ("action", "Edit replacement description / postings\ndate remains fixed in this editor"),
            ("action", "Preview replacement using Record mechanics"),
            ("decision", "User chose Publish?", "Edit or Cancel\nno write"),
            ("insertion", "HouseholdCommand.correctActual\nsurface-neutral command port"),
            ("insertion", "CorrectionPublisher\nre-read Actual + Locus policy"),
            ("insertion", "Correction admission\nappend replacement evidence"),
            ("insertion", "ActualAuthority.publishActual?\ncomplete generation"),
            ("action", "Reload canonical Actual view"),
        ],
    },
    "11.1 Authoritative Correction Publish": {
        "description": "Writer-owned publication seam for one correction replacement draft.",
        "sources": "Loam/HouseholdCommand.lean; Loam/CorrectionPublisher.lean; Loam/ActualAuthority.lean; Loam/LocusAdmissionAuthority.lean",
        "audit": "This path shares one-Actual publication mechanics with Record but keeps correction currentness, target restrictions, and replacement identity local.",
        "nodes": [
            ("decision", "Data root non-empty?", "Refuse\ninvalid data root"),
            ("insertion", "Acquire writer ownership\nactual.loam writer lock"),
            ("insertion", "Load authoritative ActualEvidence"),
            ("decision", "Actual authority decoded?", "Refuse\nmissing or malformed Actual"),
            ("insertion", "Load current Locus admission policy"),
            ("decision", "Locus policy decoded?", "Refuse\nmissing or malformed policy"),
            ("insertion", "CorrectionPublisher.admit?\nagainst evidence + current policy"),
            ("decision", "Correction admitted?", "Refuse\ncorrection semantic guard failed"),
            ("insertion", "ActualAuthority.publishActual?\ncomplete generation"),
            ("decision", "Atomic publication succeeded?", "Refuse\nexisting authority remains intact"),
            ("action", "Return success"),
        ],
    },
    "11.2 Correction Admission": {
        "description": "Correction-specific semantic admission before one replacement generation is published.",
        "sources": "Loam/CorrectionPublisher.lean; Loam/Application/ActualValidityFrontier.lean; Loam/Core/BalancedMovement.lean",
        "audit": "Correction is not generic Movement admission: it must prove the target is current and practical, unreferenced by relation/discharge and reversal evidence, then append replacement lineage without rewriting history.",
        "nodes": [
            ("decision", "Replacement is balanced nonzero JPY and tokens persistable?", "Refuse\nreplacement outside practical entrance"),
            ("decision", "Every replacement Locus currently admitted?", "Refuse\nLocus not approved for new write"),
            ("insertion", "Resolve targetCurrent?\nretained and not already corrected"),
            ("decision", "Target is current?", "Refuse\nmissing or superseded target"),
            ("decision", "Target itself is practical balanced JPY?", "Refuse\ntarget outside correction entrance"),
            ("decision", "Relation / discharge evidence ignores target?", "Refuse\nreferenced target not yet qualified"),
            ("decision", "Reversal evidence ignores target?", "Refuse\nreversal participant not yet qualified"),
            ("insertion", "Find target current occurrence date"),
            ("decision", "Current date exists?", "Refuse\nno current occurrence coordinate"),
            ("action", "Allocate fresh replacement EventId"),
            ("decision", "Replacement identity available?", "Refuse\nidentity allocation failed"),
            ("action", "Create EventCorrection\ntarget -> replacement"),
            ("insertion", "Event.ofEffects?\nconstruct replacement Event"),
            ("decision", "Replacement Event structurally valid?", "Refuse\nduplicate retained Effect identity"),
            ("action", "Append Event + Correction + base date\n+ optional description"),
            ("decision", "All typed histories accept append?", "Refuse\nhistory append failed"),
            ("action", "Return complete updated ActualEvidence"),
        ],
    },
    "12.0 Complete Scheduled": {
        "description": "End-to-end realization of one current-open Scheduled occurrence into independent Actual evidence.",
        "sources": "Loam/Tui/ScheduledCompletion.lean; Loam/Tui/Cli.lean; Loam/HouseholdCommand.lean; Loam/ScheduledTerminalPublisher.lean",
        "audit": "Expected Scheduled postings seed the editor but are not Actual truth. Publication re-reads both authorities and binds Scheduled to a separately admitted Actual Event.",
        "nodes": [
            ("action", "Select one visible current-open Scheduled occurrence"),
            ("insertion", "Seed editable Actual form\nfrom expected Scheduled movement"),
            ("action", "Edit Actual date / description / postings"),
            ("action", "Preview candidate Actual using Record mechanics"),
            ("decision", "User chose Publish?", "Edit or Cancel\nno write"),
            ("insertion", "HouseholdCommand.completeScheduled\nsurface-neutral command port"),
            ("insertion", "ScheduledTerminalPublisher\nacquire Scheduled then Actual ownership"),
            ("insertion", "Re-read lifecycle + Actual + Locus policy"),
            ("insertion", "Completion-specific Actual admission"),
            ("action", "Publish Scheduled terminal claim first"),
            ("action", "Publish Actual generation second"),
            ("action", "Reload canonical Scheduled + Actual views"),
        ],
    },
    "12.1 Dual-Authority Completion Publish": {
        "description": "Writer-owned two-authority protocol for fresh or resumed Scheduled completion.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; Loam/ActualAuthority.lean; Loam/Persistence/ScheduledLifecyclePersistence.lean; Loam/WriterOwnership.lean",
        "audit": "Lock order is Scheduled then Actual. Scheduled terminal evidence is published first; if Actual publication fails, the retained terminal remains inert and a later retry reuses the same Actual identity.",
        "nodes": [
            ("decision", "Scheduled path and data root non-empty?", "Refuse\ninvalid authority path"),
            ("insertion", "Acquire Scheduled ownership"),
            ("insertion", "Acquire Actual ownership\nfixed lock order"),
            ("insertion", "Load Scheduled lifecycle image"),
            ("decision", "Lifecycle decoded?", "Refuse\nmissing / malformed Scheduled authority"),
            ("insertion", "Load authoritative ActualEvidence"),
            ("decision", "Actual authority decoded?", "Refuse\nmissing / malformed Actual"),
            ("insertion", "Load current Locus admission policy"),
            ("decision", "Locus policy decoded?", "Refuse\nmissing / malformed policy"),
            ("action", "Construct Movement world\nfrom Actual + current policy"),
            ("insertion", "findOpen?\nresolve current-open Scheduled target"),
            ("decision", "Scheduled target current-open?", "Refuse\nclosed / unknown / conflicting lifecycle"),
            ("action", "Choose Actual identity\nreuse retained endpoint or deterministic completion id"),
            ("decision", "Actual id unoccupied and endpoint ownership consistent?", "Refuse\nalready completed or identity conflict"),
            ("insertion", "appendCompletionActual?\nconstruct candidate Actual world"),
            ("decision", "Candidate Actual admitted?", "Refuse\ncompletion Actual invalid"),
            ("action", "Build ScheduledTerminal\nScheduled -> Actual"),
            ("decision", "Terminal endpoint ownership valid?", "Refuse\none-to-one ownership violated"),
            ("insertion", "Publish complete Scheduled lifecycle image\nonly when terminal is fresh"),
            ("decision", "Lifecycle publication succeeded?", "Refuse\nActual remains untouched"),
            ("insertion", "ActualAuthority.publishActual?\ncomplete Actual generation"),
            ("decision", "Actual publication succeeded?", "Return retryable refusal\nretained terminal remains inert"),
            ("action", "Completion authoritative in both views"),
        ],
    },
    "12.2 Completion Actual Admission": {
        "description": "Construct one plain Actual candidate for a Scheduled completion using an externally chosen stable EventId.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; Loam/MovementAdmission.lean",
        "audit": "This resembles Movement admission but intentionally differs: EventId is chosen by Scheduled completion, Relation/Discharge drafts are refused, and no fresh Event identity is allocated here.",
        "nodes": [
            ("insertion", "MovementAdmission.validateDraft\nvalidate practical Movement draft"),
            ("decision", "Draft valid?", "Refuse\ninvalid practical Movement"),
            ("decision", "Relation / Discharge drafts absent?", "Refuse\ncompletion admits plain effects only"),
            ("decision", "Every Effect Locus currently admitted?", "Refuse\nLocus not approved for new write"),
            ("insertion", "Event.ofEffects?\nuse completion-selected EventId"),
            ("decision", "Completion Event structurally valid?", "Refuse\nEvent construction failed"),
            ("action", "Append Event + base ActualValidity fact"),
            ("decision", "Event / validity append accepted?", "Refuse\nhistory append failed"),
            ("action", "Append optional description"),
            ("decision", "Description memory accepted?", "Refuse\ndescription append failed"),
            ("action", "Preserve existing relations / discharges"),
            ("action", "Return updated Movement world"),
        ],
    },
    "12.3 Interrupted Completion Recovery": {
        "description": "Why Scheduled-first publication remains fail-closed across interruption.",
        "sources": "Loam/ScheduledTerminalPublisher.lean; Loam/Application/ScheduledInspection.lean",
        "audit": "A terminal relation whose Actual target is absent is intentionally inert to Scheduled readers. Retry reuses that target identity; cancellation refuses to compete with an interrupted completion.",
        "nodes": [
            ("decision", "Completion terminal already retained?", "Fresh completion path\ncreate stable endpoint"),
            ("action", "Reuse retained completion Actual EventId"),
            ("decision", "Actual Event already exists?", "Refuse\nalready completed"),
            ("decision", "Retained endpoint belongs to this Scheduled source?", "Refuse\nendpoint ownership conflict"),
            ("action", "Rebuild candidate Actual with same EventId"),
            ("action", "Skip duplicate Scheduled lifecycle publication"),
            ("insertion", "Publish missing Actual generation"),
            ("decision", "Actual publication succeeds?", "Remain retryable\nterminal stays inert"),
            ("action", "Scheduled completion becomes visible as complete"),
        ],
    },
}


def insert_item(db, item_id, diagram_id, kind, text, x, y, w, h, a=0, b=0):
    db.execute(
        "insert into items values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (item_id, diagram_id, kind, text, 0, x, y, w, h, a, b, 0, "", "", ""),
    )


def add_simple_diagram(db, item_id, diagram_id, name, entries, description):
    db.execute("insert into diagrams values (?,?,?,?,?)", (diagram_id, name, "0 0", description, 100.0))
    insert_item(db, item_id, diagram_id, "beginend", name, 360, 60, 150, 24, 60)
    item_id += 1
    if name == "00 Overview":
        end_y = 140 + len(entries) * 70
        insert_item(db, item_id, diagram_id, "vertical", "", 360, 84, 0, end_y - 84)
        item_id += 1
        for index, entry in enumerate(entries):
            insert_item(db, item_id, diagram_id, "action", entry, 360, 140 + index * 70, 220, 26)
            item_id += 1
    else:
        end_y = 370
        insert_item(db, item_id, diagram_id, "vertical", "", 360, 84, 0, end_y - 84)
        item_id += 1
        text = "\n".join(entries)
        insert_item(db, item_id, diagram_id, "action", text, 360, 220, 300, max(40, 18 * len(entries)))
        item_id += 1
    insert_item(db, item_id, diagram_id, "beginend", "End", 360, end_y, 80, 24, 60)
    return item_id + 1


def add_flow_diagram(db, item_id, diagram_id, name, spec):
    db.execute("insert into diagrams values (?,?,?,?,?)",
               (diagram_id, name, "0 0", spec["description"], 90.0))
    for key in ("sources", "audit"):
        db.execute("insert into diagram_info values (?,?,?)", (diagram_id, key, spec[key]))
    db.execute("insert into diagram_info values (?,?,?)",
               (diagram_id, "status", "architecture observation; not yet code-generation source"))

    x = 380
    side_x = 960
    start_y = 60
    first_y = 150
    gap = 105
    nodes = spec["nodes"]
    end_y = first_y + len(nodes) * gap + 30

    insert_item(db, item_id, diagram_id, "beginend", name, x, start_y, 170, 24, 60)
    item_id += 1
    insert_item(db, item_id, diagram_id, "vertical", "", x, start_y + 24, 0, end_y - (start_y + 24))
    item_id += 1

    wrapped_audit = textwrap.wrap(spec["audit"], width=56)
    audit_text = "AUDIT NOTE\n" + "\n".join(wrapped_audit)
    audit_h = max(58, 11 * (len(wrapped_audit) + 1))
    insert_item(db, item_id, diagram_id, "commentout",
                audit_text, 1210, 100, 250, audit_h, 20, 0)
    item_id += 1

    for index, node in enumerate(nodes):
        y = first_y + index * gap
        kind = node[0]
        if kind in ("action", "insertion"):
            text = node[1]
            width = 255 if len(text) > 55 else 220
            height = 38 if "\n" in text else 30
            insert_item(db, item_id, diagram_id, kind, text, x, y, width, height)
            item_id += 1
        elif kind == "decision":
            question, failure = node[1], node[2]
            w = 180 if len(question) > 34 else 145
            h = 30
            a = side_x - (x + w)
            insert_item(db, item_id, diagram_id, "if", question, x, y, w, h, a, 1)
            item_id += 1
            fail_end_y = y + 72
            insert_item(db, item_id, diagram_id, "vertical", "", side_x, y, 0, fail_end_y - y - 24)
            item_id += 1
            insert_item(db, item_id, diagram_id, "beginend", failure, side_x, fail_end_y, 190, 30, 60)
            item_id += 1
        else:
            raise ValueError(f"unknown node kind: {kind}")

    insert_item(db, item_id, diagram_id, "beginend", "End", x, end_y, 80, 24, 60)
    return item_id + 1


def add_tree_node(db, node_id, parent, kind, name="", diagram_id=None):
    db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, parent, kind, name, diagram_id))
    return node_id + 1


def add_flow_folder(db, node_id, parent, folder_name, prefix, diagram_ids):
    folder = node_id
    node_id = add_tree_node(db, node_id, parent, "folder", folder_name)
    for name in FLOW_DIAGRAMS:
        if name.startswith(prefix):
            node_id = add_tree_node(db, node_id, folder, "item", diagram_id=diagram_ids[name])
    return node_id


def build():
    if OUTPUT.exists():
        OUTPUT.unlink()

    all_names = [name for name, _, _ in SIMPLE_DIAGRAMS] + list(FLOW_DIAGRAMS)
    diagram_ids = {name: idx for idx, name in enumerate(all_names, 1)}

    with sqlite3.connect(OUTPUT) as db:
        db.executescript(SCHEMA)
        db.executemany(
            "insert into info values (?,?)",
            [("type", "drakon"), ("version", "2"), ("start_version", "1"), ("language", "SPARK")],
        )
        db.execute("insert into state values (1,1,?)",
                   ("LOAM System Map v0.5 — macro gate + cross-path write atlas",))

        item_id = 1
        for name, entries, description in SIMPLE_DIAGRAMS:
            item_id = add_simple_diagram(db, item_id, diagram_ids[name], name, entries, description)
        for name, spec in FLOW_DIAGRAMS.items():
            item_id = add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = add_tree_node(db, node_id, 0, "folder", "LOAM System Map")

        node_id = add_tree_node(db, node_id, root, "item",
                                diagram_id=diagram_ids["00 Architecture Audit Gate"])
        node_id = add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids["00 Overview"])
        for name in ["01 Human Entrances", "02 Commands & Questions", "03 Application"]:
            node_id = add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        core_folder = node_id
        node_id = add_tree_node(db, node_id, root, "folder", "04 Core Facts")
        for name in ["04 Core Overview", "04.1 Movement", "04.2 Meaning",
                     "04.3 Time & Truth", "04.4 Allocation", "04.5 Knowledge"]:
            node_id = add_tree_node(db, node_id, core_folder, "item", diagram_id=diagram_ids[name])

        for name in ["05 Evidence & History", "06 Authority & Persistence",
                     "07 Projections & Reports", "08 Formal Evidence"]:
            node_id = add_tree_node(db, node_id, root, "item", diagram_id=diagram_ids[name])

        atlas_folder = node_id
        node_id = add_tree_node(db, node_id, root, "folder", "09 Write Path Atlas")
        node_id = add_tree_node(db, node_id, atlas_folder, "item",
                                diagram_id=diagram_ids["09 Write Path Comparison"])
        node_id = add_flow_folder(db, node_id, atlas_folder, "10 Record Movement", "10.", diagram_ids)
        node_id = add_flow_folder(db, node_id, atlas_folder, "11 Correct Actual", "11.", diagram_ids)
        node_id = add_flow_folder(db, node_id, atlas_folder, "12 Complete Scheduled", "12.", diagram_ids)

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")
        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")

        if db.execute("select count(*) from diagrams").fetchone()[0] != len(all_names):
            raise SystemExit("diagram count mismatch")
        if db.execute("select count(*) from items where type='if'").fetchone()[0] < 45:
            raise SystemExit("expected detailed decision icons")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(FLOW_DIAGRAMS):
            raise SystemExit("missing source traceability metadata")
        if db.execute(
            "select count(*) from tree_nodes where type='folder' and name in "
            "('10 Record Movement','11 Correct Actual','12 Complete Scheduled')"
        ).fetchone()[0] != 3:
            raise SystemExit("write-path atlas folder mismatch")

    print(OUTPUT)


if __name__ == "__main__":
    build()
