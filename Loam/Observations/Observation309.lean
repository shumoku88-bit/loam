import Loam.Application.CorrectionFrontier
import Loam.PracticalMovement

namespace Loam.Observation309

open Loam.Core

set_option autoImplicit false

/-!
# Observation 309 — suspense as an ordinary Locus under real Correction semantics

Observation 269 established in a bounded Alloy model that a conserved Movement may
remain partially classified and that exact redistribution out of an unresolved
coordinate can preserve the physical payment.

This observation asks whether that shape survives contact with existing LOAM
semantics without introducing a new Core concept.

The fixture uses only:

- ordinary `LocusId` values;
- ordinary anonymous `Effect` values;
- the existing practical single-Measure Movement admission;
- retained `EventMemory`;
- explicit `EventCorrectionMemory`;
- the production CorrectionFrontier projection.

The selected household story is deliberately concrete:

    PayPay physical payment: 5,800 JPY

Initially:
    Food       1,200
    Suspense   4,600

After one partial correction:
    Food       1,200
    Books      2,000
    Suspense   2,600

After a second correction:
    Food       1,200
    Books      4,600
    Suspense       0

The physical source quantity and Measure remain unchanged throughout.
-/

private def source : LocusId := ⟨"paypay"⟩
private def knownA : LocusId := ⟨"food"⟩
private def knownB : LocusId := ⟨"books"⟩
private def suspense : LocusId := ⟨"suspense"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def originalId : EventId := ⟨"purchase-original"⟩
private def partialId : EventId := ⟨"purchase-partial"⟩
private def fullId : EventId := ⟨"purchase-full"⟩

private def effect (locus : LocusId) (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity locus jpy (Quantity.ofQuanta quanta)

private def original : Event :=
  { id := originalId
    effects :=
      [ effect source (-5800)
      , effect knownA 1200
      , effect suspense 4600
      ]
    keyNodup := by
      simp [retainedEffectKeys, effect, Effect.ofAnonymousQuantity] }

private def partiallyClassified : Event :=
  { id := partialId
    effects :=
      [ effect source (-5800)
      , effect knownA 1200
      , effect knownB 2000
      , effect suspense 2600
      ]
    keyNodup := by
      simp [retainedEffectKeys, effect, Effect.ofAnonymousQuantity] }

private def full : Event :=
  { id := fullId
    effects :=
      [ effect source (-5800)
      , effect knownA 1200
      , effect knownB 4600
      ]
    keyNodup := by
      simp [retainedEffectKeys, effect, Effect.ofAnonymousQuantity] }

private def initialEvents : EventMemory :=
  { events := [original]
    idNodup := by native_decide }

private def partialEvents : EventMemory :=
  { events := [original, partiallyClassified]
    idNodup := by native_decide }

private def fullEvents : EventMemory :=
  { events := [original, partiallyClassified, full]
    idNodup := by native_decide }

private def noCorrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def originalToPartial : EventCorrection :=
  { target := originalId
    replacement := partialId }

private def partialToFull : EventCorrection :=
  { target := partialId
    replacement := fullId }

private def firstCorrection : EventCorrectionMemory :=
  { corrections := [originalToPartial]
    idNodup := by native_decide }

private def fullCorrectionChain : EventCorrectionMemory :=
  { corrections := [originalToPartial, partialToFull]
    idNodup := by native_decide }

private def practicalMeasure? (event : Event) : Option MeasureId :=
  (Loam.PracticalMovement.ofSingleMeasureEffects? event.effects).map (·.measure)

/-! ## Existing practical Movement admission accepts every stage -/

theorem original_is_practical :
    (Loam.PracticalMovement.ofSingleMeasureEffects? original.effects).isSome =
      true := by
  native_decide

theorem partial_is_practical :
    (Loam.PracticalMovement.ofSingleMeasureEffects? partiallyClassified.effects).isSome =
      true := by
  native_decide

theorem full_is_practical :
    (Loam.PracticalMovement.ofSingleMeasureEffects? full.effects).isSome =
      true := by
  native_decide

theorem practical_measure_stays_jpy :
    practicalMeasure? original = some jpy ∧
    practicalMeasure? partial = some jpy ∧
    practicalMeasure? full = some jpy := by
  native_decide

/-! ## Correction topology is already admitted by the real frontier -/

theorem first_correction_frontier_admitted :
    Loam.Application.correctionFrontierAdmissible
      partialEvents firstCorrection = true := by
  native_decide

theorem full_correction_chain_frontier_admitted :
    Loam.Application.correctionFrontierAdmissible
      fullEvents fullCorrectionChain = true := by
  native_decide

/-! ## Physical source stays exact while suspense shrinks -/

theorem source_quantity_is_preserved :
    Loam.Application.quantityAtCorrectionFrontier?
        initialEvents noCorrections source jpy =
      some (Quantity.ofQuanta (-5800)) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        partialEvents firstCorrection source jpy =
      some (Quantity.ofQuanta (-5800)) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        fullEvents fullCorrectionChain source jpy =
      some (Quantity.ofQuanta (-5800)) := by
  native_decide

theorem known_food_quantity_is_preserved :
    Loam.Application.quantityAtCorrectionFrontier?
        initialEvents noCorrections knownA jpy =
      some (Quantity.ofQuanta 1200) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        partialEvents firstCorrection knownA jpy =
      some (Quantity.ofQuanta 1200) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        fullEvents fullCorrectionChain knownA jpy =
      some (Quantity.ofQuanta 1200) := by
  native_decide

theorem newly_classified_quantity_grows :
    Loam.Application.quantityAtCorrectionFrontier?
        initialEvents noCorrections knownB jpy =
      some (Quantity.ofQuanta 0) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        partialEvents firstCorrection knownB jpy =
      some (Quantity.ofQuanta 2000) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        fullEvents fullCorrectionChain knownB jpy =
      some (Quantity.ofQuanta 4600) := by
  native_decide

theorem unresolved_quantity_can_shrink_in_stages :
    Loam.Application.quantityAtCorrectionFrontier?
        initialEvents noCorrections suspense jpy =
      some (Quantity.ofQuanta 4600) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        partialEvents firstCorrection suspense jpy =
      some (Quantity.ofQuanta 2600) ∧
    Loam.Application.quantityAtCorrectionFrontier?
        fullEvents fullCorrectionChain suspense jpy =
      some (Quantity.ofQuanta 0) := by
  native_decide

/-! ## Correction preserves the retained historical observations -/

theorem original_observation_remains_retained :
    original ∈ fullEvents.events := by
  simp [fullEvents]

theorem partial_observation_remains_retained :
    partiallyClassified ∈ fullEvents.events := by
  simp [fullEvents]

theorem final_observation_is_retained :
    full ∈ fullEvents.events := by
  simp [fullEvents]

/-!
## Finding

For this concrete real-semantics fixture, no new Core suspense concept is needed.

The existing LOAM vocabulary already admits:

    ordinary LocusId("suspense")
      + balanced single-Measure Event
      + explicit EventCorrection
      + fail-closed CorrectionFrontier
        ->
      partial classification now
      + staged resolution later
      + unchanged physical source quantity
      + unchanged known Measure
      + retained historical observations

The result is intentionally narrower than a production feature.

It does not yet prove:

- that one particular suspense Locus should be canonical household policy;
- how a writer should allocate or validate that Locus;
- how unresolved quantity should appear in TUI / Attention;
- how arbitrary multi-Effect partial reclassification should be generated;
- that all production CorrectionPublisher side conditions are satisfied;
- anything about unknown Measure, tax decomposition, merchant identity, or
  accounting-role completeness.

The useful result is architectural: the first contact with real Event / Effect /
Correction semantics does not force a new semantic primitive.

That keeps open the simpler production direction:

    explicit ordinary Locus convention
      + existing correction semantics
      + derived unresolved queries

rather than adding a separate Suspense type or authority.
-/

end Loam.Observation309
