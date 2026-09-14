#!/usr/bin/env python3
"""Build the human-scale LOAM DRAKON system map.

The generated .drn file is an SQLite database understood by DRAKON Editor.
This map is an architecture/navigation artifact, not household-data authority
and not yet a code-generation source.
"""

from pathlib import Path
import sqlite3

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
    ("06 Authority & Persistence", ["Household authority root", "actual.loam", "Decode", "Validate", "Publish", "Configuration"], ""),
    ("07 Projections & Reports", ["Actual Review", "Balances / Accounting Role Balance", "Income & Expense", "Stock-Flow", "Transactions Flow", "Budget Window", "Other answers remain derived views"], ""),
    ("08 Formal Evidence", ["Lean: retained laws / practical Core", "Alloy: structures / counterexamples", "J: arrays / projection / loss / shape", "TLA+: temporal and operation-order questions", "Historical observations: evidence, not production authority"], ""),
]

FLOW_DIAGRAMS = {
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
        "audit": "Historical Actual evidence and current Locus new-write policy remain separate authorities. The lock covers re-read through atomic publication, not human think time.",
        "nodes": [
            ("decision", "Data root non-empty?", "Refuse\ninvalid data root"),
            ("insertion", "Acquire writer ownership\nactual.loam writer lock"),
            ("insertion", "Load authoritative ActualEvidence\nfrom actual.loam"),
            ("decision", "Actual authority decoded?", "Refuse\nmissing or malformed Actual"),
            ("insertion", "Load current Locus admission policy\nfrom locus-admission.loam"),
            ("decision", "Locus policy decoded?", "Refuse\nmissing or malformed policy"),
            ("action", "Construct MovementAdmission.World\nfrom evidence + current policy"),
            ("action", "Drop temporary EffectKeys\nunless a Relation references them"),
            ("insertion", "MovementAdmission.admit?\nagainst authoritative world"),
            ("decision", "Draft admitted?", "Refuse\nsemantic admission failed"),
            ("action", "Optional beforePublish callback\nsurface observes admitted EventId"),
            ("action", "Build updated ActualEvidence\npreserve correction / reversal evidence"),
            ("insertion", "ActualAuthority.publishActual?\ncomplete generation"),
            ("decision", "Atomic publication succeeded?", "Refuse\nexisting authority remains intact"),
            ("action", "Return admitted EventId"),
        ],
    },
    "10.3 Movement Admission": {
        "description": "Pure semantic admission of one Movement draft against one typed world.",
        "sources": "Loam/MovementAdmission.lean; Loam/Core/BalancedMovement.lean; Loam/Application/OpenRelationFrontier.lean; Loam/Application/RelationDischargeFrontier.lean",
        "audit": "Balanced JPY is an entrance contract, not a global Event law. Identity allocation and relation/discharge currentness live here, not in UI or persistence.",
        "nodes": [
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
            ("action", "Return Admitted\nupdated world + Event + new relation evidence"),
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
        "description": "Explicit low-level line CLI. It intentionally calls MovementPublisher directly.",
        "sources": "Loam/Cli/MovementCli.lean; Loam/Cli/Movement/Entry.lean; Loam/Cli/Movement/RelationEntry.lean; Loam/Cli/Movement/DischargeEntry.lean; Loam/MovementPublisher.lean",
        "audit": "The preflight is observational only. After human think time, MovementPublisher re-reads authoritative state under lock. Direct publisher use is an explicit low-level-CLI policy exception to HouseholdCommand.",
        "nodes": [
            ("insertion", "Preflight loadSelectedWorld?\nobservational only"),
            ("decision", "Current world readable?", "Refuse before input"),
            ("action", "Collect occurrence date\nand optional description"),
            ("insertion", "Collect signed Movement Effects\nFROM then TO"),
            ("decision", "Collector produced balanced movement?", "Refuse\ninput incomplete or unbalanced"),
            ("insertion", "Collect optional Relation drafts"),
            ("insertion", "Collect optional Discharge drafts"),
            ("action", "Build MovementAdmission.Draft"),
            ("insertion", "MovementPublisher.publishDraftWithPreview\nDIRECT low-level CLI path"),
            ("decision", "Authoritative publication succeeded?", "Print refusal\nexit 2"),
            ("action", "Print recorded movement\nexit 0"),
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

    insert_item(db, item_id, diagram_id, "commentout",
                "AUDIT NOTE\n" + spec["audit"], 1210, 90, 220, 58, 20, 0)
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
            insert_item(db, item_id, diagram_id, "beginend", failure, side_x, fail_end_y, 170, 24, 60)
            item_id += 1
        else:
            raise ValueError(f"unknown node kind: {kind}")

    insert_item(db, item_id, diagram_id, "beginend", "End", x, end_y, 80, 24, 60)
    return item_id + 1


def add_tree_node(db, node_id, parent, kind, name="", diagram_id=None):
    db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, parent, kind, name, diagram_id))
    return node_id + 1


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
                   ("LOAM System Map v0.2 — architecture observation + Record Movement write path",))

        item_id = 1
        for name, entries, description in SIMPLE_DIAGRAMS:
            item_id = add_simple_diagram(
                db, item_id, diagram_ids[name], name, entries, description
            )
        for name, spec in FLOW_DIAGRAMS.items():
            item_id = add_flow_diagram(db, item_id, diagram_ids[name], name, spec)

        node_id = 1
        root = node_id
        node_id = add_tree_node(db, node_id, 0, "folder", "LOAM System Map")

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

        write_folder = node_id
        node_id = add_tree_node(db, node_id, root, "folder", "10 Write Path")
        movement_folder = node_id
        node_id = add_tree_node(db, node_id, write_folder, "folder", "Record Movement")
        for name in FLOW_DIAGRAMS:
            node_id = add_tree_node(db, node_id, movement_folder, "item",
                                    diagram_id=diagram_ids[name])

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")
        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")

        if db.execute("select count(*) from diagrams").fetchone()[0] != len(all_names):
            raise SystemExit("diagram count mismatch")
        if db.execute("select count(*) from items where type='if'").fetchone()[0] < 10:
            raise SystemExit("expected detailed decision icons")
        if db.execute("select count(*) from diagram_info where name='sources'").fetchone()[0] != len(FLOW_DIAGRAMS):
            raise SystemExit("missing source traceability metadata")

    print(OUTPUT)


if __name__ == "__main__":
    build()
