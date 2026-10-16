import Loam.Authority.AnnualSourceHeadSandbox

namespace Loam.AnnualSandboxDurabilityBarriers

set_option autoImplicit false

/-!
# Linux-only fsync barriers for the disposable native annual source sandbox

Lean 4's current IO.FS.Handle.flush is NOT a POSIX fsync. This deliberately
opt-in experimental adapter runs an audited, fixed Python helper synchronously
for each file or parent-directory durability barrier. The helper refuses any
unmarked root, escaping path, symlink, unsupported OS, and any failed fsync.
There is NO fallback to IO.FS.Handle.flush or ordinary rename.

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
    throw (IO.userError s!"annual Linux durability barrier failed ({kind}, {target}): {output.stderr}")

/-- The only injection point for a real Linux file+directory fsync experiment.
All calls fail closed; no-process-barrier/no-op fallback is forbidden here. -/
def barriers (root : System.FilePath) :
    Loam.AnnualSourceHeadSandbox.PublicationBarriers := {
  syncFile := runSync root "file"
  syncParents := runSync root "parents"
}

end Loam.AnnualSandboxDurabilityBarriers
