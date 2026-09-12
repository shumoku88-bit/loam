import Loam.OperationalContinuity

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

private def missingActualMessage : String :=
  "loam: actual authority not found: /data/actual.loam"

private def malformedActualMessage : String :=
  "loam: actual authority is malformed or unsupported: /data/actual.loam"

private def conflictMessage : String :=
  "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  let manifestRoot := dataDir
  IO.FS.createDirAll dataDir

  let missing :=
    Loam.OperationalContinuity.explainReadFailure "Actual / Movement" missingActualMessage
  expect (missing.area == "Actual / Movement") "missing actual area"
  expect
    (missing.situation ==
      "The actual.loam authority file is missing, so LOAM will not guess household actual facts.")
    "missing actual human situation"
  expect (missing.technical == missingActualMessage) "missing actual technical preservation"
  expect
    (missing.safety ==
      "This diagnosis is read-only. It did not create, change, repair, or discard any household fact.")
    "read-only safety statement"

  let malformed :=
    Loam.OperationalContinuity.explainReadFailure "Actual / Movement" malformedActualMessage
  expect
    (malformed.situation ==
      "The actual.loam authority file cannot be verified, so LOAM refused to treat it as current household data.")
    "malformed human situation"
  expect (malformed.technical == malformedActualMessage) "malformed technical preservation"

  let conflict :=
    Loam.OperationalContinuity.explainReadFailure "Scheduled" conflictMessage
  expect
    (conflict.situation ==
      "Scheduled lifecycle evidence contains conflicting terminal claims, so LOAM refused to choose one silently.")
    "Scheduled conflict human situation"

  match ← Loam.OperationalContinuity.diagnoseStartupRead dataDir manifestRoot with
  | .ok () => throw (IO.userError "missing actual.loam must fail closed")
  | .error diagnosis =>
      expect (diagnosis.area == "Actual / Movement") "startup diagnosis area"
      expect (diagnosis.technical.startsWith "loam: actual authority not found:") "startup technical cause"
      expect
        ((Loam.OperationalContinuity.renderDiagnosis diagnosis).startsWith
          "LOAM operational diagnosis\nStatus: blocked\n")
        "blocked diagnosis rendering"

  expect
    (Loam.OperationalContinuity.renderReady.startsWith
      "LOAM operational diagnosis\nStatus: ready\n")
    "ready rendering"

  IO.println "Operational continuity diagnosis: human explanation and fail-closed startup probe passed."
