import Loam.Authority.AnnualSourceHeadSandbox

namespace Loam.AnnualSandboxDurabilityBarriers

set_option autoImplicit false

/-!
# POSIX native annual source durability barriers (disposable roots only)

Lean 4's current IO.FS.Handle.flush is NOT a POSIX fsync. This deliberately
opt-in experimental adapter runs an audited, fixed Python helper synchronously
for each file or parent-directory durability barrier. The helper refuses any
unmarked root, escaping path, symlink, unsupported OS, and any failed sync.
Linux invokes os.fsync; Darwin/APFS requires the separate precompiled
F_FULLFSYNC C witness supplied by disposable CI. No supported syscall or
verified APFS mount means refusal; no fallback to fsync on Darwin, flush,
or ordinary rename.

Do not call this from product authority, or claim that CI's SIGKILL/power
semantics prove actual sudden-power-loss durability on Linux/macOS.
-/

def markerFile : String := ".loam-annual-durability-sandbox-only"

def markerBody : String := "LOAM ANNUAL SANDBOX ONLY\n"

/-- Explicitly mark a disposable test root. The caller must already own this
root; marker presence is NOT an authentication or sandbox security boundary. -/
def markDisposableRoot (root : System.FilePath) : IO Unit := do
  IO.FS.createDirAll root
  IO.FS.writeFile (root / markerFile) markerBody

private def runSync (root : System.FilePath) (kind : String)
    (target : System.FilePath) : IO Unit := do
  let output ← IO.Process.output {
    cmd := "python3"
    args := #["tools/annual-sandbox-sync.py", kind, root.toString, target.toString]
  }
  if output.exitCode != 0 then
    throw (IO.userError s!"annual POSIX durability barrier failed ({kind}, {target}): {output.stderr}")

/-- Existing injection point for real Linux fsync and macOS/APFS F_FULLFSYNC
file+directory barriers, with no-op fallback forbidden in this research path.
The production HouseholdAuthority does not call this adapter. -/
def barriers (root : System.FilePath) :
    Loam.AnnualSourceHeadSandbox.PublicationBarriers := {
  syncFile := runSync root "file"
  syncParents := runSync root "parents"
}

end Loam.AnnualSandboxDurabilityBarriers
