import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/--
One explicit claim that a remembered Event supplies a corrected interpretation
of another remembered Event.

Both endpoints remain ordinary `EventId` values. The relation does not mutate,
remove, or reclassify either Event, and it assigns no arrival-order authority.
Repeated and competing corrections are admitted only by later Application
frontier boundaries rather than by this raw value.
-/
structure EventCorrection where
  target : EventId
  replacement : EventId
deriving Repr, DecidableEq

/--
A read-only projection that keeps both the original observation and the Event
offered as its corrected interpretation, together with the explicit correction
fact that connects them.

This is retained only for consumers that need to inspect one raw correction's
closed endpoints. Current multi-correction authority is derived separately by
Application correction-frontier semantics.
-/
structure CorrectedEvent where
  correction : EventCorrection
  original : Event
  effective : Event

namespace EventCorrection

/--
Project one raw correction only when both endpoint Events are present in the
same Event memory.

This function establishes endpoint closure only. It does not make the edge a
current frontier, choose among competing corrections, infer chronology, or
assign authority from representation order.
-/
def project? (memory : EventMemory) (correction : EventCorrection) : Option CorrectedEvent := do
  let original ← EventMemory.findById? memory correction.target
  let effective ← EventMemory.findById? memory correction.replacement
  return { correction := correction, original := original, effective := effective }

/--
Correction endpoint projection inherits EventMemory's representation-order
independence. Reordering remembered Events cannot change either selected
endpoint.
-/
theorem project?_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (correction : EventCorrection) :
    project? left correction = project? right correction := by
  unfold project?
  rw [EventMemory.findById?_perm left right hPerm correction.target]
  rw [EventMemory.findById?_perm left right hPerm correction.replacement]

/-- A correction cannot project from an Event memory containing no endpoints. -/
@[simp] theorem project?_empty (correction : EventCorrection) :
    project? { events := [], idNodup := by simp } correction = none := by
  simp [project?]

end EventCorrection

end Loam.Core
