import Loam.Tests.IncrementalDailyDelta
import Loam.Review.ActualReview
import Loam.Application.CorrectionFrontier
import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Tests.IncrementalCorrectedFrontier

open Loam.Core
open Loam.Tests.IncrementalDailyDelta

set_option autoImplicit false

/-!
Bridge a *qualified* Actual read to the narrow arithmetic delta law.

The only correction/currentness selector comes from ActualReview.Record.isCurrent,
which in turn comes from the existing admitted Actual image. There is no new
EventCorrection parser or frontier interpretation here.

These are coordinate quantities, not expenses. AccountingRole, routing, payment
lifecycle, and other report-specific selectors stay with their current owners.
-/

/--
Extract one (day, Measure) signed contribution per current Event at an explicitly
chosen Locus/Measure coordinate.

Refuse if a current Event contributes a nonzero quantity but has no occurrence
date. An undated value must never quietly become a zero-valued report row.
-/
def selectedRows?
    (coordinate : EffectCoordinate)
    (records : List Loam.ActualReview.Record) : Option (List Contribution) := do
  let rowsRev ← records.foldlM (init := ([] : List Contribution)) fun acc record => do
    if !record.isCurrent then
      return acc
    let quanta :=
      (Event.quantityAt record.event coordinate.locus coordinate.measure).quanta
    if quanta == 0 then
      return acc
    let day ← record.date
    return { bucket := { day := day, measure := coordinate.measure.token },
             signedQuanta := quanta } :: acc
  return rowsRev.reverse

/--
An admitted source transition supplying a single changed selected contribution
may use the original delta law. The hypotheses require *both* source projections
to succeed and the unchanged contributions to match exactly. No unknown value is
converted to zero, and no raw correction is treated as automatically admissible.
-/
theorem qualified_single_replacement
    (coordinate : EffectCoordinate)
    (oldRecords newRecords : List Loam.ActualReview.Record)
    (bucket : Bucket)
    (beforeRows afterRows : List Contribution)
    (removed added : Contribution)
    (hOld : selectedRows? coordinate oldRecords =
      some (beforeRows ++ removed :: afterRows))
    (hNew : selectedRows? coordinate newRecords =
      some (beforeRows ++ added :: afterRows)) :
    (selectedRows? coordinate oldRecords).map
      (fun rows => afterReplacement bucket (recompute bucket rows) removed added)
      =
    (selectedRows? coordinate newRecords).map (recompute bucket) := by
  rw [hOld, hNew]
  exact congrArg some
    (replacement_equivalence bucket beforeRows afterRows removed added)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def makeEvent (id : String) (measure : MeasureId) (amount : Int) : IO Event :=
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      Effect.ofAnonymousQuantity ⟨"bank"⟩ measure (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ measure (Quantity.ofQuanta amount)
    ]) "test Event failed local admission"

private def makeEvidence
    (events : List Event)
    (dates : List (ActualValidityFact String))
    (corrections : List EventCorrection) : IO Loam.ActualEvidence := do
  let events ← requireSome (EventMemory.ofEvents? events) "EventMemory admission failed"
  let validity ← requireSome (ActualValidityHistory.ofParts? dates [])
    "ActualValidityHistory admission failed"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? corrections)
    "EventCorrectionMemory admission failed"
  return { Loam.ActualEvidence.empty with
    events := events, validity := validity, corrections := corrections }

/-- Two full canonical admissions, followed by independent full-scan and delta checks. -/
def runAll : IO Unit := do
  let jpy : MeasureId := ⟨"jpy"⟩
  let eur : MeasureId := ⟨"eur"⟩
  let jpyFood : EffectCoordinate := ⟨⟨"food"⟩, jpy⟩
  let eurFood : EffectCoordinate := ⟨⟨"food"⟩, eur⟩
  let original ← makeEvent "old" jpy 500
  let replacement ← makeEvent "replacement" jpy 800
  let unaffected ← makeEvent "eur-unaffected" eur 900

  let oldEvidence ← makeEvidence [original, unaffected]
    [.base original.id "2026-10-03",
     .base unaffected.id "2026-10-04"] []
  let newEvidence ← makeEvidence [original, unaffected, replacement]
    [.base original.id "2026-10-03",
     .base unaffected.id "2026-10-04",
     .base replacement.id "2026-10-05"]
    [{ target := original.id, replacement := replacement.id }]

  let oldImage ← requireSome (Loam.Persistence.admitActualImage? oldEvidence)
    "old full Actual admission refused"
  let newImage ← requireSome (Loam.Persistence.admitActualImage? newEvidence)
    "new full Actual admission refused"

  let oldRecords := Loam.ActualReview.recordsFromActualImage oldImage
  let newRecords := Loam.ActualReview.recordsFromActualImage newImage

  -- This fixture is checked against LOAM's own correction frontier, not a new
  -- 'last event wins' or list-order interpretation.
  let oldFrontier ← requireSome
    (Loam.Application.correctionFrontierMemory? oldEvidence.events oldEvidence.corrections)
    "old correction frontier refused"
  let newFrontier ← requireSome
    (Loam.Application.correctionFrontierMemory? newEvidence.events newEvidence.corrections)
    "new correction frontier refused"
  expect
    ((oldRecords.filter Loam.ActualReview.Record.isCurrent).map (fun r => r.event.id) ==
      oldFrontier.events.map Event.id)
    "old ActualReview disagrees with correction frontier"
  expect
    ((newRecords.filter Loam.ActualReview.Record.isCurrent).map (fun r => r.event.id) ==
      newFrontier.events.map Event.id)
    "new ActualReview disagrees with correction frontier"

  let oldRows ← requireSome (selectedRows? jpyFood oldRecords)
    "old JPY date selection refused"
  let newRows ← requireSome (selectedRows? jpyFood newRecords)
    "new JPY date selection refused"

  let oldContribution : Contribution :=
    { bucket := { day := "2026-10-03", measure := "jpy" }, signedQuanta := 500 }
  let newContribution : Contribution :=
    { bucket := { day := "2026-10-05", measure := "jpy" }, signedQuanta := 800 }
  expect (oldRows == [oldContribution]) "old JPY rows unexpectedly differ"
  expect (newRows == [newContribution]) "new JPY correction did not replace old"

  for bucket in [oldContribution.bucket, newContribution.bucket,
      { day := "2026-10-04", measure := "jpy" }] do
    let expected := recompute bucket newRows
    let updated :=
      afterReplacement bucket (recompute bucket oldRows) oldContribution newContribution
    expect (updated == expected)
      s!"delta and full JPY frontier scan disagree at {repr bucket}"

  let oldEur ← requireSome (selectedRows? eurFood oldRecords)
    "old EUR date selection refused"
  let newEur ← requireSome (selectedRows? eurFood newRecords)
    "new EUR date selection refused"
  expect (oldEur == newEur) "JPY correction unexpectedly changed EUR rows"
  expect (recompute { day := "2026-10-04", measure := "eur" } newEur == 900)
    "EUR remained current but quantity changed"

  -- A raw correction with a missing endpoint is not admitted as a current world.
  let malformed ← makeEvidence [original, replacement]
    [.base original.id "2026-10-03", .base replacement.id "2026-10-05"]
    [{ target := ⟨"missing-id"⟩, replacement := replacement.id }]
  expect ((Loam.Persistence.admitActualImage? malformed).isNone)
    "malformed correction was accepted as a qualified Actual image"

  -- A current nonzero quantity without a known date is not a zero row.
  let undated : Loam.ActualReview.Record := {
    event := original, date := none, description := "", replacement := none
  }
  expect ((selectedRows? jpyFood [undated]).isNone)
    "undated current JPY quantity was silently omitted"

  IO.println "qualified corrected frontier / date-Measure delta checks passed"

end Loam.Tests.IncrementalCorrectedFrontier

#eval Loam.Tests.IncrementalCorrectedFrontier.runAll
