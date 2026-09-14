#!/usr/bin/env python3
"""Inspect the LOAM DRAKON map as text.

This is the screenshot-light bridge for AI/human collaboration: it exposes the
tree, semantic icon text, decision orientation, source metadata, and optional
geometry without requiring a rendered screenshot.
"""

from pathlib import Path
import argparse
import json
import sqlite3

HERE = Path(__file__).resolve().parent
DEFAULT_MAP = HERE / "loam-system-map.drn"
SEMANTIC_TYPES = {
    "beginend", "action", "insertion", "if", "branch", "address",
    "loopstart", "loopend", "select", "case", "commentin", "commentout",
}


def connect(path: Path) -> sqlite3.Connection:
    if not path.exists():
        raise SystemExit(
            f"map not found: {path}\nRun: python3 {HERE / 'build_map.py'}"
        )
    return sqlite3.connect(path)


def diagram_names(db: sqlite3.Connection) -> list[str]:
    return [row[0] for row in db.execute("select name from diagrams order by diagram_id")]


def resolve_diagram(db: sqlite3.Connection, query: str) -> str:
    names = diagram_names(db)
    exact = [name for name in names if name.lower() == query.lower()]
    if exact:
        return exact[0]
    matches = [name for name in names if query.lower() in name.lower()]
    if not matches:
        raise SystemExit(f"no diagram matches {query!r}")
    if len(matches) > 1:
        raise SystemExit("diagram query is ambiguous:\n  " + "\n  ".join(matches))
    return matches[0]


def tree_rows(db: sqlite3.Connection):
    nodes = {
        row[0]: {
            "id": row[0], "parent": row[1], "type": row[2],
            "name": row[3], "diagram_id": row[4],
        }
        for row in db.execute(
            "select node_id,parent,type,name,diagram_id from tree_nodes order by node_id"
        )
    }
    dia_names = {
        row[0]: row[1]
        for row in db.execute("select diagram_id,name from diagrams")
    }
    children = {}
    for node in nodes.values():
        children.setdefault(node["parent"], []).append(node)

    result = []

    def walk(parent: int, depth: int):
        for node in children.get(parent, []):
            label = (
                node["name"]
                if node["type"] == "folder"
                else dia_names.get(node["diagram_id"], "?")
            )
            result.append((depth, node["type"], label))
            walk(node["id"], depth + 1)

    walk(0, 0)
    return result


def metadata(db: sqlite3.Connection, diagram_id: int) -> dict[str, str]:
    return dict(
        db.execute(
            "select name,value from diagram_info where diagram_id=? order by name",
            (diagram_id,),
        )
    )


def semantic_items(db: sqlite3.Connection, diagram_id: int, geometry: bool = False):
    rows = list(
        db.execute(
            "select item_id,type,text,x,y,w,h,a,b from items "
            "where diagram_id=? order by y,x,item_id",
            (diagram_id,),
        )
    )
    result = []
    for item_id, kind, text, x, y, w, h, a, b in rows:
        if not geometry and kind not in SEMANTIC_TYPES:
            continue
        entry = {"id": item_id, "type": kind, "text": text or ""}
        if kind == "if":
            entry["bottom_exit"] = "YES" if b == 1 else "NO"
            entry["right_exit"] = "NO" if b == 1 else "YES"
            entry["right_exit_x"] = x + w + a
        if geometry:
            entry["geometry"] = {"x": x, "y": y, "w": w, "h": h, "a": a, "b": b}
        result.append(entry)
    return result


def print_tree(db: sqlite3.Connection):
    for depth, kind, label in tree_rows(db):
        marker = "[+]" if kind == "folder" else "-"
        print("  " * depth + f"{marker} {label}")


def print_diagram(db: sqlite3.Connection, name: str, geometry: bool = False):
    diagram_id, description = db.execute(
        "select diagram_id,description from diagrams where name=?", (name,)
    ).fetchone()
    print(f"\n=== {name} ===")
    if description:
        print(f"Description: {description}")
    meta = metadata(db, diagram_id)
    for key in ("sources", "audit", "status"):
        if key in meta:
            print(f"{key.capitalize()}: {meta[key]}")
    print("Items:")
    for item in semantic_items(db, diagram_id, geometry=geometry):
        text = item["text"].replace("\n", " / ")
        if item["type"] == "if":
            line = (
                f"  #{item['id']} IF {text} "
                f"[bottom={item['bottom_exit']}, "
                f"right={item['right_exit']} @x={item['right_exit_x']}]"
            )
        else:
            line = f"  #{item['id']} {item['type'].upper()} {text}"
        if geometry:
            line += " " + json.dumps(item["geometry"], ensure_ascii=False)
        print(line)


def as_json(db: sqlite3.Connection, names: list[str], geometry: bool = False):
    payload = {
        "tree": [
            {"depth": depth, "type": kind, "label": label}
            for depth, kind, label in tree_rows(db)
        ],
        "diagrams": [],
    }
    for name in names:
        diagram_id, description = db.execute(
            "select diagram_id,description from diagrams where name=?", (name,)
        ).fetchone()
        payload["diagrams"].append(
            {
                "name": name,
                "description": description,
                "metadata": metadata(db, diagram_id),
                "items": semantic_items(db, diagram_id, geometry=geometry),
            }
        )
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("map", nargs="?", type=Path, default=DEFAULT_MAP)
    parser.add_argument("--diagram", "-d")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--geometry", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    with connect(args.map) as db:
        if args.all:
            names = diagram_names(db)
        elif args.diagram:
            names = [resolve_diagram(db, args.diagram)]
        else:
            names = []

        if args.json:
            as_json(db, names, args.geometry)
            return

        print("LOAM DRAKON tree")
        print_tree(db)
        if names:
            for name in names:
                print_diagram(db, name, args.geometry)
        else:
            print("\nUse --diagram 'Record Movement' to inspect one diagram.")
            print("Use --geometry when a screenshot-equivalent layout trace is useful.")


if __name__ == "__main__":
    main()
