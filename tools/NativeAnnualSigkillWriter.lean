import Loam.Authority.AnnualSourceHeadSandbox

namespace Loam.Tools.NativeAnnualSigkillWriter

set_option autoImplicit false

private def requireOk {α : Type} (value : Except String α)
    (label : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error message => throw (IO.userError s!"{label}: {message}")

/--
This executable is intentionally limited to disposable CI roots, supplied by
the external harness. The hook fires inside the REAL sandbox append path after
the full native source file is installed and requalified, before the sole HEAD
can change. The harness sends SIGKILL to the entire subprocess group after it
sees the ready marker. No production path, data or authority is touched.
-/
def run (args : List String) : IO Unit := do
  let [rootText, beforeText, afterText, readyText] := args
    | throw (IO.userError
        "usage: NativeAnnualSigkillWriter TEMP_ROOT BEFORE AFTER READY")
  let root := System.FilePath.mk rootText
  let before ← IO.FS.readFile (System.FilePath.mk beforeText)
  let after ← IO.FS.readFile (System.FilePath.mk afterText)
  let beforeGen ← requireOk
    (Loam.AnnualSourceMaterialization.qualifyWire? before) "baseline"
  let afterGen ← requireOk
    (Loam.AnnualSourceMaterialization.qualifyWire? after) "candidate"
  let base ← requireOk
    (← Loam.AnnualSourceHeadSandbox.bootstrap? root "2026" beforeGen.wire)
    "sandbox bootstrap"
  let _ ← requireOk
    (← Loam.AnnualSourceHeadSandbox.appendWithInstalledTestHook?
      root base.headWire "2027-01-03" "scheduled-completion:first"
      ["Actual", "Scheduled"] afterGen.image (do
        IO.FS.writeFile (System.FilePath.mk readyText) "SOURCE_INSTALLED_BEFORE_HEAD\n"
        IO.sleep 60000))
    "append should not return before an intentional process SIGKILL"
  throw (IO.userError "SIGKILL did not terminate the writer at its intended cut")

end Loam.Tools.NativeAnnualSigkillWriter

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSigkillWriter.run args
