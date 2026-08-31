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

/--
Project a correction only when it directly targets the supplied current
interpretation tip.

The tip is explicit input rather than inferred from EventMemory representation
order. This is the practical admission primitive suggested by Observation 021:
a repeated correction may continue the current interpretation, while a stale
correction that targets an earlier interpretation does not silently become
current merely because it was observed later.
-/
def projectFromTip?
    (memory : EventMemory)
    (tip : EventId)
    (correction : EventCorrection) : Option CorrectedEvent :=
  if correction.target = tip then
    project? memory correction
  else
    none

/-- Matching the current tip adds no meaning beyond ordinary correction projection. -/
theorem projectFromTip?_current
    (memory : EventMemory)
    (tip : EventId)
    (correction : EventCorrection)
    (hTarget : correction.target = tip) :
    projectFromTip? memory tip correction = project? memory correction := by
  simp [projectFromTip?, hTarget]

/-- A stale correction cannot continue a different current interpretation tip. -/
@[simp] theorem projectFromTip?_stale
    (memory : EventMemory)
    (tip : EventId)
    (correction : EventCorrection)
    (hTarget : correction.target ≠ tip) :
    projectFromTip? memory tip correction = none := by
  simp [projectFromTip?, hTarget]

/-- Successful current-tip projection certifies that the correction named that tip. -/
theorem projectFromTip?_some_target
    (memory : EventMemory)
    (tip : EventId)
    (correction : EventCorrection)
    (projected : CorrectedEvent)
    (hProjected : projectFromTip? memory tip correction = some projected) :
    correction.target = tip := by
  unfold projectFromTip? at hProjected
  split at hProjected
  next hTarget => exact hTarget
  next hTarget => simp at hProjected

/--
Try one repeated correction after an already projected correction.

Only the prior projection's effective Event identity is accepted as the next
target. The structure therefore earns a linear continuation without declaring
list order, arrival time, or `last correction wins` to be authoritative.
-/
def projectNext?
    (memory : EventMemory)
    (current : CorrectedEvent)
    (next : EventCorrection) : Option CorrectedEvent :=
  projectFromTip? memory current.effective.id next

/-- A repeated correction aimed behind the current effective Event is rejected. -/
@[simp] theorem projectNext?_stale
    (memory : EventMemory)
    (current : CorrectedEvent)
    (next : EventCorrection)
    (hTarget : next.target ≠ current.effective.id) :
    projectNext? memory current next = none := by
  simp [projectNext?, hTarget]

/-- Current-tip admission remains independent of EventMemory representation order. -/
theorem projectFromTip?_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (tip : EventId)
    (correction : EventCorrection) :
    projectFromTip? left tip correction = projectFromTip? right tip correction := by
  by_cases hTarget : correction.target = tip
  · simp [projectFromTip?, hTarget, project?_perm left right hPerm correction]
  · simp [projectFromTip?, hTarget]

end EventCorrection

end Loam.Core
