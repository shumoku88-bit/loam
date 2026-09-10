import Loam.MovementRecoveryPublisher
import Loam.OperationalContinuity

namespace Loam.DoctorCli

set_option autoImplicit false

private def usage : String :=
  "Usage:\n" ++
  "  ./tools/loam doctor [LOAM_DATA_DIR]\n" ++
  "  ./tools/loam doctor restore RECOVERY_DIGEST [LOAM_DATA_DIR]"

private def resolveDataDir (args : List String) : IO (Except String System.FilePath) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")
  | [path] =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | _ => return .error usage

private def resolveManifestRoot
    (dataDir : System.FilePath) : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some path =>
      if path.isEmpty then return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok (System.FilePath.mk path)
  | none => return .ok (dataDir / "movement-authority")

private def diagnose (args : List String) : IO UInt32 := do
  let dataDir ←
    match ← resolveDataDir args with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let manifestRoot ←
    match ← resolveManifestRoot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  match ← Loam.OperationalContinuity.diagnoseStartupRead dataDir manifestRoot with
  | .ok () =>
      IO.println Loam.OperationalContinuity.renderReady
      return 0
  | .error diagnosis =>
      IO.eprintln (Loam.OperationalContinuity.renderDiagnosis diagnosis)
      return 2

private def restore (digest : String) (dataArgs : List String) : IO UInt32 := do
  let dataDir ←
    match ← resolveDataDir dataArgs with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let manifestRoot ←
    match ← resolveManifestRoot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  match ← Loam.MovementRecoveryPublisher.restore manifestRoot.toString digest with
  | .error message =>
      IO.eprintln "LOAM recovery"
      IO.eprintln "Status: refused"
      IO.eprintln ("Technical detail: " ++ message)
      return 2
  | .ok () =>
      IO.println "LOAM recovery"
      IO.println "Status: restored"
      IO.println ("Selected recovery generation: " ++ digest)
      IO.println "CURRENT now selects an already-retained generation that passed manifest, object-digest, and typed-world validation."
      IO.println "No household facts were synthesized by recovery."
      return 0

/-- Diagnose startup reads, or explicitly restore one exact retained Movement generation. -/
def run (args : List String) : IO UInt32 := do
  match args with
  | "restore" :: digest :: dataArgs => restore digest dataArgs
  | "restore" :: [] =>
      IO.eprintln usage
      return 2
  | _ => diagnose args

end Loam.DoctorCli


def main (args : List String) : IO UInt32 :=
  Loam.DoctorCli.run args
