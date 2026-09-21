import Loam.Core.EventMemory
import Loam.PracticalMovement

namespace Loam.Observation289

open Loam.Core

set_option autoImplicit false

/-!
# Observation 289 — stock split separates acquisition identity from active quantity identity

Observations 287–288 showed that acquisition-specific basis and partial-disposal
provenance can use the already-earned `EventId + EffectKey` endpoint.

F100 applies a sharper pressure:

> A stock split changes the quantity representation of one continuing
> acquisition without creating a new acquisition basis.

The selected specimen treats pre-split and post-split share units as distinct
Measure identities so the transformation is explicit rather than hidden inside
an unexplained quantity jump:

```text
acquisition
  broker  +3 pre-share

2-for-1 split
  broker  -3 pre-share
  broker  +6 post-share

later disposal
  broker  -4 post-share
```

The aggregate holding after the split and disposal is therefore:

```text
0 pre-share
2 post-share
```

The split is deliberately **not** an ordinary same-Measure Movement. It is a
quantity-representation transformation whose economic interpretation requires
separate evidence.

The pressure is identity:

- the original acquisition Effect carries +3 `pre-share`;
- the post-split quantity lives on a different +6 `post-share` Effect;
- a later -4 `post-share` disposal cannot use the original acquisition Effect
  directly as its quantity source;
- acquisition basis still belongs to the original acquisition provenance.

Does this force a new `LotId`, or can explicit Effect-to-Effect lineage retain
the selected continuity?
-/

private def broker : LocusId := ⟨"broker"⟩
private def outside : LocusId := ⟨"outside"⟩

private def preShare : MeasureId := ⟨"share-pre-split"⟩
private def postShare : MeasureId := ⟨"share-post-split"⟩

private def acquisitionId : EventId := ⟨"acquisition"⟩
private def splitId : EventId := ⟨"two-for-one-split"⟩
private def disposalId : EventId := ⟨"post-split-disposal"⟩

private def acquisitionKey : EffectKey := ⟨"acquisition-held"⟩
private def retiredKey : EffectKey := ⟨"split-retired-old-units"⟩
private def transformedKey : EffectKey := ⟨"split-issued-new-units"⟩
private def disposalKey : EffectKey := ⟨"post-split-disposal-held"⟩

private def acquisition? : Option Event :=
  Event.ofEffects? acquisitionId [
    Effect.ofQuantity
      acquisitionKey broker preShare (Quantity.ofQuanta 3),
    Effect.ofAnonymousQuantity
      outside preShare (Quantity.ofQuanta (-3))
  ]

/--
One neutral cross-Measure quantity transformation.

No cash, price, gain or acquisition meaning is encoded in the Event itself.
-/
private def splitEvent? : Option Event :=
  Event.ofEffects? splitId [
    Effect.ofQuantity
      retiredKey broker preShare (Quantity.ofQuanta (-3)),
    Effect.ofQuantity
      transformedKey broker postShare (Quantity.ofQuanta 6)
  ]

private def disposal? : Option Event :=
  Event.ofEffects? disposalId [
    Effect.ofQuantity
      disposalKey broker postShare (Quantity.ofQuanta (-4)),
    Effect.ofAnonymousQuantity
      outside postShare (Quantity.ofQuanta 4)
  ]

private def physicalMemory? : Option EventMemory := do
  let acquisition ← acquisition?
  let split ← splitEvent?
  let disposal ← disposal?
  EventMemory.ofEvents? [acquisition, split, disposal]

theorem physical_quantities_after_split_and_disposal :
    (do
      let memory ← physicalMemory?
      pure (
        (EventMemory.quantityAtRecorded memory broker preShare).quanta,
        (EventMemory.quantityAtRecorded memory broker postShare).quanta)) =
      some (0, 2) := by
  native_decide

/--
The ordinary practical Movement entrance refuses the split because unlike
Measures do not cancel each other.
-/
private def ordinarySplitMovementRefused : Bool :=
  match splitEvent? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofSingleMeasureEffects? event.effects).isNone

theorem stock_split_is_not_an_ordinary_same_measure_movement :
    ordinarySplitMovementRefused = true := by
  native_decide

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def acquisitionAnchor : EffectAnchor :=
  ⟨acquisitionId, acquisitionKey⟩

private def retiredAnchor : EffectAnchor :=
  ⟨splitId, retiredKey⟩

private def transformedAnchor : EffectAnchor :=
  ⟨splitId, transformedKey⟩

private def disposalAnchor : EffectAnchor :=
  ⟨disposalId, disposalKey⟩

private def findEffect?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← EventMemory.findById? memory anchor.event
  event.effects.find? fun effect => effect.key = some anchor.effect

private def sourceCanCoverDisposal?
    (memory : EventMemory)
    (source disposal : EffectAnchor) : Bool :=
  match findEffect? memory source, findEffect? memory disposal with
  | some sourceEffect, some disposalEffect =>
      sourceEffect.locus = broker &&
      disposalEffect.locus = broker &&
      sourceEffect.measure = disposalEffect.measure &&
      sourceEffect.quantity.quanta > 0 &&
      disposalEffect.quantity.quanta < 0 &&
      sourceEffect.quantity.quanta >= -disposalEffect.quantity.quanta
  | _, _ => false

/--
After the split, the original acquisition Effect is no longer a valid direct
quantity source for the four-unit disposal.

It has the wrong Measure and only the historical pre-split quantity.
-/
theorem acquisition_effect_is_not_the_active_post_split_quantity_source :
    (do
      let memory ← physicalMemory?
      pure (sourceCanCoverDisposal? memory acquisitionAnchor disposalAnchor)) =
      some false := by
  native_decide

/--
The transformed Effect *is* the active post-split quantity source.
-/
theorem transformed_effect_can_cover_post_split_disposal :
    (do
      let memory ← physicalMemory?
      pure (sourceCanCoverDisposal? memory transformedAnchor disposalAnchor)) =
      some true := by
  native_decide

/--
Observation-local stock-split lineage.

The evidence states that one original acquisition-origin Effect was retired by
one split-side old-unit Effect and continued as one transformed new-unit Effect.

No generic graph, LotId, price or tax meaning is built into this structure.
-/
structure SplitLineageEvidence where
  origin : EffectAnchor
  retired : EffectAnchor
  transformed : EffectAnchor
deriving Repr, DecidableEq

private def splitLineage : SplitLineageEvidence := {
  origin := acquisitionAnchor
  retired := retiredAnchor
  transformed := transformedAnchor
}

private def anchoredQuantity?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option (MeasureId × Int) := do
  let effect ← findEffect? memory anchor
  pure (effect.measure, effect.quantity.quanta)

private def splitLineageAdmitted?
    (memory : EventMemory)
    (evidence : SplitLineageEvidence) : Bool :=
  anchoredQuantity? memory evidence.origin = some (preShare, 3) &&
  anchoredQuantity? memory evidence.retired = some (preShare, -3) &&
  anchoredQuantity? memory evidence.transformed = some (postShare, 6) &&
  evidence.retired.event = evidence.transformed.event

theorem explicit_lineage_qualifies_selected_two_for_one_split :
    (do
      let memory ← physicalMemory?
      pure (splitLineageAdmitted? memory splitLineage)) =
      some true := by
  native_decide

/--
Acquisition basis stays attached to the acquisition provenance, not to the
current physical Effect identity.
-/
structure BasisEvidence where
  acquisition : EffectAnchor
  totalBasisJpy : Int
deriving Repr, DecidableEq

private def acquisitionBasis : BasisEvidence := {
  acquisition := acquisitionAnchor
  totalBasisJpy := 1200
}

private def originForCurrentSource?
    (lineage : List SplitLineageEvidence)
    (currentSource : EffectAnchor) : Option EffectAnchor :=
  match lineage.find? fun item => item.transformed = currentSource with
  | some item => some item.origin
  | none => some currentSource

private def basisForCurrentSource?
    (basis : List BasisEvidence)
    (lineage : List SplitLineageEvidence)
    (currentSource : EffectAnchor) : Option Int := do
  let origin ← originForCurrentSource? lineage currentSource
  let row ← basis.find? fun item => item.acquisition = origin
  pure row.totalBasisJpy

/--
Without split lineage, the post-split Effect has no acquisition-basis evidence.

With lineage, its basis provenance resolves to the original acquisition.
-/
theorem physical_effect_identity_alone_does_not_preserve_basis_continuity :
    basisForCurrentSource? [acquisitionBasis] [] transformedAnchor = none ∧
    basisForCurrentSource?
      [acquisitionBasis] [splitLineage] transformedAnchor = some 1200 := by
  native_decide

/--
The same EventMemory exists with or without split-lineage evidence.

So the physical quantity facts do not determine acquisition continuity.
-/
private def lineageKnown
    (memory : EventMemory)
    (evidence : List SplitLineageEvidence)
    (source : EffectAnchor) : Bool :=
  evidence.any fun item =>
    decide (item.transformed = source) &&
      splitLineageAdmitted? memory item

theorem same_physical_history_different_lineage_evidence_changes_provenance_answer :
    (do
      let memory ← physicalMemory?
      pure (
        lineageKnown memory [] transformedAnchor,
        lineageKnown memory [splitLineage] transformedAnchor)) =
      some (false, true) := by
  native_decide

/-!
## Finding

The stock-split specimen breaks a tempting identity compression:

```text
acquisition Effect identity
    =
current lot-like quantity identity
```

That equality does not survive the split.

Before the split:

```text
acquisition Effect
  +3 pre-share
```

After the split:

```text
transformed Effect
  +6 post-share
```

The later disposal is quantity-compatible with the transformed Effect, not the
original acquisition Effect.

Yet this selected case still does not force a first-class `LotId`.

A narrow lineage relation is sufficient:

```text
original acquisition Effect
        |
        | explicit split lineage
        v
post-split transformed Effect
```

Basis stays attached to the acquisition origin while current quantity lives on
the transformed Effect.

So the stronger practical shape is now:

```text
EventId + EffectKey
    -> one physical Effect identity

Effect-to-Effect transformation provenance
    -> continuity of one acquisition origin across quantity representation change
```

This observation also confirms that a stock split is not an ordinary
same-Measure Movement in the selected representation.

It does **not** earn:

- a production `SplitLineageEvidence` family;
- a production corporate-action writer or persistence row;
- a universal choice to model every split with distinct pre/post Measures;
- a first-class `LotId`;
- nested / repeated split closure;
- reverse splits or fractional cash-in-lieu;
- multiple acquisitions affected by one split;
- basis-allocation / rounding policy;
- tax rules;
- stock-symbol or security-master ontology;
- merger / spin-off semantics;
- correction or reversal laws for corporate actions.

The narrow earned statement is:

> A stock split can make acquisition Effect identity differ from the current
> quantity-bearing Effect identity. Explicit transformation provenance can
> preserve the selected acquisition continuity without yet introducing a new
> Lot identity.
-/

end Loam.Observation289
