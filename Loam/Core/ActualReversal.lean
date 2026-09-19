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

/--
Flatten retained reversal relations to their endpoint identities.

The order is representation only: each relation contributes its target followed
by its reversal endpoint.
-/
def endpointIds (reversals : List ActualReversal) : List EventId :=
  reversals.flatMap fun relation => [relation.target, relation.reversal]

end ActualReversal

/--
Complete retained Actual-reversal relation evidence.

List order is representation only. Every retained endpoint identity is globally
unique across both roles: one Event cannot be used twice as a target, twice as a
reversal, or once in each role. This excludes self-reversal, reversal chains,
and reversal cycles at the Core memory boundary.

Referential closure and exact inverse-Effect validation remain publisher/read
admission obligations because relation-first interrupted publication may
temporarily name an absent reversal Event.
-/
structure ActualReversalMemory where
  reversals : List ActualReversal
  endpointNodup : (ActualReversal.endpointIds reversals).Nodup

namespace ActualReversalMemory

/-- Admit only raw reversal evidence whose endpoint identities are globally unique. -/
def ofReversals? (reversals : List ActualReversal) : Option ActualReversalMemory :=
  if hEndpoints : (ActualReversal.endpointIds reversals).Nodup then
    some { reversals := reversals, endpointNodup := hEndpoints }
  else
    none

/-- Empty reversal authority is valid explicit evidence. -/
def empty : ActualReversalMemory :=
  { reversals := [], endpointNodup := by simp [ActualReversal.endpointIds] }

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
The two new endpoint identities are checked against the retained endpoint list;
the existing global endpoint uniqueness proof is then reused constructively.
-/
def add? (memory : ActualReversalMemory) (relation : ActualReversal) : Option ActualReversalMemory :=
  if hSelf : relation.target = relation.reversal then
    none
  else if hTarget :
      relation.target ∈ ActualReversal.endpointIds memory.reversals then
    none
  else if hReversal :
      relation.reversal ∈ ActualReversal.endpointIds memory.reversals then
    none
  else
    some {
      reversals := relation :: memory.reversals
      endpointNodup := by
        simp [ActualReversal.endpointIds, hSelf, hTarget, hReversal, memory.endpointNodup]
    }

end ActualReversalMemory

end Loam.Core
