#!/usr/bin/env python3
"""Inventory Lean module granularity without treating file size as a verdict.

The report is intentionally descriptive. It extracts physical module shape,
imports, declarations, dependency fan-in/fan-out, sole-consumer relationships,
production-root reachability, and recent git co-change evidence. It does not
recommend merges or deletion automatically.

Run from the repository root:

    python3 tools/module_granularity_audit.py

Optional outputs:

    --tsv PATH       machine-readable module inventory
    --dot PATH       import DAG in Graphviz DOT form
    --markdown PATH  compact human audit table
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import pathlib
import re
import subprocess
from typing import Iterable

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOAM = ROOT / "Loam"
LAKEFILE = ROOT / "lakefile.lean"

IMPORT_RE = re.compile(r"^import\s+([A-Za-z0-9_.]+)\s*$")
DECL_RE = re.compile(
    r"^(?:private\s+|protected\s+|noncomputable\s+|partial\s+|unsafe\s+)*"
    r"(def|abbrev|structure|inductive|class|theorem|lemma|instance)\s+([A-Za-z0-9_'.]+)"
)
LEAN_LIB_RE = re.compile(r"^\s*lean_lib\s+([A-Za-z0-9_.]+)")
ROOT_RE = re.compile(r"^\s*root\s*:=\s*`([A-Za-z0-9_.]+)")


@dataclasses.dataclass(frozen=True)
class Module:
    name: str
    path: pathlib.Path
    lines: int
    bytes: int
    imports: tuple[str, ...]
    declarations: tuple[str, ...]

    @property
    def layer(self) -> str:
        relative = self.path.relative_to(ROOT)
        parts = relative.parts
        if relative == pathlib.Path("Loam.lean"):
            return "umbrella"
        if len(parts) >= 3 and parts[0] == "Loam":
            return parts[1]
        if len(parts) == 2 and parts[0] == "Loam":
            return "root"
        return "other"


def module_name(path: pathlib.Path) -> str:
    relative = path.relative_to(ROOT).with_suffix("")
    return ".".join(relative.parts)


def read_module(path: pathlib.Path) -> Module:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    imports: list[str] = []
    declarations: list[str] = []
    for line in lines:
        stripped = line.strip()
        import_match = IMPORT_RE.match(stripped)
        if import_match:
            imports.append(import_match.group(1))
        decl_match = DECL_RE.match(stripped)
        if decl_match:
            declarations.append(f"{decl_match.group(1)}:{decl_match.group(2)}")
    return Module(
        name=module_name(path),
        path=path,
        lines=len(lines),
        bytes=len(text.encode("utf-8")),
        imports=tuple(imports),
        declarations=tuple(declarations),
    )


def lean_modules() -> list[Module]:
    paths = sorted(LOAM.rglob("*.lean"))
    umbrella = ROOT / "Loam.lean"
    if umbrella.exists():
        paths.insert(0, umbrella)
    return [read_module(path) for path in paths]


def declared_roots() -> set[str]:
    """Read library/executable module roots declared by the Lake file.

    This is application/import reachability evidence, not Lake build inclusion:
    `lean_lib` may still compile namespace-glob modules that no production entry
    imports.
    """
    if not LAKEFILE.exists():
        return set()
    roots: set[str] = set()
    for line in LAKEFILE.read_text(encoding="utf-8").splitlines():
        library = LEAN_LIB_RE.match(line)
        if library:
            roots.add(library.group(1))
        executable_root = ROOT_RE.match(line)
        if executable_root:
            roots.add(executable_root.group(1))
    return roots


def reachable_modules(modules: list[Module], roots: set[str]) -> set[str]:
    by_name = {module.name: module for module in modules}
    reachable: set[str] = set()
    pending = [root for root in roots if root in by_name]
    while pending:
        name = pending.pop()
        if name in reachable:
            continue
        reachable.add(name)
        pending.extend(
            imported
            for imported in by_name[name].imports
            if imported in by_name and imported not in reachable
        )
    return reachable


def git(args: list[str]) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], text=True, stderr=subprocess.DEVNULL
    )


def recent_change_sets(limit: int) -> list[set[str]]:
    """Return changed Lean-module names for recent commits.

    Merge commits are included because LOAM commonly lands one qualified audit
    slice per PR; the evidence is descriptive rather than a statistical oracle.
    """
    try:
        raw = git([
            "log",
            f"-{limit}",
            "--name-only",
            "--pretty=format:@@COMMIT@@",
            "--",
            "Loam",
            "Loam.lean",
        ])
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    result: list[set[str]] = []
    current: set[str] = set()
    for line in raw.splitlines():
        if line == "@@COMMIT@@":
            if current:
                result.append(current)
            current = set()
            continue
        line = line.strip()
        if not line.endswith(".lean"):
            continue
        path = ROOT / line
        try:
            current.add(module_name(path))
        except ValueError:
            pass
    if current:
        result.append(current)
    return result


def cochange_counts(change_sets: Iterable[set[str]]) -> dict[tuple[str, str], int]:
    counts: dict[tuple[str, str], int] = collections.Counter()
    for changed in change_sets:
        names = sorted(changed)
        for index, left in enumerate(names):
            for right in names[index + 1 :]:
                counts[(left, right)] += 1
    return counts


def pair_count(counts: dict[tuple[str, str], int], left: str, right: str) -> int:
    if not left or not right or left == right:
        return 0
    return counts.get(tuple(sorted((left, right))), 0)


def quote(value: str) -> str:
    return '"' + value.replace('"', '\\"') + '"'


def build_rows(
    modules: list[Module],
    roots: set[str],
    reachable: set[str],
    cochanges: dict[tuple[str, str], int],
):
    by_name = {module.name: module for module in modules}
    consumers: dict[str, list[str]] = collections.defaultdict(list)
    for module in modules:
        for imported in module.imports:
            if imported in by_name:
                consumers[imported].append(module.name)

    rows = []
    for module in modules:
        local_imports = [name for name in module.imports if name in by_name]
        local_consumers = sorted(consumers[module.name])
        sole_consumer = local_consumers[0] if len(local_consumers) == 1 else ""
        rows.append(
            {
                "module": module.name,
                "path": str(module.path.relative_to(ROOT)),
                "layer": module.layer,
                "lines": module.lines,
                "bytes": module.bytes,
                "declarations": len(module.declarations),
                "fan_out": len(local_imports),
                "fan_in": len(local_consumers),
                "declared_root": module.name in roots,
                "reachable_from_declared_root": module.name in reachable,
                "sole_consumer": sole_consumer,
                "sole_consumer_cochanges": pair_count(
                    cochanges, module.name, sole_consumer
                ),
                "imports": ",".join(local_imports),
            }
        )
    return rows, by_name


def write_tsv(path: pathlib.Path, rows) -> None:
    columns = [
        "module",
        "path",
        "layer",
        "lines",
        "bytes",
        "declarations",
        "fan_out",
        "fan_in",
        "declared_root",
        "reachable_from_declared_root",
        "sole_consumer",
        "sole_consumer_cochanges",
        "imports",
    ]
    with path.open("w", encoding="utf-8") as handle:
        handle.write("\t".join(columns) + "\n")
        for row in rows:
            handle.write("\t".join(str(row[column]) for column in columns) + "\n")


def write_dot(path: pathlib.Path, modules: list[Module], by_name: dict[str, Module]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write("digraph loam_modules {\n")
        handle.write("  rankdir=LR;\n")
        for module in modules:
            handle.write(f"  {quote(module.name)};\n")
        for module in modules:
            for imported in module.imports:
                if imported in by_name:
                    handle.write(f"  {quote(module.name)} -> {quote(imported)};\n")
        handle.write("}\n")


def write_markdown(path: pathlib.Path, rows) -> None:
    ordered = sorted(rows, key=lambda row: (row["layer"], row["lines"], row["module"]))
    with path.open("w", encoding="utf-8") as handle:
        handle.write("# LOAM module granularity inventory\n\n")
        handle.write(
            "This table is candidate evidence only. Small modules are not presumed wrong; "
            "semantic ownership, reuse, authority, effect boundaries, and history must decide each verdict.\n\n"
        )
        handle.write(
            "| module | layer | lines | decls | fan-in | fan-out | reachable | sole consumer | cochanges |\n"
        )
        handle.write("|---|---|---:|---:|---:|---:|---|---|---:|\n")
        for row in ordered:
            handle.write(
                f"| `{row['module']}` | {row['layer']} | {row['lines']} | "
                f"{row['declarations']} | {row['fan_in']} | {row['fan_out']} | "
                f"{row['reachable_from_declared_root']} | `{row['sole_consumer']}` | "
                f"{row['sole_consumer_cochanges']} |\n"
            )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--history", type=int, default=200, help="recent commits for co-change evidence")
    parser.add_argument("--tsv", type=pathlib.Path)
    parser.add_argument("--dot", type=pathlib.Path)
    parser.add_argument("--markdown", type=pathlib.Path)
    args = parser.parse_args()

    modules = lean_modules()
    roots = declared_roots()
    reachable = reachable_modules(modules, roots)
    change_sets = recent_change_sets(args.history)
    cochanges = cochange_counts(change_sets)
    rows, by_name = build_rows(modules, roots, reachable, cochanges)

    if args.tsv:
        write_tsv(args.tsv, rows)
    if args.dot:
        write_dot(args.dot, modules, by_name)
    if args.markdown:
        write_markdown(args.markdown, rows)

    small = [row for row in rows if row["lines"] <= 80]
    sole = [row for row in rows if row["sole_consumer"]]
    production_unreachable = [
        row
        for row in rows
        if not row["reachable_from_declared_root"]
        and row["layer"] not in {"Tests", "Observations"}
    ]
    print(f"Lean modules: {len(rows)}")
    print(f"Modules <= 80 lines: {len(small)}")
    print(f"Modules with exactly one local consumer: {len(sole)}")
    print(f"Declared Lake roots: {len(roots)}")
    print(f"Production-like modules unreachable from declared roots: {len(production_unreachable)}")
    for row in production_unreachable:
        print(f"  unreachable: {row['module']}")
    print(f"Recent commit change sets observed: {len(change_sets)}")
    print("No merge/split/retirement verdicts are generated automatically.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
