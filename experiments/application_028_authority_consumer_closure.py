#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

PRIMARY = {
    "loam",
    "loamMovement",
    "loamCapacity",
    "loamDailyQuantity",
    "loamOpenScheduled",
}
SECONDARY = {
    "loamActualRouting",
    "loamBudgetWindow",
    "loamJournalExport",
}
SHADOW = {
    "loamShadowAudit",
    "loamShadowQuantity",
    "loamShadowDay",
    "loamShadowScheduledDay",
}
HISTORICAL = {
    "loamHistoricalPrepare",
    "loamHistoricalPublish",
}

READ_RE = re.compile(r"\b(?:Loam\.Persistence\.)?load[A-Z][A-Za-z0-9_]*\?")
WRITE_RE = re.compile(r"\b(?:Loam\.Persistence\.)?save[A-Z][A-Za-z0-9_]*\?")
IMPORT_RE = re.compile(r"^import\s+([A-Za-z0-9_.]+)\s*$", re.MULTILINE)
EXE_RE = re.compile(
    r"lean_exe\s+([A-Za-z0-9_]+)\s+where\s*\n\s*root\s*:=\s*`([A-Za-z0-9_.]+)",
    re.MULTILINE,
)


def module_path(module: str) -> Path | None:
    if not module.startswith("Loam"):
        return None
    pieces = module.split(".")
    direct = ROOT.joinpath(*pieces).with_suffix(".lean")
    if direct.exists():
        return direct
    return None


def imported_modules(path: Path) -> list[str]:
    return IMPORT_RE.findall(path.read_text())


def closure(root_module: str) -> set[Path]:
    start = module_path(root_module)
    if start is None:
        raise SystemExit(f"missing executable root module: {root_module}")
    seen: set[Path] = set()
    stack = [start]
    while stack:
        path = stack.pop()
        if path in seen:
            continue
        seen.add(path)
        for module in imported_modules(path):
            imported = module_path(module)
            if imported is not None and imported not in seen:
                stack.append(imported)
    return seen


def cli_files(paths: set[Path]) -> set[Path]:
    result: set[Path] = set()
    cli_root = ROOT / "Loam" / "Cli"
    single = ROOT / "Loam" / "Cli.lean"
    for path in paths:
        if path == single or cli_root in path.parents:
            result.add(path)
    return result


def direct_access(path: Path) -> tuple[bool, bool]:
    text = path.read_text()
    return bool(READ_RE.search(text)), bool(WRITE_RE.search(text))


lake = (ROOT / "lakefile.lean").read_text()
exe_roots = dict(EXE_RE.findall(lake))
all_expected = PRIMARY | SECONDARY | SHADOW | HISTORICAL

if set(exe_roots) != all_expected:
    missing = sorted(all_expected - set(exe_roots))
    extra = sorted(set(exe_roots) - all_expected)
    raise SystemExit(f"executable role inventory drift: missing={missing} extra={extra}")

wrapper = (ROOT / "tools" / "loam").read_text()
menu_build = "lake build loam loamMovement loamCapacity loamDailyQuantity loamOpenScheduled"
if menu_build not in wrapper:
    raise SystemExit("ordinary tools/loam five-binary menu build frontier drifted")

closures = {name: closure(module) for name, module in exe_roots.items()}
access: dict[str, tuple[bool, bool]] = {}
for name, paths in closures.items():
    files = cli_files(paths)
    reads = any(direct_access(path)[0] for path in files)
    writes = any(direct_access(path)[1] for path in files)
    access[name] = (reads, writes)

retained = PRIMARY | SECONDARY
retained_consumers = {name for name in retained if access[name][0] or access[name][1]}
retained_writers = {name for name in retained_consumers if access[name][1]}
retained_read_only = retained_consumers - retained_writers

expected_writers = {
    "loam",
    "loamMovement",
    "loamCapacity",
    "loamDailyQuantity",
    "loamOpenScheduled",
    "loamActualRouting",
}
expected_read_only = {"loamBudgetWindow", "loamJournalExport"}
if retained_writers != expected_writers:
    raise SystemExit(
        f"steady-state writer classification drift: expected={sorted(expected_writers)} actual={sorted(retained_writers)}"
    )
if retained_read_only != expected_read_only:
    raise SystemExit(
        f"steady-state read-only classification drift: expected={sorted(expected_read_only)} actual={sorted(retained_read_only)}"
    )

retained_cli = set().union(*(cli_files(closures[name]) for name in retained))
direct_consumer_modules = {
    path
    for path in retained_cli
    if any(direct_access(path))
}
direct_writer_modules = {
    path
    for path in direct_consumer_modules
    if direct_access(path)[1]
}
direct_read_only_modules = direct_consumer_modules - direct_writer_modules

persistence_modules = {
    path
    for name in retained
    for path in closures[name]
    if (ROOT / "Loam" / "Persistence") in path.parents or path == ROOT / "Loam" / "Persistence.lean"
}

print("Application 028 authority consumer closure PASS")
print(f"declared_executables={len(exe_roots)}")
print(f"primary_practical_executables={len(PRIMARY)}")
print(f"secondary_steady_state_executables={len(SECONDARY)}")
print(f"nonsteady_executables={len(SHADOW | HISTORICAL)}")
print(f"steady_state_executables={len(retained)}")
print(f"steady_state_authority_consumers={len(retained_consumers)}")
print(f"steady_state_authority_writers={len(retained_writers)}")
print(f"steady_state_read_only_consumers={len(retained_read_only)}")
print(f"quiesce_or_retire_at_cutover={len(SHADOW | HISTORICAL)}")
print(f"unique_steady_state_cli_modules={len(retained_cli)}")
print(f"direct_persistence_consumer_cli_modules={len(direct_consumer_modules)}")
print(f"direct_persistence_writer_cli_modules={len(direct_writer_modules)}")
print(f"direct_persistence_read_only_cli_modules={len(direct_read_only_modules)}")
print(f"steady_state_persistence_modules={len(persistence_modules)}")

for name in sorted(exe_roots):
    reads, writes = access[name]
    if name in PRIMARY:
        role = "primary"
    elif name in SECONDARY:
        role = "secondary"
    elif name in SHADOW:
        role = "shadow"
    else:
        role = "historical"
    mode = "writer" if writes else "read-only" if reads else "no-direct-authority-call"
    print(f"exe {name}: role={role} authority={mode} root={exe_roots[name]}")

print("direct steady-state persistence consumers:")
for path in sorted(direct_consumer_modules):
    reads, writes = direct_access(path)
    mode = "writer" if writes else "read-only"
    print(f"  {path.relative_to(ROOT)}  {mode}")
