import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview
import Loam.Publisher.MovementPublisher
import Loam.Publisher.CorrectionPublisher
import Loam.Publisher.ActualValidityPublisher
import Loam.Tests.Support

namespace Loam.Tools.NativeHouseholdSectionBridge

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

/-!
Research-only real HouseholdImage snapshot emitter and verifier.
All roots are disposable and created by the caller. Do not use with
loam-data. Publication/knowledge years are NOT inferred from validOn.
-/

private def qualified (root : System.FilePath) : IO Loam.ActualAuthority.HouseholdObserved := do
  let observed ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "qualified native Household Actual"
  let lifecycle ← requireOk
    (Loam.ScheduledReview.fromGenerationForEvents observed.generation
      observed.image.evidence.events)
    "qualified native Scheduled from the same generation"
  let openRecords ← requireOk
    (Loam.ScheduledReview.currentOpenRecords lifecycle)
    "Scheduled open frontier"
  let ids := openRecords.map (fun row => row.id.token)
  expect (!ids.contains "paid" && !ids.contains "cancelled" &&
          ids.contains "exception" && ids.contains "first")
    "cross-year Scheduled endpoint was reopened or lost"
  return observed

private def capture (root output : System.FilePath) (name : String) : IO Unit := do
  let observed ← qualified root
  IO.FS.writeFile (output / (name ++ ".wire")) observed.generation.wire
  let records := Loam.ActualReview.recordsFromActualImage observed.image
  IO.println s!"NATIVE_SECTION_SNAPSHOT {name} bytes={observed.generation.wire.utf8ByteSize} actual_records={records.length} sections={observed.generation.image.sections.length}"

private def effects (amount : Int) : List Effect :=
  [Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
   Effect.ofAnonymousQuantity ⟨"wifi"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)]

private def produce (root output : System.FilePath) : IO Unit := do
  IO.FS.createDirAll output
  capture root output "snapshot-0"

  let first ← requireOk
    (← Loam.MovementPublisher.publishDraft root.toString {
      validOn := "2025-12-30"
      description := some "synthetic historical transaction"
      effects := effects 120
      relations := []
      discharges := []
      total := 120 })
    "qualified native synthetic Actual publish"
  capture root output "snapshot-1"

  let _ ← requireOk
    (← Loam.CorrectionPublisher.publishCorrection root.toString {
      target := first
      effects := effects 125
      description := some "historical transaction correction" })
    "qualified native Actual correction"
  capture root output "snapshot-2"

  let observed ← qualified root
  let edge ← requireSome
    (observed.image.evidence.corrections.corrections.find?
      (fun item => item.target == first))
    "native correction edge"
  let replacement := edge.replacement
  let _ ← requireOk
    (← Loam.ActualValidityPublisher.publishDate root.toString {
      target := replacement
      validOn := "2027-01-03" })
    "native Actual date revision"
  capture root output "snapshot-3"

  let final ← qualified root
  let rows := Loam.ActualReview.recordsFromActualImage final.image
  let original ← requireSome (rows.find? (fun row => row.event.id == first))
    "retained original Event"
  let winner ← requireSome (rows.find? (fun row => row.event.id == replacement))
    "retained current replacement"
  expect (!original.isCurrent && winner.isCurrent &&
          winner.date == some "2027-01-03")
    "cross-year corrected Actual winner differs from full admitted projection"
  IO.println "NATIVE_SECTION_PRODUCE_PASS real Actual correction+date and Scheduled witness"

private def verify (root : System.FilePath) : IO Unit := do
  let observed ← qualified root
  let rows := Loam.ActualReview.recordsFromActualImage observed.image
  let completed ← requireSome
    (rows.find? (fun row => row.description == "paid Wi-Fi"))
    "retained native Scheduled completion Actual"
  expect completed.isCurrent "completed Actual source changed"
  IO.println s!"NATIVE_SECTION_VERIFY_PASS bytes={observed.generation.wire.utf8ByteSize} actual_records={rows.length} sections={observed.generation.image.sections.length}"

def run (args : List String) : IO Unit := do
  match args with
  | ["produce", root, output] => produce (System.FilePath.mk root) (System.FilePath.mk output)
  | ["verify", root] => verify (System.FilePath.mk root)
  | _ => throw (IO.userError "usage: NativeHouseholdSectionBridge [produce ROOT OUT | verify ROOT]")

end Loam.Tools.NativeHouseholdSectionBridge

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeHouseholdSectionBridge.run args
