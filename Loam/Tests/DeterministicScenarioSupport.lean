import Loam.Authority.ActualAuthority
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Tests.ActualWorldFixture

namespace Loam.Tests.DeterministicScenarioSupport

open Loam
open Loam.Persistence

set_option autoImplicit false

def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw <| IO.userError s!"{message}: {detail}"

def cleanupDir (dir : System.FilePath) : IO Unit := do
  if ← dir.pathExists then
    IO.FS.removeDirAll dir

def authorityBytes (root : System.FilePath) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "load Household generation for Actual bytes"
  requireSome
    (Loam.Persistence.HouseholdImage.body? generation.image "Actual")
    "Household Actual section missing while reading authority bytes"

def publishInitialActual
    (root : System.FilePath)
    (evidence : ActualEvidence) : IO Unit := do
  let body ← requireSome
    (encodeNormalizedActual? evidence)
    "initial Actual fixture did not encode"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "Actual" body)
    "initial Household Actual fixture publication failed"
  pure ()

def publishInitialLocusAdmission
    (root : System.FilePath)
    (vocabulary : LocusAdmissionVocabulary) : IO Unit := do
  let body ← requireSome
    (Loam.Persistence.encodeLocusAdmissionVocabulary? vocabulary)
    "initial LocusAdmission fixture did not encode"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "LocusAdmission" body)
    "initial Household LocusAdmission fixture publication failed"
  pure ()

def loadActual
    (root : System.FilePath)
    (context : String) : IO ActualEvidence := do
  requireOk (← Loam.ActualAuthority.loadActual? root)
    s!"{context}: typed Actual reload failed"

def loadCanonicalActual
    (root : System.FilePath)
    (context : String) : IO (ActualEvidence × String) := do
  let evidence ← loadActual root context
  let encoded ← requireSome
    (encodeNormalizedActual? evidence)
    s!"{context}: admitted Actual failed canonical encoding"
  let decoded ← requireSome
    (decodeNormalizedActual? encoded)
    s!"{context}: canonical Actual failed typed decoding"
  let reencoded ← requireSome
    (encodeNormalizedActual? decoded)
    s!"{context}: decoded Actual failed canonical re-encoding"
  expect (encoded == reencoded)
    s!"{context}: normalized Actual encode/decode was not canonical"
  let disk ← authorityBytes root
  expect (disk == encoded)
    s!"{context}: authority bytes diverged from canonical admitted encoding"
  pure (evidence, disk)

def checkCanonical
    (root : System.FilePath)
    (context : String) : IO String := do
  let (_, bytes) ← loadCanonicalActual root context
  pure bytes

def expectRefusal {α : Type}
    (root : System.FilePath)
    (context : String)
    (action : IO (Except String α)) : IO Unit := do
  let before ← authorityBytes root
  match ← action with
  | .ok _ =>
      throw <| IO.userError s!"{context}: operation unexpectedly succeeded"
  | .error _ => pure ()
  let after ← authorityBytes root
  expect (after == before)
    s!"{context}: refused operation changed Actual authority bytes"
  let _ ← checkCanonical root context
  pure ()

end Loam.Tests.DeterministicScenarioSupport
