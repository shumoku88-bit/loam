import Loam.OperationalContinuity

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

private def missingCurrentMessage : String :=
  "loam: selected Movement manifest CURRENT is missing"

private def digestMessage : String :=
  "loam: selected Movement object failed digest verification: objects/Event/example.loam"

private def conflictMessage : String :=
  "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  let manifestRoot := dataDir / "movement-authority"
  IO.FS.createDirAll dataDir

  let missing :=
    Loam.OperationalContinuity.explainReadFailure "Actual / Movement" missingCurrentMessage
  expect (missing.area == "Actual / Movement") "missing CURRENT area"
  expect
    (missing.situation ==
      "The selected Movement authority is unavailable, so LOAM will not guess which household generation is current.")
    "missing CURRENT human situation"
  expect (missing.technical == missingCurrentMessage) "missing CURRENT technical preservation"
  expect
    (missing.safety ==
      "This diagnosis is read-only. It did not create, change, repair, or discard any household fact.")
    "read-only safety statement"

  let digest :=
    Loam.OperationalContinuity.explainReadFailure "Actual / Movement" digestMessage
  expect
    (digest.situation ==
      "The selected Movement generation failed integrity verification and was not trusted.")
    "digest human situation"
  expect (digest.technical == digestMessage) "digest technical preservation"

  let conflict :=
    Loam.OperationalContinuity.explainReadFailure "Scheduled" conflictMessage
  expect
    (conflict.situation ==
      "Scheduled lifecycle evidence contains conflicting terminal claims, so LOAM refused to choose one silently.")
    "Scheduled conflict human situation"

  match ← Loam.OperationalContinuity.diagnoseStartupRead dataDir manifestRoot with
  | .ok () => throw (IO.userError "missing CURRENT must fail closed")
  | .error diagnosis =>
      expect (diagnosis.area == "Actual / Movement") "startup diagnosis area"
      expect (diagnosis.technical == missingCurrentMessage) "startup technical cause"
      expect
        ((Loam.OperationalContinuity.renderDiagnosis diagnosis).startsWith
          "LOAM operational diagnosis\nStatus: blocked\n")
        "blocked diagnosis rendering"

  expect
    (Loam.OperationalContinuity.renderReady.startsWith
      "LOAM operational diagnosis\nStatus: ready\n")
    "ready rendering"

  IO.println "Operational continuity diagnosis: human explanation and fail-closed startup probe passed."
