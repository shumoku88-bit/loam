import Loam.Core.EventCorrection

namespace Loam.Examples.ScientificObservation

open Loam.Core

set_option autoImplicit false

/-!
# Non-household Core probe: scalar scientific observation

This file deliberately removes movement, transfer, conservation, money,
accounts, debit/credit roles, and household parties. It asks whether the same
low-level LOAM vocabulary can represent one scalar observation at one stable
observation locus and later retain an explicit corrected interpretation.
-/

def plantA : LocusId := ⟨"observation:plant-a"⟩
def plantB : LocusId := ⟨"observation:plant-b"⟩

def leafCount : MeasureId := ⟨"observation:leaf-count"⟩

def sevenLeaves : Quantity := Quantity.ofQuanta 7
def eightLeaves : Quantity := Quantity.ofQuanta 8

def recordedObservationId : EventId := ⟨"observation:leaf-count-recorded"⟩
def correctedObservationId : EventId := ⟨"observation:leaf-count-corrected"⟩

/--
The first observation records seven leaves at plant A.

There is no source locus, destination locus, balancing counterpart, transfer, or
conservation law in this Event.
-/
def recordedObservation : Event :=
  { id := recordedObservationId
    effects :=
      [Effect.ofAnonymousQuantity plantA leafCount sevenLeaves]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

/--
The corrected interpretation records eight leaves at the same observation
coordinate.
-/
def correctedObservation : Event :=
  { id := correctedObservationId
    effects :=
      [Effect.ofAnonymousQuantity plantA leafCount eightLeaves]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

def observationCorrection : EventCorrection :=
  { target := recordedObservationId
    replacement := correctedObservationId }

/-- Both observations are retained; the correction is a separate explicit fact. -/
def observationHistory : EventMemory :=
  { events := [recordedObservation, correctedObservation]
    idNodup := by
      simp [recordedObservation, correctedObservation,
        recordedObservationId, correctedObservationId] }

private theorem recorded_value :
    Event.quantityAt recordedObservation plantA leafCount = sevenLeaves := by
  simp [recordedObservation, plantA, leafCount, sevenLeaves,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity,
    SomeAmount.ofQuantity, Amount.ofQuantity, Quantity.ofQuanta]

private theorem corrected_value :
    Event.quantityAt correctedObservation plantA leafCount = eightLeaves := by
  simp [correctedObservation, plantA, leafCount, eightLeaves,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity,
    SomeAmount.ofQuantity, Amount.ofQuantity, Quantity.ofQuanta]

/--
The observation does not spill into another Locus merely because both Loci use
the same MeasureId.
-/
theorem unrelated_plant_is_zero :
    Event.quantityAt recordedObservation plantB leafCount = Quantity.ofQuanta 0 := by
  simp [recordedObservation, plantA, plantB, leafCount, sevenLeaves,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity,
    SomeAmount.ofQuantity, Amount.ofQuantity, Quantity.ofQuanta]

/--
The first scalar observation is represented directly, without introducing a
counterpart Effect or movement semantics.
-/
theorem records_scalar_observation :
    Event.quantityAt recordedObservation plantA leafCount = sevenLeaves :=
  recorded_value

/--
The correction edge closes over both retained observations without replacing the
raw historical Event in memory.
-/
theorem correction_projects :
    (EventCorrection.project? observationHistory observationCorrection).isSome = true := by
  simp [EventCorrection.project?, observationHistory, observationCorrection,
    EventMemory.findById?, FiniteKeyed.findBy?, recordedObservation,
    correctedObservation, recordedObservationId, correctedObservationId]

/--
The same Locus/Measure coordinate can receive a corrected scalar interpretation
without any Core vocabulary change.
-/
theorem corrected_scalar_observation :
    Event.quantityAt correctedObservation plantA leafCount = eightLeaves :=
  corrected_value

/--
The original value remains independently inspectable after the correction fact
is retained.
-/
theorem original_scalar_observation_remains :
    Event.quantityAt recordedObservation plantA leafCount = sevenLeaves :=
  recorded_value

end Loam.Examples.ScientificObservation
