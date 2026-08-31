import Loam.Core.EventCorrection

namespace Loam.Core

set_option autoImplicit false

namespace EventCorrection

/--
Project one locus/measure quantity after applying one explicit correction.

Both correction endpoint Events remain recorded facts in `EventMemory`. The
replacement therefore already contributes to `EventMemory.quantityAtRecorded`.
For a correction between distinct Event identities, the effective projection
removes only the superseded target contribution; adding the replacement again
would double-count it.

A degenerate self-relation leaves the recorded aggregate unchanged. This
function does not make such a relation authoritative or meaningful; it merely
avoids inventing a quantity change that the relation does not describe.

This is deliberately a single-correction projection. It does not fold a
correction chain, choose among sibling corrections, apply a conflict resolution,
or infer chronology from EventMemory representation order.
-/
def quantityAtEffective?
    (memory : EventMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let projected ← project? memory correction
  if correction.target = correction.replacement then
    return EventMemory.quantityAtRecorded memory locus measure
  else
    return
      EventMemory.quantityAtRecorded memory locus measure -
        Event.quantityAt projected.original locus measure

/-- A correction with missing endpoint Events has no effective quantity projection. -/
@[simp] theorem quantityAtEffective?_empty
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId) :
    quantityAtEffective? { events := [], idNodup := by simp }
      correction locus measure = none := by
  simp [quantityAtEffective?, project?]

/--
For a successfully projected correction between distinct Event identities, the
single-correction aggregate is exactly the recorded aggregate minus the
superseded target Event's contribution. The replacement is not added again
because it is already a remembered Event.
-/
theorem quantityAtEffective?_distinct
    (memory : EventMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (projected : CorrectedEvent)
    (hProjected : project? memory correction = some projected)
    (hDistinct : correction.target ≠ correction.replacement) :
    quantityAtEffective? memory correction locus measure =
      some
        (EventMemory.quantityAtRecorded memory locus measure -
          Event.quantityAt projected.original locus measure) := by
  simp [quantityAtEffective?, hProjected, hDistinct]

/-- A projected self-relation does not change the recorded aggregate. -/
theorem quantityAtEffective?_self
    (memory : EventMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (projected : CorrectedEvent)
    (hProjected : project? memory correction = some projected)
    (hSelf : correction.target = correction.replacement) :
    quantityAtEffective? memory correction locus measure =
      some (EventMemory.quantityAtRecorded memory locus measure) := by
  simp [quantityAtEffective?, hProjected, hSelf]

/--
Single-correction effective quantity remains independent of EventMemory storage
order. Reordering remembered facts changes neither endpoint lookup nor the
recorded aggregate from which the superseded target is removed.
-/
theorem quantityAtEffective?_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId) :
    quantityAtEffective? left correction locus measure =
      quantityAtEffective? right correction locus measure := by
  unfold quantityAtEffective?
  rw [project?_perm left right hPerm correction]
  rw [EventMemory.quantityAtRecorded_perm left right hPerm locus measure]

end EventCorrection

end Loam.Core
