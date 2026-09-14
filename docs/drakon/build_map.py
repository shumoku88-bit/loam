#!/usr/bin/env python3
"""Build the human-scale LOAM DRAKON system map.

The generated .drn file is an SQLite database understood by DRAKON Editor.
This map is a navigation/design artifact, not a household-data authority.
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

DIAGRAMS = [
    ("00 Overview", [
        "Human Entrances",
        "Commands / Questions",
        "Application",
        "Core Facts",
        "Authority / Persistence",
        "Projections / Answers",
    ], "LOAM at human-scale: one path from interaction to retained facts and derived answers."),
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


def insert_item(db, item_id, diagram_id, kind, text, x, y, w, h, a=0, b=0):
    db.execute(
        "insert into items values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (item_id, diagram_id, kind, text, 0, x, y, w, h, a, b, 0, "", "", ""),
    )


def build():
    if OUTPUT.exists():
        OUTPUT.unlink()

    with sqlite3.connect(OUTPUT) as db:
        db.executescript(SCHEMA)
        db.executemany(
            "insert into info values (?,?)",
            [("type", "drakon"), ("version", "2"), ("start_version", "1"), ("language", "SPARK")],
        )
        db.execute("insert into state values (1,1,?)", ("LOAM System Map v0.1",))

        item_id = 1
        diagram_ids = {}
        for diagram_id, (name, entries, description) in enumerate(DIAGRAMS, 1):
            diagram_ids[name] = diagram_id
            db.execute(
                "insert into diagrams values (?,?,?,?,?)",
                (diagram_id, name, "0 0", description, 100.0),
            )

            insert_item(db, item_id, diagram_id, "beginend", name, 360, 60, 150, 24, 60)
            item_id += 1
            insert_item(db, item_id, diagram_id, "vertical", "", 360, 84, 0, 230)
            item_id += 1

            if name == "00 Overview":
                for index, entry in enumerate(entries):
                    insert_item(db, item_id, diagram_id, "action", entry, 360, 140 + index * 65, 220, 26)
                    item_id += 1
                end_y = 140 + len(entries) * 65
            else:
                text = "\n".join(entries)
                insert_item(db, item_id, diagram_id, "action", text, 360, 220, 300, max(40, 18 * len(entries)))
                item_id += 1
                end_y = 360

            insert_item(db, item_id, diagram_id, "beginend", "End", 360, end_y, 80, 24, 60)
            item_id += 1

        node_id = 1
        root = node_id
        db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, 0, "folder", "LOAM System Map", None))
        node_id += 1

        db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, root, "item", "", diagram_ids["00 Overview"]))
        node_id += 1
        for name in ["01 Human Entrances", "02 Commands & Questions", "03 Application"]:
            db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, root, "item", "", diagram_ids[name]))
            node_id += 1

        core_folder = node_id
        db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, root, "folder", "04 Core Facts", None))
        node_id += 1
        for name in ["04 Core Overview", "04.1 Movement", "04.2 Meaning", "04.3 Time & Truth", "04.4 Allocation", "04.5 Knowledge"]:
            db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, core_folder, "item", "", diagram_ids[name]))
            node_id += 1

        for name in ["05 Evidence & History", "06 Authority & Persistence", "07 Projections & Reports", "08 Formal Evidence"]:
            db.execute("insert into tree_nodes values (?,?,?,?,?)", (node_id, root, "item", "", diagram_ids[name]))
            node_id += 1

        db.commit()
        db.execute("pragma page_size=512")
        db.execute("vacuum")
        integrity = db.execute("pragma integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")

    print(OUTPUT)


if __name__ == "__main__":
    build()
