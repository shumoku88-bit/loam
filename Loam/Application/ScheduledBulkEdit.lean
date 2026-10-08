import Loam.Review.ScheduledCoverageSelector
import Loam.Publisher.ScheduledReplacementPublisher

namespace Loam.ScheduledBulkEdit

open Loam.Core

set_option autoImplicit false

/-!
# Reviewed Scheduled bulk editing

Similarity is advisory, not retained recurrence or contract identity. The caller
chooses exact Scheduled IDs before constructing ordinary replacement drafts.
No selection, period, amount template, or series membership is persisted.
-/

abbrev Record := Loam.ScheduledReview.Record

/-- Same Measure and signed Locus sets, deliberately independent of amount/date. -/
def candidates
    (snapshot : Loam.ScheduledReview.EvidenceSnapshot)
    (source : Record) : Except String (List Record) := do
  let shape := Loam.ScheduledCoverageSelector.ofRecord source
  if !shape.usable then
    throw "loam: Scheduled candidate source needs both signed Locus sides"
  let records ← Loam.ScheduledReview.orderedCurrentOpenRecords snapshot
  return records.filter fun record =>
    record.measure == source.measure &&
      Loam.ScheduledCoverageSelector.ofRecord record == shape

/-- Explicit inclusive date bounds; absent upper bound means all retained later dates. -/
def inPeriod (record : Record) (fromDate throughDate : String) : Bool :=
  decide (fromDate <= record.scheduledOn) &&
    (throughDate.isEmpty || decide (record.scheduledOn <= throughDate))

def validatePeriod (fromDate throughDate : String) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate fromDate then
    throw "Enter a real YYYY-MM-DD start date."
  if !throughDate.isEmpty && !Loam.ActualDate.validIsoDate throughDate then
    throw "Enter a real YYYY-MM-DD end date, or leave it empty."
  if !throughDate.isEmpty && decide (throughDate < fromDate) then
    throw "End date must not precede start date."

/-- Uniform amount editing never guesses how split postings should be allocated. -/
def simpleAmount? (record : Record) : Option Int := do
  let [first, second] := record.movement.changes | none
  if first.coordinate == second.coordinate then none
  else if first.quantity.quanta < 0 && second.quantity.quanta > 0 then
    some second.quantity.quanta
  else if second.quantity.quanta < 0 && first.quantity.quanta > 0 then
    some first.quantity.quanta
  else none

/-- Keep exact date, Measure, posting order and Loci; change both balanced sides. -/
def withAmount (record : Record) (amount : Int) :
    Except String Loam.ScheduledReplacementPublisher.Draft := do
  if amount <= 0 then
    throw "Enter a positive amount."
  let some _ := simpleAmount? record
    | throw (record.id.token ++ ": split postings require explicit individual editing; no allocation was guessed.")
  let changes := record.movement.changes.map fun change =>
    { change with quantity := Quantity.ofQuanta (if change.quantity.quanta < 0 then -amount else amount) }
  let some movement := BalancedMovement.ofChanges? record.measure changes
    | throw "Scheduled amount change does not balance."
  return { source := record.id, scheduledOn := record.scheduledOn, movement := movement }

/--
Resolve only explicitly selected IDs. Unchanged amounts produce no replacement
facts. A missing, duplicated or unsupported selection is refused, not truncated.
-/
def amountDrafts
    (records : List Record) (selected : List ScheduledId) (amount : Int) :
    Except String (List Loam.ScheduledReplacementPublisher.Draft) := do
  if selected.isEmpty then throw "Check at least one candidate."
  if !(decide selected.Nodup) then throw "A candidate may be selected only once."
  let mut drafts := []
  for id in selected do
    let some record := records.find? fun record => record.id == id
      | throw "Selected candidate is outside the reviewed period."
    let draft ← withAmount record amount
    if simpleAmount? record != some amount then
      drafts := drafts ++ [draft]
  if drafts.isEmpty then throw "Selected amounts are already unchanged. Nothing to publish."
  return drafts

end Loam.ScheduledBulkEdit
