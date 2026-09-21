import Loam.Core.EventMemory
import Loam.PracticalMovement

namespace Loam.Observation291

open Loam.Core

set_option autoImplicit false

/-!
# Observation 291 — many-to-one merger provenance

Observation 290 established one-to-many branching continuity for a spin-off.

This observation applies the opposite topology:

> Two independently acquired origins merge into one current physical Effect.

Selected specimen:

```text
Acquisition A   +2 old-share   total basis 600 JPY
Acquisition B   +4 old-share   total basis 1,800 JPY

Merger
  -6 old-share
  +3 new-share
```

The merger ratio is therefore two old shares to one new share.

The single current +3 new-share Effect physically aggregates both origins:

```text
A origin -> 1 new-share
B origin -> 2 new-share
```

A later one-share disposal can consume either origin-derived component.

The pressure asks:

1. Is one current physical Effect sufficient as lot identity? Expected: no.
2. Can quantity-bearing provenance edges from each origin to that one current
   Effect preserve the selected basis/gain answers? Expected: yes.
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩

private def oldShare : MeasureId := ⟨"pre-merger-share"⟩
private def newShare : MeasureId := ⟨"post-merger-share"⟩

private def acquisitionAId : EventId := ⟨"merger-origin-a"⟩
private def acquisitionBId : EventId := ⟨"merger-origin-b"⟩
private def mergerId : EventId := ⟨"merger-event"⟩
private def disposalId : EventId := ⟨"merged-share-disposal"⟩

private def acquisitionAKey : EffectKey := ⟨"origin-a-held"⟩
private def acquisitionBKey : EffectKey := ⟨"origin-b-held"⟩
private def retiredKey : EffectKey := ⟨"merged-old-retired"⟩
private def currentKey : EffectKey := ⟨"merged-current-held"⟩
private def disposalKey : EffectKey := ⟨"merged-disposal-held"⟩

private def acquisitionA? : Option Event :=
  Event.ofEffects? acquisitionAId [
    Effect.ofQuantity
      acquisitionAKey broker oldShare (Quantity.ofQuanta 2),
    Effect.ofAnonymousQuantity
      outside oldShare (Quantity.ofQuanta (-2))
  ]

private def acquisitionB? : Option Event :=
  Event.ofEffects? acquisitionBId [
    Effect.ofQuantity
      acquisitionBKey broker oldShare (Quantity.ofQuanta 4),
    Effect.ofAnonymousQuantity
      outside oldShare (Quantity.ofQuanta (-4))
  ]

private def merger? : Option Event :=
  Event.ofEffects? mergerId [
    Effect.ofQuantity
      retiredKey broker oldShare (Quantity.ofQuanta (-6)),
    Effect.ofQuantity
      currentKey broker newShare (Quantity.ofQuanta 3)
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity
      disposalKey broker newShare (Quantity.ofQuanta (-1)),
    Effect.ofAnonymousQuantity
      outside newShare (Quantity.ofQuanta 1)
  ]

private def physicalMemory? : Option EventMemory := do
  let a ← acquisitionA?
  let b ← acquisitionB?
  let merger ← merger?
  let disposal ← disposal?
  EventMemory.ofEvents? [a, b, merger, disposal]

theorem physical_merged_holding_after_disposal_is_two :
    (do
      let memory ← physicalMemory?
      pure (
        (EventMemory.quantityAtRecorded memory broker oldShare).quanta,
        (EventMemory.quantityAtRecorded memory broker newShare).quanta)) =
      some (0, 2) := by
  native_decide

private def ordinaryMergerMovementRefused : Bool :=
  match merger? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofSingleMeasureEffects? event.effects).isNone

theorem merger_is_not_an_ordinary_same_measure_movement :
    ordinaryMergerMovementRefused = true := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def originA : EffectAnchor :=
  ⟨acquisitionAId, acquisitionAKey⟩

private def originB : EffectAnchor :=
  ⟨acquisitionBId, acquisitionBKey⟩

private def current : EffectAnchor :=
  ⟨mergerId, currentKey⟩

private def disposal : EffectAnchor :=
  ⟨disposalId, disposalKey⟩

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
Many-to-one lineage edge.

`currentUnits` records the exact portion of the shared current Effect that
descends from this origin.
-/
structure MergerLineageEdge where
  origin : EffectAnchor
  current : EffectAnchor
  currentUnits : Quantity
deriving Repr, DecidableEq

private def edgeA : MergerLineageEdge := {
  origin := originA
  current := current
  currentUnits := Quantity.ofQuanta 1
}

private def edgeB : MergerLineageEdge := {
  origin := originB
  current := current
  currentUnits := Quantity.ofQuanta 2
}

private def edges : List MergerLineageEdge :=
  [edgeA, edgeB]

private def edgeAdmitted?
    (memory : EventMemory)
    (edge : MergerLineageEdge) : Bool :=
  match anchoredQuantity? memory edge.origin,
        anchoredQuantity? memory edge.current with
  | some (originMeasure, originUnits),
      some (currentMeasure, currentUnits) =>
      originMeasure = oldShare &&
      originUnits > 0 &&
      currentMeasure = newShare &&
      currentUnits = 3 &&
      edge.currentUnits.quanta > 0 &&
      edge.currentUnits.quanta <= currentUnits
  | _, _ => false

private def incomingUnits
    (edges : List MergerLineageEdge)
    (current : EffectAnchor) : Int :=
  edges.foldl
    (fun total edge =>
      if edge.current = current
      then total + edge.currentUnits.quanta
      else total)
    0

theorem two_origins_can_feed_one_current_effect :
    (do
      let memory ← physicalMemory?
      pure (
        edgeAdmitted? memory edgeA,
        edgeAdmitted? memory edgeB,
        edgeA.origin != edgeB.origin,
        edgeA.current = edgeB.current,
        incomingUnits edges current)) =
      some (true, true, true, true, 3) := by
  native_decide

/--
The shared current Effect identity does not tell us whether its first new-share
unit descends from A or B.

The same physical Effect is compatible with both selected source answers.
-/
structure BasisEvidence where
  acquisition : EffectAnchor
  totalBasisJpy : Int
  resultingUnits : Quantity
deriving Repr, DecidableEq

private def basisA : BasisEvidence := {
  acquisition := originA
  totalBasisJpy := 600
  resultingUnits := Quantity.ofQuanta 1
}

private def basisB : BasisEvidence := {
  acquisition := originB
  totalBasisJpy := 1800
  resultingUnits := Quantity.ofQuanta 2
}

private def basis : List BasisEvidence := [basisA, basisB]

private def basisPerCurrentUnit?
    (basis : List BasisEvidence)
    (origin : EffectAnchor) : Option Int := do
  let row ← basis.find? fun item => item.acquisition = origin
  if row.resultingUnits.quanta <= 0 then none
  else if row.totalBasisJpy % row.resultingUnits.quanta != 0 then none
  else some (row.totalBasisJpy / row.resultingUnits.quanta)

structure DisposalAttribution where
  disposal : EffectAnchor
  origin : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

private def disposeFromA : DisposalAttribution := {
  disposal := disposal
  origin := originA
  units := Quantity.ofQuanta 1
}

private def disposeFromB : DisposalAttribution := {
  disposal := disposal
  origin := originB
  units := Quantity.ofQuanta 1
}

private def lineageCapacityFor?
    (edges : List MergerLineageEdge)
    (origin current : EffectAnchor) : Option Int := do
  let edge ← edges.find? fun item =>
    item.origin = origin && item.current = current
  pure edge.currentUnits.quanta

private def disposalAdmitted?
    (memory : EventMemory)
    (edges : List MergerLineageEdge)
    (attribution : DisposalAttribution) : Bool :=
  anchoredQuantity? memory attribution.disposal = some (newShare, -1) &&
  match lineageCapacityFor? edges attribution.origin current with
  | none => false
  | some capacity =>
      attribution.units.quanta > 0 &&
      attribution.units.quanta <= capacity

theorem one_current_effect_supports_two_distinct_origin_attributions :
    (do
      let memory ← physicalMemory?
      pure (
        disposalAdmitted? memory edges disposeFromA,
        disposalAdmitted? memory edges disposeFromB)) =
      some (true, true) := by
  native_decide

private def realisedGain?
    (basis : List BasisEvidence)
    (attribution : DisposalAttribution)
    (proceedsJpy : Int) : Option Int := do
  let perUnit ← basisPerCurrentUnit? basis attribution.origin
  pure (proceedsJpy - attribution.units.quanta * perUnit)

theorem current_effect_identity_does_not_determine_realised_gain :
    realisedGain? basis disposeFromA 1000 = some 400 ∧
    realisedGain? basis disposeFromB 1000 = some 100 := by
  native_decide

/--
Without many-to-one lineage, neither disposal attribution is admitted.

The physical current Effect exists, but it does not contain the hidden origin
partition.
-/
theorem physical_current_effect_does_not_reconstruct_origin_partition :
    (do
      let memory ← physicalMemory?
      pure (
        disposalAdmitted? memory [] disposeFromA,
        disposalAdmitted? memory [] disposeFromB)) =
      some (false, false) := by
  native_decide

/-!
## Finding

The many-to-one merger is the strongest pressure in this sequence so far.

One current physical Effect contains quantity descended from two independent
acquisition origins:

```text
origin A --1 unit--\
                    -> current Effect (+3)
origin B --2 units--/
```

Therefore:

```text
current Effect identity
    !=
lot-like acquisition identity
```

even more strongly than in the one-to-one split case.

Yet the selected basis / disposal answers are still recoverable from
quantity-bearing provenance edges plus origin basis evidence.

A first-class LotId is therefore **still not forced by this specimen**.

The graph hypothesis survives one-to-one, one-to-many, and many-to-one
transformations:

```text
physical Effect nodes
+
quantity-bearing provenance edges
+
basis evidence at origins / allocations
    -> selected lot-like answers
```

But the hypothesis is now close to its strongest practical form.

A future LotId would be independently earned only if a selected query needs one
stable reference that is not equivalent to:

- an acquisition origin Effect;
- one current physical Effect;
- or a reconstructable provenance component / path.

Examples that could apply further pressure include:

- external broker lot identifiers that remain stable across transformations;
- user annotations attached to a lot as a continuing entity;
- tax authority identifiers or wash-sale relationships naming a persistent lot;
- corrections that replace provenance edges while preserving one externally
  referenced lot identity.

Not earned:

- production `MergerLineageEdge`;
- generic graph infrastructure;
- production `LotId`;
- merger writer/persistence;
- holding-period/tax policy;
- fractional merger ratios or cash-in-lieu;
- correction/conflict semantics for graph edges.
-/

end Loam.Observation291
