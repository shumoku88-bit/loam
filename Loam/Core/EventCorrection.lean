import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/--
Stable identity for one explicit correction relation.

The token identifies the correction fact itself. It does not encode chronology,
authority, reason, event kind, or accounting meaning.
-/
structure EventCorrectionId where
  token : String
deriving Repr, DecidableEq

/--
One explicit claim that a remembered Event supplies a corrected interpretation
of another remembered Event.

Both endpoints remain ordinary `EventId` values. The relation does not mutate,
remove, or reclassify either Event, and it assigns no arrival-order authority.
Repeated correction, competing corrections, and conflict resolution are not
admitted or rejected by this value alone; those require a collection-level law
that has not yet been introduced into the practical core.
-/
structure EventCorrection where
  id : EventCorrectionId
  target : EventId
  replacement : EventId
deriving Repr, DecidableEq

/--
A read-only projection that keeps both the original observation and the Event
currently offered as its corrected interpretation, together with the explicit
correction fact that connects them.

Keeping both Events is intentional: the effective Event alone cannot explain
whether its meaning was original or reached through correction.
-/
structure CorrectedEvent where
  correction : EventCorrection
  original : Event
  effective : Event

namespace EventCorrection

/--
Project one correction only when both endpoint Events are present in the same
Event memory.

This is deliberately the single-correction boundary from Observation 020. It
is not a `last correction wins` rule, does not inspect list position, and does
not yet construct a correction chain or conflict frontier.
-/
def project? (memory : EventMemory) (correction : EventCorrection) : Option CorrectedEvent := do
  let original ← EventMemory.findById? memory correction.target
  let effective ← EventMemory.findById? memory correction.replacement
  return { correction := correction, original := original, effective := effective }

/--
Correction projection inherits EventMemory's representation-order independence.
Reordering the remembered Events cannot change either endpoint selected by a
stable correction relation.
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
