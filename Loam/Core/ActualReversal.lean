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

/--
The physical part of one Effect used by reversal semantics.

EffectKey is intentionally excluded: exact physical inversion concerns locus,
measure, and exact signed quantity only.
-/
structure PhysicalEffect where
  locus : LocusId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/-- Forget Effect identity while retaining its physical coordinates and quantity. -/
def physicalEffect (effect : Effect) : PhysicalEffect :=
  {
    locus := effect.locus
    measure := effect.measure
    quantity := effect.quantity
  }

/-- Exact additive inverse of one physical Effect. -/
def inversePhysical (effect : PhysicalEffect) : PhysicalEffect :=
  { effect with quantity := -effect.quantity }

/-- Project an Effect list to the physical multiset represented by list permutation. -/
def physicalEffects (effects : List Effect) : List PhysicalEffect :=
  effects.map physicalEffect

@[simp] theorem inversePhysical_involutive (effect : PhysicalEffect) :
    inversePhysical (inversePhysical effect) = effect := by
  cases effect with
  | mk locus measure quantity =>
      cases quantity with
      | mk quanta =>
          simp [inversePhysical, Quantity.neg]

/--
Check whether two Effect collections are exact physical inverses.

The relation is equality of physical multisets up to additive inversion:
EffectKey and list ordering are ignored, while duplicate multiplicity is retained.
-/
def exactPhysicalInverse? (target reversal : List Effect) : Bool :=
  decide (
    (physicalEffects target).Perm
      ((physicalEffects reversal).map inversePhysical))

/-- Logical characterization of the executable exact-inverse check. -/
theorem exactPhysicalInverse?_eq_true_iff
    (target reversal : List Effect) :
    exactPhysicalInverse? target reversal = true ↔
      (physicalEffects target).Perm
        ((physicalEffects reversal).map inversePhysical) := by
  simp [exactPhysicalInverse?]

/--
Exact physical inversion is symmetric.

If reversal is the physical inverse of target, then target is the physical
inverse of reversal; the executable check therefore gives the same Bool in
either direction.
-/
theorem exactPhysicalInverse?_symm (target reversal : List Effect) :
    exactPhysicalInverse? target reversal =
      exactPhysicalInverse? reversal target := by
  rw [Bool.eq_iff_iff]
  simp only [exactPhysicalInverse?_eq_true_iff]
  constructor
  · intro h
    have hMapped := h.symm.map inversePhysical
    simpa [List.map_map] using hMapped
  · intro h
    have hMapped := h.symm.map inversePhysical
    simpa [List.map_map] using hMapped

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
        change
          (relation.target :: relation.reversal ::
            ActualReversal.endpointIds memory.reversals).Nodup
        have hTargetFresh :
            relation.target ∉
              relation.reversal :: ActualReversal.endpointIds memory.reversals := by
          simp [hSelf, hTarget]
        simpa using
          And.intro hTargetFresh (And.intro hReversal memory.endpointNodup)
    }

end ActualReversalMemory

end Loam.Core
