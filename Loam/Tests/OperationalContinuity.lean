import Loam.Authority.ActualAuthority
import Loam.MovementWorldLoader
import Loam.Authority.LocusAdmissionAuthority
import Loam.OperationalContinuity
import Loam.Tests.ActualWorldFixture

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

private def missingActualMessage : String :=
  "loam: required HouseholdImage Actual section is missing"

private def malformedActualMessage : String :=
  "loam: HouseholdImage section is malformed or unsupported: Actual"

private def conflictMessage : String :=
  "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"

private def installActualSection (root : System.FilePath) : IO Unit := do
  let some body := Loam.Persistence.encodeNormalizedActual? Loam.ActualEvidence.empty
    | throw (IO.userError "empty Actual did not encode")
  match ← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "Actual" body with
  | .ok () => pure ()
  | .error message => throw (IO.userError message)

private def installLocusSection (root : System.FilePath) : IO Unit := do
  let some body :=
      Loam.Persistence.encodeLocusAdmissionVocabulary?
        Loam.Core.LocusAdmissionVocabulary.empty
    | throw (IO.userError "empty LocusAdmission did not encode")
  match ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "LocusAdmission" body with
  | .ok () => pure ()
  | .error message => throw (IO.userError message)

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  let actualRoot := dataDir
  IO.FS.createDirAll dataDir

  let missing :=
    Loam.OperationalContinuity.explainReadFailure "Actual / Movement" missingActualMessage
  expect (missing.area == "Actual / Movement") "missing actual area"
  expect
    (missing.situation ==
      "The HouseholdImage Actual authority is unavailable, so LOAM will not guess household actual facts.")
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
      "The HouseholdImage Actual section cannot be verified, so LOAM refused to treat it as current household data.")
    "malformed human situation"
  expect (malformed.technical == malformedActualMessage) "malformed technical preservation"

  let conflict :=
    Loam.OperationalContinuity.explainReadFailure "Scheduled" conflictMessage
  expect
    (conflict.situation ==
      "Scheduled lifecycle evidence contains conflicting terminal claims, so LOAM refused to choose one silently.")
    "Scheduled conflict human situation"

  match ← Loam.OperationalContinuity.diagnoseStartupRead dataDir actualRoot with
  | .ok () => throw (IO.userError "missing household.loam Actual must fail closed")
  | .error diagnosis =>
      expect (diagnosis.area == "Actual / Movement") "startup diagnosis area"
      expect
        (diagnosis.technical.startsWith "loam: HouseholdImage authority is missing:")
        "startup technical cause"
      expect
        ((Loam.OperationalContinuity.renderDiagnosis diagnosis).startsWith
          "LOAM operational diagnosis\nStatus: blocked\n")
        "blocked diagnosis rendering"

  let fallbackParent := dataDir / "fallback-parent"
  let selectedRoot := fallbackParent / "selected-household"
  IO.FS.createDirAll selectedRoot
  installActualSection fallbackParent
  installLocusSection fallbackParent

  match ← Loam.MovementWorldLoader.loadSelectedWorld? selectedRoot with
  | .ok _ =>
      throw (IO.userError "explicit household root silently fell back to parent Household Actual authority")
  | .error message =>
      expect
        (message ==
          s!"loam: HouseholdImage authority is missing: {Loam.HouseholdAuthority.path selectedRoot}")
        "selected household root did not fail at its own Household authority"

  installActualSection selectedRoot
  match ← Loam.MovementWorldLoader.loadSelectedWorld? selectedRoot with
  | .ok _ =>
      throw (IO.userError "explicit household root silently paired with parent Locus admission authority")
  | .error message =>
      expect
        (message == "loam: required HouseholdImage Locus admission section is missing")
        "selected household root did not fail at its own Locus admission section"

  expect
    (Loam.OperationalContinuity.renderReady.startsWith
      "LOAM operational diagnosis\nStatus: ready\n")
    "ready rendering"

  IO.println "Operational continuity diagnosis: human explanation and strict fail-closed authority selection passed."
