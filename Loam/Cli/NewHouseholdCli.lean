import Loam.Authority.HouseholdAuthority
import Loam.MovementWorldLoader
import Loam.OperationalContinuity

namespace Loam.NewHouseholdCli

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Explicit fresh household

This is *not* a recovery or year-rollover operation. A user who lost all data
may choose an independent, previously nonexistent directory and begin recording
from today's known facts. Never alter an old, corrupt, or merely idle root.

The initial image contains explicitly empty (not absent, not unknown-as-zero)
structural families. It asserts no bank balances, historical completeness,
planned payments, or fabricated opening transactions.
-/

private def initialImage? : Except String Loam.Persistence.HouseholdImage.Image := do
  let some actual := encodeNormalizedActual? Loam.ActualEvidence.empty
    | throw "loam: fresh Actual evidence could not be encoded"
  let some scheduledMemory :=
      ScheduledMemory.ofOccurrences? ([] : List (ScheduledOccurrence String))
    | throw "loam: empty Scheduled memory was not admitted"
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw "loam: empty Scheduled terminal memory was not admitted"
  let lifecycle : ScheduledLifecycleImage := {
    scheduled := scheduledMemory, terminals := terminals
  }
  let some scheduled := encodeScheduledLifecycleImage? lifecycle
    | throw "loam: empty Scheduled lifecycle could not be encoded"
  let some loci := encodeLocusAdmissionVocabulary? LocusAdmissionVocabulary.empty
    | throw "loam: empty Locus admission could not be encoded"
  let some roles := encodeAccountingRoleMap? AccountingRoleMap.empty
    | throw "loam: empty AccountingRole map could not be encoded"
  let some actualRouteHistory : Option ActualRoutingHistory :=
      RoutingHistory.ofEntries? []
    | throw "loam: empty Actual routing history was not admitted"
  let some actualRouting := encodeActualRoutingHistory? actualRouteHistory
    | throw "loam: empty Actual routing history could not be encoded"
  let some scheduledRouteHistory : Option (ScheduledRoutingHistory String) :=
      RoutingHistory.ofEntries? []
    | throw "loam: empty Scheduled routing history was not admitted"
  let some scheduledRouting := encodeScheduledRoutingHistory? scheduledRouteHistory
    | throw "loam: empty Scheduled routing history could not be encoded"
  let some attentionItems := AttentionMemory.ofItems? []
    | throw "loam: empty Attention items were not admitted"
  let some attentionClosures := AttentionClosureMemory.ofClosures? []
    | throw "loam: empty Attention closures were not admitted"
  let some attention := encodeAttentionMemory? attentionItems attentionClosures
    | throw "loam: empty Attention could not be encoded"
  let some capacity := encodeNormalizedCapacity? (Loam.CapacityEvidence.empty : Loam.CapacityEvidence String)
    | throw "loam: empty Capacity could not be encoded"
  let some zeroOrigin := encodeZeroOriginCoverage? ZeroOriginCoverage.empty
    | throw "loam: empty ZeroOrigin coverage could not be encoded"
  let some opening := encodeOpeningSupportMap? OpeningSupportMap.empty
    | throw "loam: empty Opening support could not be encoded"
  let some anchor := encodeCurrentQuantityAnchor? Loam.CurrentQuantityAnchor.Evidence.empty
    | throw "loam: empty CurrentQuantityAnchor could not be encoded"
  let some presence := encodeCurrentQuantityPresence? Loam.CurrentQuantityPresence.Evidence.empty
    | throw "loam: empty CurrentQuantityPresence could not be encoded"
  let some bounded := encodeBoundedHistorySupport? Loam.BoundedHistorySupport.Evidence.empty
    | throw "loam: empty BoundedHistorySupport could not be encoded"
  return {
    sections := [
      { name := "Actual", body := actual },
      { name := "Scheduled", body := scheduled },
      { name := "Capacity", body := capacity },
      { name := "Attention", body := attention },
      { name := "ActualRouting", body := actualRouting },
      { name := "ScheduledRouting", body := scheduledRouting },
      { name := "AccountingRole", body := roles },
      { name := "LocusAdmission", body := loci },
      { name := "ZeroOrigin", body := zeroOrigin },
      { name := "OpeningSupport", body := opening },
      { name := "CurrentQuantityAnchor", body := anchor },
      { name := "CurrentQuantityPresence", body := presence },
      { name := "BoundedHistorySupport", body := bounded }
    ]
  }

/--
Create an independent fresh household only in a directory that did not exist.
Neither an existing empty directory nor a failed/corrupt former household is a
permitted destination. The existing HouseholdImage installer supplies admission,
locking, staging, and re-read qualification. No old path is ever modified.
-/
def create (root : System.FilePath) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: new household path must not be empty"
  if ← root.pathExists then
    return .error "loam: new household destination already exists; choose a different directory"
  let image ←
    match initialImage? with
    | .ok image => pure image
    | .error message => return .error message
  try
    IO.FS.createDirAll root
    match ← Loam.HouseholdAuthority.installInitial? root image with
    | .error message => return .error message
    | .ok _ => pure ()
    match ← Loam.OperationalContinuity.diagnoseStartupRead root root with
    | .ok () => return .ok ()
    | .error diagnosis =>
        return .error ("loam: fresh household installed but startup check failed: " ++
          diagnosis.technical)
  catch error =>
    return .error ("loam: fresh household creation failed: " ++ error.toString)

/-- Deliberately no default root: choosing a new identity must be explicit. -/
def run (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      match ← create (System.FilePath.mk path) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok () =>
          IO.println ("New independent household created at: " ++ path)
          IO.println "No old transactions were imported; unknown past balances are not zero."
          IO.println ("Open it with: loam tui " ++ path)
          IO.println "Next: add account/category Loci and roles, observe today's balances, recreate future Scheduled payments, then record normally."
          IO.println "Daily Pace also needs an explicit pool and cycle boundaries before it can show a value."
          return 0
  | _ =>
      IO.eprintln "Usage: loam init NEW_DATA_DIR"
      IO.eprintln "Choose a directory that does not yet exist. This never resets or repairs an existing household."
      return 2

end Loam.NewHouseholdCli
