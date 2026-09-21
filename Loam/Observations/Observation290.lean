import Loam.Core.EventMemory
import Loam.PracticalMovement

namespace Loam.Observation290

open Loam.Core

set_option autoImplicit false

/-!
# Observation 290 — spin-off turns lot continuity into a branching provenance graph

Observation 289 showed a one-to-one stock-split lineage:

```text
acquisition Effect
    -> transformed Effect
```

That is still only a path.

This observation applies a one-to-many corporate-action pressure:

> Can one acquisition origin continue into two independently held securities
> without introducing a first-class Lot identity?

The selected spin-off specimen is deliberately small:

```text
acquisition
  +4 old-parent

spin-off
  -4 old-parent
  +4 parent
  +2 child
```

The physical Event records only the exact quantity transformation.

The selected continuity claim is separate:

```text
origin acquisition
  -> parent branch
  -> child branch
```

Acquisition basis begins as one total 1,200 JPY basis at the origin. A separate
basis-allocation observation assigns:

```text
parent 900
child  300
```

This observation tests two different questions:

1. Is branching identity/provenance representable as edges between existing
   Effect anchors?
2. Does lineage alone determine basis allocation?

The expected answers are YES and NO respectively.
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩

private def oldParent : MeasureId := ⟨"parent-before-spinoff"⟩
private def parent : MeasureId := ⟨"parent-after-spinoff"⟩
private def child : MeasureId := ⟨"child-after-spinoff"⟩

private def acquisitionId : EventId := ⟨"spinoff-origin-acquisition"⟩
private def spinoffId : EventId := ⟨"spinoff-event"⟩

private def acquisitionKey : EffectKey := ⟨"origin-held"⟩
private def retiredKey : EffectKey := ⟨"retired-old-parent"⟩
private def parentKey : EffectKey := ⟨"new-parent-held"⟩
private def childKey : EffectKey := ⟨"new-child-held"⟩

private def acquisition? : Option Event :=
  Event.ofEffects? acquisitionId [
    Effect.ofQuantity
      acquisitionKey broker oldParent (Quantity.ofQuanta 4),
    Effect.ofAnonymousQuantity
      outside oldParent (Quantity.ofQuanta (-4))
  ]

private def spinoff? : Option Event :=
  Event.ofEffects? spinoffId [
    Effect.ofQuantity
      retiredKey broker oldParent (Quantity.ofQuanta (-4)),
    Effect.ofQuantity
      parentKey broker parent (Quantity.ofQuanta 4),
    Effect.ofQuantity
      childKey broker child (Quantity.ofQuanta 2)
  ]

private def physicalMemory? : Option EventMemory := do
  let acquisition ← acquisition?
  let spinoff ← spinoff?
  EventMemory.ofEvents? [acquisition, spinoff]

theorem physical_spinoff_quantities_are_retained :
    (do
      let memory ← physicalMemory?
      pure (
        (EventMemory.quantityAtRecorded memory broker oldParent).quanta,
        (EventMemory.quantityAtRecorded memory broker parent).quanta,
        (EventMemory.quantityAtRecorded memory broker child).quanta)) =
      some (0, 4, 2) := by
  native_decide

private def ordinarySpinoffMovementRefused : Bool :=
  match spinoff? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofSingleMeasureEffects? event.effects).isNone

theorem spinoff_is_not_an_ordinary_same_measure_movement :
    ordinarySpinoffMovementRefused = true := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def originAnchor : EffectAnchor :=
  ⟨acquisitionId, acquisitionKey⟩

private def retiredAnchor : EffectAnchor :=
  ⟨spinoffId, retiredKey⟩

private def parentAnchor : EffectAnchor :=
  ⟨spinoffId, parentKey⟩

private def childAnchor : EffectAnchor :=
  ⟨spinoffId, childKey⟩

private def findEffect?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← EventMemory.findById? memory anchor.event
  event.effects.find? fun effect => effect.key = some anchor.effect

private def anchoredQuantity?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option (MeasureId × Int) := do
  let effect ← findEffect? memory anchor
  pure (effect.measure, effect.quantity.quanta)

/--
One observation-local provenance edge.

The edge carries no basis amount and no generic corporate-action meaning. It
states only that one current Effect continues one acquisition origin.
-/
structure LineageEdge where
  origin : EffectAnchor
  current : EffectAnchor
deriving Repr, DecidableEq

private def parentEdge : LineageEdge :=
  ⟨originAnchor, parentAnchor⟩

private def childEdge : LineageEdge :=
  ⟨originAnchor, childAnchor⟩

private def lineageEdges : List LineageEdge :=
  [parentEdge, childEdge]

private def lineageEdgeAdmitted?
    (memory : EventMemory)
    (edge : LineageEdge) : Bool :=
  match anchoredQuantity? memory edge.origin,
        anchoredQuantity? memory edge.current with
  | some (originMeasure, originQuantity),
      some (currentMeasure, currentQuantity) =>
      originMeasure = oldParent &&
      originQuantity = 4 &&
      currentMeasure != oldParent &&
      currentQuantity > 0
  | _, _ => false

theorem one_origin_can_branch_to_two_current_effects :
    (do
      let memory ← physicalMemory?
      pure (
        lineageEdgeAdmitted? memory parentEdge,
        lineageEdgeAdmitted? memory childEdge,
        parentEdge.origin = childEdge.origin,
        parentEdge.current != childEdge.current)) =
      some (true, true, true, true) := by
  native_decide

private def descendants
    (edges : List LineageEdge)
    (origin : EffectAnchor) : List EffectAnchor :=
  edges.filterMap fun edge =>
    if edge.origin = origin then some edge.current else none

theorem branching_lineage_exposes_both_current_descendants :
    descendants lineageEdges originAnchor =
      [parentAnchor, childAnchor] := by
  native_decide

/--
The physical EventMemory does not determine lineage.

The same quantities can exist with no acquisition-continuity claim at all.
-/
private def lineageKnown
    (memory : EventMemory)
    (edges : List LineageEdge)
    (origin current : EffectAnchor) : Bool :=
  edges.any fun edge =>
    decide (edge.origin = origin) &&
    decide (edge.current = current) &&
    lineageEdgeAdmitted? memory edge

theorem same_physical_history_different_lineage_changes_continuity_answer :
    (do
      let memory ← physicalMemory?
      pure (
        lineageKnown memory [] originAnchor childAnchor,
        lineageKnown memory lineageEdges originAnchor childAnchor)) =
      some (false, true) := by
  native_decide

/--
Origin acquisition basis.
-/
structure BasisEvidence where
  acquisition : EffectAnchor
  totalBasisJpy : Int
deriving Repr, DecidableEq

private def originBasis : BasisEvidence := {
  acquisition := originAnchor
  totalBasisJpy := 1200
}

/--
Separate branch allocation of the origin basis.

Lineage answers "which branch continues which origin".
BasisAllocation answers "how much basis moved to each branch".

Those are not the same information.
-/
structure BasisAllocation where
  origin : EffectAnchor
  current : EffectAnchor
  basisJpy : Int
deriving Repr, DecidableEq

private def allocation90_30 : List BasisAllocation := [
  ⟨originAnchor, parentAnchor, 900⟩,
  ⟨originAnchor, childAnchor, 300⟩
]

private def allocation60_60 : List BasisAllocation := [
  ⟨originAnchor, parentAnchor, 600⟩,
  ⟨originAnchor, childAnchor, 600⟩
]

private def allocatedBasisTotal
    (allocations : List BasisAllocation)
    (origin : EffectAnchor) : Int :=
  allocations.foldl
    (fun total row =>
      if row.origin = origin then total + row.basisJpy else total)
    0

private def basisAt?
    (allocations : List BasisAllocation)
    (current : EffectAnchor) : Option Int := do
  let row ← allocations.find? fun item => item.current = current
  pure row.basisJpy

private def allocationAdmitted?
    (originBasis : BasisEvidence)
    (edges : List LineageEdge)
    (allocations : List BasisAllocation) : Bool :=
  allocatedBasisTotal allocations originBasis.acquisition =
      originBasis.totalBasisJpy &&
  allocations.all fun allocation =>
    edges.any fun edge =>
      decide (edge.origin = allocation.origin) &&
      decide (edge.current = allocation.current)

/--
Two different basis-allocation worlds can share the exact same physical history
and exact same provenance graph.
-/
theorem lineage_graph_does_not_determine_basis_allocation :
    allocationAdmitted? originBasis lineageEdges allocation90_30 = true ∧
    allocationAdmitted? originBasis lineageEdges allocation60_60 = true ∧
    basisAt? allocation90_30 parentAnchor = some 900 ∧
    basisAt? allocation60_60 parentAnchor = some 600 := by
  native_decide

private def unrealisedGain?
    (allocations : List BasisAllocation)
    (current : EffectAnchor)
    (marketValueJpy : Int) : Option Int := do
  let basis ← basisAt? allocations current
  pure (marketValueJpy - basis)

theorem same_physical_graph_and_market_value_can_have_different_gain :
    unrealisedGain? allocation90_30 parentAnchor 1500 = some 600 ∧
    unrealisedGain? allocation60_60 parentAnchor 1500 = some 900 := by
  native_decide

/-!
## Finding

The spin-off specimen is the first selected case in this sequence that requires
a genuinely branching continuity shape:

```text
             -> parent Effect
origin Effect
             -> child Effect
```

The physical Event does not determine those edges.

The edges also do not determine basis allocation.

So at least three layers remain distinct:

```text
physical quantity transformation
    Event / Effects

acquisition continuity
    Effect -> Effect provenance graph

basis distribution
    allocation over provenance edges / descendants
```

This is strong evidence against compressing all three meanings into one Lot
record merely because traditional investment systems use that noun.

However it is **not** evidence that first-class Lot identity is useless.

A durable Lot object may still become valuable if future selected queries need
one stable identity independent of all of its changing physical Effect nodes.

What this observation establishes is narrower:

> The first branching corporate-action pressure can be represented as a
> provenance graph over existing Effect identities, with basis allocation kept
> as a separate evidence plane.

Not earned:

- production `LineageEdge` or `BasisAllocation`;
- generic provenance graph infrastructure;
- a production `LotId`;
- corporate-action persistence;
- security-master identity;
- tax basis allocation policy;
- market-price authority;
- repeated/nested corporate-action transitive closure;
- merger many-to-one lineage;
- correction/conflict rules for lineage or allocations.

A future pressure should introduce a *many-to-one* transformation. If two
independent acquisition origins merge into one current physical Effect while
remaining separately observable for basis / holding-period questions, that is
the strongest next test for whether graph edges remain sufficient or a durable
Lot identity becomes independently necessary.
-/

end Loam.Observation290
