import Loam.OperationalContinuity

namespace Loam.DoctorCli

set_option autoImplicit false

private def usage : String :=
  "Usage: ./tools/loam doctor [LOAM_DATA_DIR]"

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

/-- Read-only production-startup diagnosis. No repair or migration is attempted. -/
def run (args : List String) : IO UInt32 := do
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

end Loam.DoctorCli


def main (args : List String) : IO UInt32 :=
  Loam.DoctorCli.run args
