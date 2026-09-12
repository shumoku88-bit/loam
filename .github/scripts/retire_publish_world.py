from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST_ROOT = ROOT / "Loam" / "Tests"
OLD_CALL = "Loam.ActualAuthority.publishWorld?"
NEW_CALL = "Loam.Tests.ActualWorldFixture.publishWorld?"
FIXTURE_IMPORT = "import Loam.Tests.ActualWorldFixture\n"
EXPECTED_TEST_FILES = 21

fixture = '''import Loam.ActualAuthority
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission

namespace Loam.Tests.ActualWorldFixture

open Loam.Core

set_option autoImplicit false

/--
Initialize one isolated test household from the older MovementAdmission.World shape.

This helper is deliberately test-only. MovementAdmission.World does not carry
correction or reversal history, so converting it to ActualEvidence is only sound
for fresh fixtures that intentionally start with those histories empty. Actual
and Locus-admission files are written sequentially; this is not a production
multi-authority transaction boundary.
-/
def publishWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Unit) := do
  let evidence : Loam.ActualEvidence := {
    events := world.events
    validity := world.validity
    descriptions := world.descriptions
    corrections := { corrections := [], idNodup := by simp }
    reversals := ActualReversalMemory.empty
    relations := world.relations
    discharges := world.discharges
  }
  let path :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then root
    else Loam.ActualAuthority.actualPath root
  let dataDir :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then
      root.parent.getD root
    else
      root
  match ← Loam.ActualAuthority.publishActualFile? path evidence with
  | .error message => return .error message
  | .ok () =>
      Loam.LocusAdmissionAuthority.publishCurrent? dataDir world.locusAdmission

end Loam.Tests.ActualWorldFixture
'''

fixture_path = TEST_ROOT / "ActualWorldFixture.lean"
if fixture_path.exists():
    raise SystemExit(f"fixture already exists: {fixture_path}")
fixture_path.write_text(fixture)

callers = []
occurrences = 0
for path in sorted(TEST_ROOT.glob("*.lean")):
    if path == fixture_path:
        continue
    text = path.read_text()
    count = text.count(OLD_CALL)
    if count == 0:
        continue
    callers.append(path)
    occurrences += count
    if FIXTURE_IMPORT.strip() not in text:
        text = FIXTURE_IMPORT + text
    text = text.replace(OLD_CALL, NEW_CALL)
    path.write_text(text)

if len(callers) != EXPECTED_TEST_FILES:
    names = ", ".join(str(path.relative_to(ROOT)) for path in callers)
    raise SystemExit(
        f"expected {EXPECTED_TEST_FILES} test caller files, found {len(callers)}: {names}"
    )

actual_authority = ROOT / "Loam" / "ActualAuthority.lean"
text = actual_authority.read_text()
start_marker = "\n/--\nPublish one complete MovementAdmission.World"
end_marker = "\nend Loam.ActualAuthority\n"
start = text.find(start_marker)
end = text.rfind(end_marker)
if start < 0 or end < 0 or end <= start:
    raise SystemExit("could not locate production publishWorld? block")
retired = text[:start] + end_marker
if "def publishWorld?" in retired:
    raise SystemExit("production publishWorld? definition survived retirement")
actual_authority.write_text(retired)

remaining_test_calls = []
for path in sorted(TEST_ROOT.glob("*.lean")):
    if OLD_CALL in path.read_text():
        remaining_test_calls.append(str(path.relative_to(ROOT)))
if remaining_test_calls:
    raise SystemExit("old publishWorld? test calls remain: " + ", ".join(remaining_test_calls))

print(
    f"retired production publishWorld?; migrated {len(callers)} test files "
    f"and {occurrences} call site(s) to test-only ActualWorldFixture"
)
