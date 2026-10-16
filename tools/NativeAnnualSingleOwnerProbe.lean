import Loam.Authority.AnnualSingleOwnerSandbox
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Review.AnnualSourceQueryPolicy

namespace Loam.Tools.NativeAnnualSingleOwnerProbe

open Loam.Core
open Loam.Persistence.HouseholdImage
open Loam.AnnualSingleOwnerSandbox
open Loam.AnnualSourceHeadSandbox

set_option autoImplicit false

private def expect (yes : Bool) (why : String) : IO Unit := do
  unless yes do throw (IO.userError why)

private def requireOk {α : Type} (x : Except String α) (label : String) :
    IO α := do
  match x with
  | .ok value => return value
  | .error reason => throw (IO.userError s!"{label}: {reason}")

private def requireSome {α : Type} (x : Option α) (label : String) :
    IO α := do
  let some value := x | throw (IO.userError label)
  return value

private def withLoci
    (generation : Loam.HouseholdAuthority.Generation)
    (newLocus : String) : IO Image := do
  let vocab ← requireSome (LocusAdmissionVocabulary.ofLoci?
    [⟨"bank"⟩, ⟨"cash"⟩, ⟨"food"⟩, ⟨"later"⟩, ⟨newLocus⟩])
    "native 2029 locus vocabulary"
  let body ← requireSome
    (Loam.Persistence.encodeLocusAdmissionVocabulary? vocab)
    "native locus body encoding"
  requireSome (replaceBody? generation.image "LocusAdmission" body)
    "native current source missing locus section"

private def sameHome
    (first second : Loam.AnnualSelectedHomePreview.Snapshot) : Bool :=
  let keys (home : Loam.Tui.Main.Snapshot) :=
    home.actual.allRecords.map (fun record =>
      (record.event.id.token, record.isCurrent))
  keys first.home == keys second.home &&
  first.view.currentBalances == second.view.currentBalances &&
  (first.view.openScheduled.map fun row => row.id.token) ==
    (second.view.openScheduled.map fun row => row.id.token) &&
  first.view.generation.wire != "" && second.view.generation.wire != ""

private def run (ordinary annual : System.FilePath) : IO Unit := do
  let ordinaryPath := Loam.HouseholdAuthority.path ordinary
  let original ← IO.FS.readFile ordinaryPath
  let previous ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath ordinary)
  let initialWire ← IO.FS.readFile (headPath annual)

  let pin ← requireOk (← open? annual initialWire)
    "select only the already observed annual authority"
  expect (pin.selected.head.years == ["2028"] &&
          !(← (annual / "journal" / "2029").pathExists))
    "read-only new-year entry created or lost a physical source year"

  let before ← requireOk
    (← pin.readHome? ordinary "2027-01-03") "first single-owner Home read"
  let nextYearRead ← requireOk
    (← pin.readHome? ordinary "2029-01-01")
    "read-only Jan 1 2029 must NOT open a new journal"
  expect (sameHome before nextYearRead &&
          !(← (annual / "journal" / "2029").pathExists))
    "new-year read created a journal or changed admitted source records"
  let candidate ← withLoci pin.selected.generation "new-for-2029"

  let first ← pin.append? "2029-01-01" "2029-first-native-operation"
    ["LocusAdmission"] candidate
  let latest ← match first with
  | .committed selected => pure selected
  | .refusedBeforeHead reason =>
      throw (IO.userError s!"valid native append refused: {reason}")
  | .outcomeUnknown _ reason =>
      throw (IO.userError s!"native append did not return a successful synced receipt: {reason}")

  expect (latest.head.years == ["2028", "2029"] &&
          latest.operations == ["post-migration-locus",
             "2029-first-native-operation"] &&
          latest.headWire != pin.selected.headWire &&
          (← (annual / "journal" / "2029" / "2.full.loam").pathExists))
    "2029 operation was not selected under the same HEAD authority"

  -- A pinned read and optimistic operation prepared from the old HEAD must
  -- refuse, not silently reload, fork a journal, or fall back to household.
  expect (!(← pin.readHome? ordinary "2027-01-03").isOk &&
          !(← open? annual initialWire).isOk)
    "stale session silently became current for Home"
  let staleCandidate ← withLoci pin.selected.generation "stale-writer"
  match ← pin.append? "2029-01-02" "stale-concurrent-op"
      ["LocusAdmission"] staleCandidate with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError
      "concurrent write from stale HEAD was not refused before publication")
  expect (!(← (annual / "journal" / "2029" / "3.full.loam").pathExists))
    "stale writer installed a phantom immutable annual source"

  let reopened ← requireOk (← open? annual latest.headWire)
    "pin newly committed annual source explicitly"
  let current ← requireOk
    (← reopened.readHome? ordinary "2027-01-03")
    "reopen Home from committed source"
  expect (sameHome before current &&
          current.view.generation.wire == latest.generation.wire &&
          current.view.openScheduled.isEmpty)
    "new year source made Home diverge from prior Actual/Scheduled/balances"

  -- Duplicate IDs are never allowed, including across a newly reopened pin.
  let duplicated ← withLoci reopened.selected.generation "duplicate-op"
  match ← reopened.append? "2029-01-03" "2029-first-native-operation"
      ["LocusAdmission"] duplicated with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "duplicate operation was not refused")

  -- The original installed household is a parity fixture only, NOT a writer.
  expect ((← IO.FS.readFile ordinaryPath) == original &&
          (← IO.FS.readFile
            (Loam.HouseholdAuthority.previousPath ordinary)) == previous)
    "year-source append dual-wrote to the original household"

  -- No second physical authority may coexist inside the annual root.
  IO.FS.writeFile (Loam.HouseholdAuthority.path annual) original
  expect (!(← open? annual latest.headWire).isOk)
    "annual root containing a competing household.loam was accepted"
  match ← reopened.append? "2029-01-04" "should-not-write"
      ["LocusAdmission"] duplicated with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError
      "annual writer failed to refuse a competing physical authority")
  IO.FS.removeFile (Loam.HouseholdAuthority.path annual)

  -- Reject a completely replayable old HEAD if the caller requires newer
  -- bytes. This pin is externally supplied; genuine trusted rollback
  -- protection is NOT implemented by this test.
  IO.FS.writeFile (headPath annual) initialWire
  expect (!(← open? annual latest.headWire).isOk)
    "valid-old HEAD rollback bypassed explicit expected bytes"
  IO.FS.writeFile (headPath annual) latest.headWire
  let final ← requireOk (← open? annual latest.headWire)
    "latest source remains replayable after refusal tests"
  let finalHome ← requireOk
    (← final.readHome? ordinary "2027-01-03")
    "last Home replay"
  expect (sameHome before finalHome &&
          (← IO.FS.readFile ordinaryPath) == original)
    "single owner read/write session did not preserve original household"
  IO.println "NATIVE_ANNUAL_SINGLE_OWNER_PASS pinned HEAD Home/read-CAS-write/reopen; Jan1 read-only; stale/duplicate/mixed-source/old-HEAD refused; no legacy dual write"

def main (args : List String) : IO Unit := do
  match args with
  | [ordinary, annual] =>
      run (System.FilePath.mk ordinary) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualSingleOwnerProbe SYNTHETIC_HOUSEHOLD ANNUAL_ROOT")

end Loam.Tools.NativeAnnualSingleOwnerProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSingleOwnerProbe.main args
