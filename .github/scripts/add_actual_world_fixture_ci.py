from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELPER_PATH_LINE = "      - 'Loam/Tests/ActualWorldFixture.lean'\n"
HELPER_TARGET = "Loam.Tests.ActualWorldFixture"

workflows = [
    ".github/workflows/application.yml",
    ".github/workflows/practical-slice-b.yml",
    ".github/workflows/actual-validity-publisher.yml",
    ".github/workflows/scheduled-creation-publisher.yml",
    ".github/workflows/scheduled-replacement-publisher.yml",
    ".github/workflows/scheduled-terminal-publisher.yml",
    ".github/workflows/tui.yml",
]

for relative in workflows:
    path = ROOT / relative
    text = path.read_text()
    if HELPER_TARGET in text or "Loam/Tests/ActualWorldFixture.lean" in text:
        raise SystemExit(f"fixture CI dependency already present in {relative}")

    path_count = text.count("    paths:\n")
    if path_count == 0:
        raise SystemExit(f"no event paths block found in {relative}")
    text = text.replace("    paths:\n", "    paths:\n" + HELPER_PATH_LINE)

    lines = text.splitlines(keepends=True)
    build_args = 0
    for index, line in enumerate(lines):
        marker = "build-args:"
        if marker not in line:
            continue
        if HELPER_TARGET in line:
            continue
        newline = "\n" if line.endswith("\n") else ""
        body = line[:-1] if newline else line
        lines[index] = body + " " + HELPER_TARGET + newline
        build_args += 1
    if build_args == 0:
        raise SystemExit(f"no build-args line found in {relative}")

    path.write_text("".join(lines))
    print(f"wired {relative}: {path_count} path block(s), {build_args} build target line(s)")

# Verify every workflow that executes a migrated test is now represented by the
# explicit dependency set. This catches a new caller/workflow added during the
# branch before the generated commit lands.
migrated_tests = set()
for test in (ROOT / "Loam" / "Tests").glob("*.lean"):
    if "import Loam.Tests.ActualWorldFixture" in test.read_text():
        migrated_tests.add(str(test.relative_to(ROOT)))

missing = []
for workflow in (ROOT / ".github" / "workflows").glob("*.yml"):
    text = workflow.read_text()
    if not any(test in text for test in migrated_tests):
        continue
    if HELPER_TARGET not in text:
        missing.append(str(workflow.relative_to(ROOT)))
if missing:
    raise SystemExit("workflow(s) execute migrated tests without fixture build target: " + ", ".join(sorted(missing)))

print(f"verified CI dependency coverage for {len(migrated_tests)} migrated test file(s)")
