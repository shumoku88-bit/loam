import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview
import Loam.Publisher.MovementPublisher
import Loam.Publisher.CorrectionPublisher
import Loam.Publisher.ActualValidityPublisher
import Loam.Tests.Support

namespace Loam.Tools.NativeAnnualReadProbe

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

/-!
Research-only native dependency-closure experiment.

The root is created by ScheduledBatchReplacement's "setup" fixture.
The probe only mutates that disposable root, using production Actual
publishers, while reading *the same qualified Household generation*
through actual Actual and Scheduled codecs.

This is NOT a production partitioned reader. Learned timestamps are not
yet canonical. We test real correction and completion identity closure.
-/

private def dueIds (snapshot : Loam.ScheduledReview.EvidenceSnapshot) :
    Except String (List String) := do
  let openRecords ← Loam.ScheduledReview.currentOpenRecords snapshot
  return openRecords.map (fun entry => entry.id.token)

private def currentYearIds (records : List Loam.ActualReview.Record)
    (year : String) : List String :=
  (records.filter fun row =>
      row.isCurrent &&
      row.date.any (fun day => day.startsWith (year ++ "-"))).map (fun row => row.event.id.token)

private def closureStep
    (records : List Loam.ActualReview.Record) (ids : List String) : List String :=
  records.foldl (fun collected row =>
    let sourceToken := row.event.id.token
    match row.replacement with
    | none => collected
    | some successor =>
        if collected.contains sourceToken || collected.contains successor.token then
          (sourceToken :: successor.token :: collected).eraseDups
        else collected) ids

/-- Close both ends of real retained correction edges. -/
private def correctionClosure
    (records : List Loam.ActualReview.Record) (year : String) : List String := Id.run do
  let initial :=
    (records.filter fun row => row.date.any (fun day =>
      day.startsWith (year ++ "-"))).map (fun row => row.event.id.token)
  let mut reachable := initial.eraseDups
  for _ in List.range (records.length + 1) do
    reachable := closureStep records reachable
  return reachable

private def closedYearIds
    (records : List Loam.ActualReview.Record) (year : String) : List String :=
  let reachable := correctionClosure records year
  (records.filter fun row =>
      reachable.contains row.event.id.token &&
      row.isCurrent &&
      row.date.any (fun day => day.startsWith (year ++ "-"))).map (fun row => row.event.id.token)

private def actualEffects (amount : Int) : List Effect :=
  [Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
   Effect.ofAnonymousQuantity ⟨"wifi"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)]

private def fromSameGeneration
    (root : System.FilePath) :
    IO (Loam.ActualAuthority.HouseholdObserved ×
      Loam.ScheduledReview.EvidenceSnapshot) := do
  let observed ← requireOk
    (← Loam.ActualAuthority.loadHouseholdObserved? root) "native admitted Actual"
  let scheduled ← requireOk
    (Loam.ScheduledReview.fromGenerationForEvents
      observed.generation observed.image.evidence.events)
    "native admitted Scheduled from same Household generation"
  return (observed, scheduled)

def run (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "one isolated setup root required")
  let root := System.FilePath.mk path

  let (before, scheduledBefore) ← fromSameGeneration root
  let openBefore ← requireOk (dueIds scheduledBefore) "before Scheduled due"
  expect (openBefore.contains "exception") "2027 Scheduled original missing"
  expect (openBefore.contains "first") "2026 Scheduled original missing"
  expect (!openBefore.contains "paid") "completed 2026 Scheduled falsely open"
  expect (!openBefore.contains "cancelled") "cancelled 2026 Scheduled falsely open"

  -- Selecting a 2027-only Actual subset cannot justify the paid 2026
  -- Scheduled without its completion Actual. Do not map this to not-due.
  let emptyEvents ← requireSome (EventMemory.ofEvents? []) "empty test Event memory"
  match Loam.ScheduledReview.fromGenerationForEvents before.generation emptyEvents with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError
      "Scheduled read accepted a trimmed Actual set missing completion evidence")

  let original ← requireOk
    (← Loam.MovementPublisher.publishDraft root.toString {
      validOn := "2025-12-30"
      description := some "synthetic original"
      effects := actualEffects 120
      relations := []
      discharges := []
      total := 120 })
    "real 2025 Actual publication"

  let (afterOriginal, _) ← fromSameGeneration root
  let beforeCorrection := Loam.ActualReview.recordsFromActualImage afterOriginal.image
  expect ((currentYearIds beforeCorrection "2025").contains original.token)
    "2025 source not projected before correction"

  let _ ← requireOk
    (← Loam.CorrectionPublisher.publishCorrection root.toString {
      target := original
      effects := actualEffects 125
      description := some "synthetic correction" })
    "cross-year source correction"

  let (afterCorrection, _) ← fromSameGeneration root
  let correction ← requireSome
    (afterCorrection.image.evidence.corrections.corrections.find?
      (fun item => item.target == original))
    "retained correction edge"
  let replacement := correction.replacement

  let _ ← requireOk
    (← Loam.ActualValidityPublisher.publishDate root.toString {
      target := replacement
      validOn := "2027-01-03" })
    "cross-year validity change for corrected source"

  let (finalObserved, finalScheduled) ← fromSameGeneration root
  let finalRecords := Loam.ActualReview.recordsFromActualImage finalObserved.image
  let oldRow ← requireSome (finalRecords.find?
    (fun row => row.event.id == original)) "retained original"
  let newRow ← requireSome (finalRecords.find?
    (fun row => row.event.id == replacement)) "retained replacement"
  expect (!oldRow.isCurrent && newRow.isCurrent)
    "Actual correction frontier did not retain original and elect replacement"
  expect (newRow.date == some "2027-01-03")
    "validity revision did not move correction winner into 2027"
  expect (!(currentYearIds finalRecords "2025").contains original.token)
    "old-year query included a superseded original"
  expect (!(currentYearIds finalRecords "2025").contains replacement.token)
    "old-year query included a newly dated winner"
  expect ((currentYearIds finalRecords "2027").contains replacement.token)
    "2027 query lost winner after changed valid date"

  let closure2025 := correctionClosure finalRecords "2025"
  let closure2027 := correctionClosure finalRecords "2027"
  expect (closure2025.contains original.token && closure2025.contains replacement.token)
    "2025 source dependency missed later 2027 replacement"
  expect (closure2027.contains original.token && closure2027.contains replacement.token)
    "2027 source dependency missed original in earlier effective year"
  for year in ["2025", "2026", "2027"] do
    let expected := currentYearIds finalRecords year
    let selected := closedYearIds finalRecords year
    expect (selected == expected)
      ("corrected native current-year answer differs after identity closure: " ++ year)

  let scheduledAfterIds ← requireOk (dueIds finalScheduled) "Scheduled after native corrections"
  expect (scheduledAfterIds == openBefore)
    "Actual-only mutations changed Scheduled open frontier"
  expect
    (Loam.Persistence.HouseholdImage.body? finalObserved.generation.image "Scheduled" ==
     Loam.Persistence.HouseholdImage.body? before.generation.image "Scheduled")
    "Actual-only publishers modified retained Scheduled bytes"
  expect (finalRecords.length >= 3)
    "completed Scheduled Actual plus original and replacement not retained"

  IO.println
    s!"NATIVE_LAZY_CLOSURE_PASS actual_rows={finalRecords.length} open_scheduled={scheduledAfterIds.length} original={original.token} replacement={replacement.token} dependent_2025={closure2025.length} dependent_2027={closure2027.length}; genuine Actual corrections and Scheduled completion dependency preserved"

end Loam.Tools.NativeAnnualReadProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualReadProbe.run args
