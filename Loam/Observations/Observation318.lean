import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Observation318

open Loam.Core

set_option autoImplicit false

/-!
# Observation 318 — ActualReversal provenance is independently retained

Observations 304–317 study how much retained state a declared future vocabulary
actually needs. For deliberately narrow ActualReversal vocabularies, complete
reversal history can collapse to a small behavioural quotient.

This observation applies the complementary canonical-basis test from #700:

> can the production-shaped retained Event world reconstruct which Actual one
> inverse Event reverses, without retaining the explicit ActualReversal pairing?

The witness keeps every retained family identical except ActualReversalMemory.

Two ordinary balanced Events A and C have identical physical Effects. Event B is
the exact physical inverse of both. Therefore the common EventMemory alone is
compatible with either provenance claim:

    A -> B

or:

    C -> B

Both worlds pass the current normalized Actual admission boundary. Nevertheless
they answer different retained provenance questions and expose different
Reversal/Correction endpoint-availability facts.

So exact physical inversion does not reconstruct reversal provenance. The
target↔reversal pairing is independently retained information for the current
production-shaped vocabulary.

This does not imply that ActualReversal needs an independent file, authority
handle, or generic relation framework. Current production already co-publishes
the inverse Event and relation in normalized actual.loam. The result is semantic,
not physical-topology specific.
-/

private def jpy : MeasureId := ⟨"jpy"⟩
private def wallet : LocusId := ⟨"o318-wallet"⟩
private def expense : LocusId := ⟨"o318-expense"⟩

private def eventAId : EventId := ⟨"o318-a"⟩
private def eventBId : EventId := ⟨"o318-b"⟩
private def eventCId : EventId := ⟨"o318-c"⟩

private def forwardEffects : List Effect :=
  [ Effect.ofAnonymousQuantity wallet jpy (Quantity.ofQuanta (-100))
  , Effect.ofAnonymousQuantity expense jpy (Quantity.ofQuanta 100)
  ]

private def inverseEffects : List Effect :=
  [ Effect.ofAnonymousQuantity wallet jpy (Quantity.ofQuanta 100)
  , Effect.ofAnonymousQuantity expense jpy (Quantity.ofQuanta (-100))
  ]

private def eventA : Event :=
  { id := eventAId
    effects := forwardEffects
    keyNodup := by native_decide }

private def eventB : Event :=
  { id := eventBId
    effects := inverseEffects
    keyNodup := by native_decide }

private def eventC : Event :=
  { id := eventCId
    effects := forwardEffects
    keyNodup := by native_decide }

private def commonEvents : EventMemory :=
  { events := [eventA, eventB, eventC]
    idNodup := by native_decide }

private def commonValidity : ActualValidityHistory String :=
  { facts :=
      [ .base eventAId "2026-09-01"
      , .base eventBId "2026-09-02"
      , .base eventCId "2026-09-03"
      ]
    factRefNodup := by native_decide
    corrections := []
    correctionIdNodup := by simp }

private def noCorrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def reversalAB : ActualReversal :=
  { target := eventAId, reversal := eventBId }

private def reversalCB : ActualReversal :=
  { target := eventCId, reversal := eventBId }

private def reversalsAB : ActualReversalMemory :=
  { reversals := [reversalAB]
    endpointNodup := by native_decide }

private def reversalsCB : ActualReversalMemory :=
  { reversals := [reversalCB]
    endpointNodup := by native_decide }

private def worldWith (reversals : ActualReversalMemory) : Loam.ActualEvidence :=
  { events := commonEvents
    validity := commonValidity
    descriptions := EventDescriptionMemory.empty
    merchants := EventMerchantEvidenceMemory.empty
    movementOperations := MovementOperationEvidenceMemory.empty
    corrections := noCorrections
    reversals := reversals
    relations := []
    discharges := [] }

def worldAB : Loam.ActualEvidence :=
  worldWith reversalsAB

def worldCB : Loam.ActualEvidence :=
  worldWith reversalsCB

/-! ## Both provenance worlds are production-admissible -/

theorem worldAB_is_admitted :
    (Loam.Persistence.admitActualImage? worldAB).isSome = true := by
  native_decide

theorem worldCB_is_admitted :
    (Loam.Persistence.admitActualImage? worldCB).isSome = true := by
  native_decide

/-! ## Everything except retained reversal provenance is identical -/

theorem same_event_memory :
    worldAB.events = worldCB.events := by
  rfl

theorem same_validity_history :
    worldAB.validity = worldCB.validity := by
  rfl

theorem same_correction_memory :
    worldAB.corrections = worldCB.corrections := by
  rfl

theorem same_nonreversal_actual_evidence :
    worldAB.events = worldCB.events ∧
    worldAB.validity = worldCB.validity ∧
    worldAB.descriptions = worldCB.descriptions ∧
    worldAB.merchants = worldCB.merchants ∧
    worldAB.movementOperations = worldCB.movementOperations ∧
    worldAB.corrections = worldCB.corrections ∧
    worldAB.relations = worldCB.relations ∧
    worldAB.discharges = worldCB.discharges := by
  constructor
  · rfl
  constructor
  · rfl
  constructor
  · rfl
  constructor
  · rfl
  constructor
  · rfl
  constructor
  · rfl
  constructor <;> rfl

theorem reversal_memories_differ :
    worldAB.reversals.reversals ≠ worldCB.reversals.reversals := by
  native_decide

/-! ## Physical inversion cannot choose the provenance target -/

theorem b_is_exact_inverse_of_a :
    ActualReversal.exactPhysicalInverse? eventA.effects eventB.effects = true := by
  native_decide

theorem b_is_exact_inverse_of_c :
    ActualReversal.exactPhysicalInverse? eventC.effects eventB.effects = true := by
  native_decide

theorem a_and_c_have_identical_physical_effects :
    eventA.effects = eventC.effects := by
  rfl

/-! ## Current retained answers distinguish the worlds -/

theorem a_is_reversed_only_in_worldAB :
    (worldAB.reversals.findByTarget? eventAId).isSome = true ∧
    (worldCB.reversals.findByTarget? eventAId).isSome = false := by
  native_decide

theorem c_is_reversed_only_in_worldCB :
    (worldAB.reversals.findByTarget? eventCId).isSome = false ∧
    (worldCB.reversals.findByTarget? eventCId).isSome = true := by
  native_decide

theorem b_explains_different_targets :
    (worldAB.reversals.findByReversal? eventBId).map ActualReversal.target =
        some eventAId ∧
    (worldCB.reversals.findByReversal? eventBId).map ActualReversal.target =
        some eventCId := by
  native_decide

/--
Production Correction admission refuses an Event participating in Reversal
evidence. The exact publisher also has other guards, but this retained
Reversal-specific guard already changes when only the pairing changes.
-/
def correctionReversalGuardAllows
    (world : Loam.ActualEvidence) (event : EventId) : Bool :=
  !world.reversals.mentionsEvent event

theorem correction_reversal_guard_distinguishes_a :
    correctionReversalGuardAllows worldAB eventAId = false ∧
    correctionReversalGuardAllows worldCB eventAId = true := by
  native_decide

theorem correction_reversal_guard_distinguishes_c :
    correctionReversalGuardAllows worldAB eventCId = true ∧
    correctionReversalGuardAllows worldCB eventCId = false := by
  native_decide

/-!
## Finding

The selected production-shaped collision is:

    same EventMemory
    + same validity
    + same corrections
    + same descriptions / merchant / operation evidence
    + same Relation / Discharge evidence
    + both normalized Actual worlds admitted
    + B is an exact physical inverse of both A and C

yet:

    A -> B
    !=
    C -> B

for current retained provenance answers and Reversal-specific Correction guards.

Therefore removing the ActualReversal target↔reversal pairing would collapse two
household worlds that the current operation vocabulary distinguishes.

Canonical-basis classification for #700:

    ActualReversal target↔reversal provenance : WITNESS

The witness earns retained semantic information, not a particular persistence
topology. It is consistent with the current normalized actual.loam design and
with Observations 304–317: narrower future vocabularies may admit much smaller
behavioural summaries, while the broader production-shaped vocabulary still
requires explicit provenance.
-/

end Loam.Observation318
