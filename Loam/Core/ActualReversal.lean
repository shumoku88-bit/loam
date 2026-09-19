import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/--
One explicit claim that a retained Actual Event is reversed by another retained
Event whose physical Effects are its exact inverse.

This relation is not a correction. Both endpoints remain historical facts and
both remain part of physical quantity accumulation. It preserves the answer
"which Actual does this inverse movement reverse?" without deriving that answer
from signs, descriptions, dates, endpoint shape, or temporal ordering.
-/
structure ActualReversal where
  target : EventId
  reversal : EventId
deriving Repr, DecidableEq

namespace ActualReversal

/-- Remove the first physical match (locus, measure, quantity) from an Effect list. -/
private def removeFirstPhysicalMatch
    (locus : LocusId) (measure : MeasureId) (quantity : Quantity) :
    List Effect → Option (List Effect)
  | [] => none
  | e :: rest =>
      if e.locus = locus ∧ e.measure = measure ∧ e.quantity = quantity then
        some rest
      else
        match removeFirstPhysicalMatch locus measure quantity rest with
        | some tail => some (e :: tail)
        | none => none

/--
Check whether the physical Effects of two Events form an exact inverse multiset
of (locus, measure, quantity) triples. EffectKey and list ordering are ignored.
-/
def exactPhysicalInverse? (target reversal : List Effect) : Bool :=
  let rec matchAll (remainingTarget : List Effect) (remainingReversal : List Effect) : Bool :=
    match remainingTarget with
    | [] => remainingReversal.isEmpty
    | e :: rest =>
        match removeFirstPhysicalMatch e.locus e.measure (-e.quantity) remainingReversal with
        | some updatedReversal => matchAll rest updatedReversal
        | none => false
  matchAll target reversal

end ActualReversal

/--
Complete retained Actual-reversal relation evidence.

List order is representation only. One target may be reversed at most once and
one reversal Event may explain at most one target. Target and reversal endpoint
roles are disjoint, so one Event cannot participate on both sides of retained
reversal evidence. Referential closure and exact inverse-Effect validation remain
publisher/read admission obligations because relation-first interrupted
publication may temporarily name an absent reversal Event.
-/
structure ActualReversalMemory where
  reversals : List ActualReversal
  targetNodup : (reversals.map ActualReversal.target).Nodup
  reversalNodup : (reversals.map ActualReversal.reversal).Nodup
  endpointDisjoint :
    List.Disjoint
      (reversals.map ActualReversal.target)
      (reversals.map ActualReversal.reversal)

namespace ActualReversalMemory

/-- Admit only endpoint-functional, role-disjoint raw reversal evidence. -/
def ofReversals? (reversals : List ActualReversal) : Option ActualReversalMemory :=
  if hTarget : (reversals.map ActualReversal.target).Nodup then
    if hReversal : (reversals.map ActualReversal.reversal).Nodup then
      if hDisjoint :
          List.Disjoint
            (reversals.map ActualReversal.target)
            (reversals.map ActualReversal.reversal) then
        some {
          reversals := reversals
          targetNodup := hTarget
          reversalNodup := hReversal
          endpointDisjoint := hDisjoint
        }
      else
        none
    else
      none
  else
    none

/-- Empty reversal authority is valid explicit evidence. -/
def empty : ActualReversalMemory :=
  {
    reversals := []
    targetNodup := by simp
    reversalNodup := by simp
    endpointDisjoint := by
      intro event hTarget
      simp at hTarget
  }

/-- Find the unique retained relation for one target Actual. -/
def findByTarget? (memory : ActualReversalMemory) (target : EventId) : Option ActualReversal :=
  memory.reversals.find? fun relation => decide (relation.target = target)

/-- Find the unique retained relation explained by one reversal Event. -/
def findByReversal? (memory : ActualReversalMemory) (reversal : EventId) : Option ActualReversal :=
  memory.reversals.find? fun relation => decide (relation.reversal = reversal)

/-- Whether one Event participates as either endpoint of retained Reversal evidence. -/
def mentionsEvent (memory : ActualReversalMemory) (event : EventId) : Bool :=
  (memory.findByTarget? event).isSome || (memory.findByReversal? event).isSome

/--
Insert one relation without revalidating the already-proven memory.

List order is representation only, so successful insertion prepends the relation.
Only the two new endpoints are checked against retained endpoint roles; the
existing Nodup and endpoint-disjointness proofs are reused constructively.
-/
def add? (memory : ActualReversalMemory) (relation : ActualReversal) : Option ActualReversalMemory :=
  if hSelf : relation.target = relation.reversal then
    none
  else if hTarget : relation.target ∈ memory.reversals.map ActualReversal.target then
    none
  else if hReversal : relation.reversal ∈ memory.reversals.map ActualReversal.reversal then
    none
  else if hTargetAsReversal :
      relation.target ∈ memory.reversals.map ActualReversal.reversal then
    none
  else if hReversalAsTarget :
      relation.reversal ∈ memory.reversals.map ActualReversal.target then
    none
  else
    some {
      reversals := relation :: memory.reversals
      targetNodup := by
        simpa using And.intro hTarget memory.targetNodup
      reversalNodup := by
        simpa using And.intro hReversal memory.reversalNodup
      endpointDisjoint := by
        intro event hTargetMem hReversalMem
        simp only [List.map_cons, List.mem_cons] at hTargetMem hReversalMem
        rcases hTargetMem with hEventTarget | hOldTarget
        · subst event
          rcases hReversalMem with hTargetReversal | hOldReversal
          · exact hSelf hTargetReversal
          · exact hTargetAsReversal hOldReversal
        · rcases hReversalMem with hEventReversal | hOldReversal
          · subst event
            exact hReversalAsTarget hOldTarget
          · exact memory.endpointDisjoint hOldTarget hOldReversal
    }

end ActualReversalMemory

end Loam.Core
