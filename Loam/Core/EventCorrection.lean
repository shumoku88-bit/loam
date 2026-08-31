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
Repeated correction, competing corrections, and conflict projection are handled
by later collection and projection boundaries rather than by this raw value.
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

/--
A truthful current view in which several distinct correction branches remain
simultaneously possible.

`branches` is a deterministic representation only. Its list position carries
no arrival, temporal, priority, or authority meaning. Every branch targets the
same interpretation, correction identity is not repeated, and replacement
Event identity is not repeated. At least two candidate interpretations are
present, so this value deliberately exposes no single `effective` Event.
-/
structure UnresolvedCorrection where
  target : EventId
  branches : List EventCorrection
  branchIdNodup : (branches.map EventCorrection.id).Nodup
  branchTarget : ∀ branch ∈ branches, branch.target = target
  candidateIdNodup : (branches.map EventCorrection.replacement).Nodup
  multiple : 2 ≤ branches.length

namespace UnresolvedCorrection

/-- Candidate interpretation identities, retaining only representation order. -/
def candidateIds (conflict : UnresolvedCorrection) : List EventId :=
  conflict.branches.map EventCorrection.replacement

/-- Candidate identity is not repeated inside an unresolved correction view. -/
theorem candidateIds_nodup (conflict : UnresolvedCorrection) :
    (candidateIds conflict).Nodup := by
  simpa [candidateIds] using conflict.candidateIdNodup

/-- An unresolved correction view always contains at least two candidates. -/
theorem candidateIds_multiple (conflict : UnresolvedCorrection) :
    2 ≤ (candidateIds conflict).length := by
  simpa [candidateIds] using conflict.multiple

/--
Reordering the represented correction branches only reorders the represented
candidate identities. It cannot choose a current winner.
-/
theorem candidateIds_perm
    (left right : UnresolvedCorrection)
    (hPerm : left.branches.Perm right.branches) :
    (candidateIds left).Perm (candidateIds right) := by
  exact hPerm.map EventCorrection.replacement

end UnresolvedCorrection

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

/--
Project two sibling corrections as an unresolved current state.

Both correction facts must directly target the same explicit interpretation,
both replacement Events must be present in memory, correction identity must be
distinct, and replacement Event identity must be distinct. No branch is chosen
as effective. The returned branch list is representation only; callers that
care about candidate meaning should treat it modulo permutation.
-/
def projectSiblingConflict?
    (memory : EventMemory)
    (tip : EventId)
    (left right : EventCorrection) : Option UnresolvedCorrection :=
  if hLeftTarget : left.target = tip then
    if hRightTarget : right.target = tip then
      if hBranchId : left.id ≠ right.id then
        if hCandidateId : left.replacement ≠ right.replacement then
          match project? memory left, project? memory right with
          | some _, some _ =>
              some {
                target := tip
                branches := [left, right]
                branchIdNodup := by simp [hBranchId]
                branchTarget := by
                  intro branch hBranch
                  simp only [List.mem_cons, List.not_mem_nil, or_false] at hBranch
                  rcases hBranch with rfl | rfl
                  · exact hLeftTarget
                  · exact hRightTarget
                candidateIdNodup := by simp [hCandidateId]
                multiple := by simp
              }
          | _, _ => none
        else
          none
      else
        none
    else
      none
  else
    none

end EventCorrection

end Loam.Core
