import Loam.ActualEvidence
import Loam.ActualDate
import Loam.Core.Event
import Loam.Core.BalancedMovement
import Loam.Core.EventMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.EventMerchantEvidence
import Loam.Core.MovementOperationEvidence
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualReversal
import Loam.Core.ActualReversalBalance
import Loam.Core.OpenRelation
import Loam.Application.CorrectionFrontier
import Loam.Application.ActualValidityFrontier
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Std.Data.HashMap

namespace Loam.Persistence

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
One fully admitted normalized Actual image plus the two read-side projections
that production repeatedly reconstructs.

The raw retained evidence remains available for writer candidate construction.
`currentEvents` and `currentValidities` are derived views, not new authorities.
Their proof fields prevent those views from drifting from the retained evidence.
-/
structure AdmittedActualImage where
  evidence : ActualEvidence
  currentEvents : EventMemory
  currentValidities : ActualValidityMemory String
  currentEvents_admitted :
    correctionFrontierMemory? evidence.events evidence.corrections = some currentEvents
  currentValidities_admitted :
    admittedActualValidityMemory? evidence.validity = some currentValidities

private def retainedEventIndex
    (events : EventMemory) : Std.HashMap String Event :=
  events.events.foldl
    (fun index event => index.insert event.id.token event)
    {}

private def currentValidityIndex
    (validities : ActualValidityMemory String) : Std.HashMap String String :=
  validities.entries.foldl
    (fun index entry => index.insert entry.event.token entry.validOn)
    {}

/--
Construct the proof-carrying movement projection for one represented Measure.
-/
private def normalizedMovementForMeasure?
    (effects : List Effect) (measure : MeasureId) :
    Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? measure <|
    ActualReversalBalance.movementChangesForMeasure measure effects

/-- Check the exact signed total for one Measure without mixing dimensional units. -/
private def normalizedMeasureBalanced
    (effects : List Effect) (measure : MeasureId) : Bool :=
  (normalizedMovementForMeasure? effects measure).isSome

/-- Every retained quantity-bearing Effect must remain nonzero. -/
private def normalizedEventEffectsNonzero (event : Event) : Bool :=
  event.effects.all fun effect =>
    effect.quantity.quanta != 0

/--
The distinct dimensional Measures represented by one Effect collection.

Balance is a property of the whole selected Measure projection, so repeated
Effects in the same Measure must not trigger repeated admission of that same
projection.
-/
private def representedMeasures (effects : List Effect) : List MeasureId :=
  (effects.map Effect.measure).eraseDups

/--
Check that every represented Measure closes independently for one Event, exactly
once per represented Measure.

Reversal endpoints may defer this check to exact-reversal admission: the target
is admitted once there and the reversal side is then derived from the exact
inverse proof rather than admitted a second time.
-/
private def normalizedEventEffectsBalanced (event : Event) : Bool :=
  (representedMeasures event.effects).all fun measure =>
    normalizedMeasureBalanced event.effects measure

/--
Occurrence-date strings become production calendar evidence at this boundary,
so every retained base date and revision date must denote a real ISO calendar
date rather than merely fit in one text token.
-/
private def normalizedValidityDatesAdmissible
    (history : ActualValidityHistory String) : Bool :=
  history.facts.all fun fact =>
    Loam.ActualDate.validIsoDate fact.validOn

/--
Validate that an ActualEvidence aggregate satisfies referential closure and
semantic admission using existing Core and Application boundaries, while
retaining the two derived read views that are otherwise recomputed downstream.

This remains a re-admission boundary rather than a second semantic engine:
it reuses the existing balanced-movement algebra and calendar-date admission,
then calls the existing frontiers and checks that references among the
co-published fact families resolve within the generation.
-/
def admitActualImage? (evidence : ActualEvidence) : Option AdmittedActualImage := do
  -- Nonzero physical evidence remains a direct persistence obligation for every Event.
  if !evidence.events.events.all normalizedEventEffectsNonzero then
    none
  -- Ordinary Events retain direct per-Measure balance admission. Reversal endpoints
  -- are deferred to the relation loop below so one target admission can prove both sides.
  if !evidence.events.events.all (fun event =>
      if evidence.reversals.mentionsEvent event.id then
        true
      else
        normalizedEventEffectsBalanced event) then
    none
  if !normalizedValidityDatesAdmissible evidence.validity then
    none
  match hFrontier : correctionFrontierMemory? evidence.events evidence.corrections with
  | none => none
  | some currentEvents =>
      match hValidity : admittedActualValidityMemory? evidence.validity with
      | none => none
      | some admittedDates => do
          -- Derived acceleration indexes only. Core memories remain the proof-carrying authority.
          let retainedEvents := retainedEventIndex evidence.events
          let currentValidities := currentValidityIndex admittedDates

          -- Every retained validity fact must belong to a retained Event.
          for fact in evidence.validity.facts do
            if !retainedEvents.contains fact.event.token then
              none
          -- Every remembered Event must have a valid current occurrence date.
          for event in evidence.events.events do
            if !currentValidities.contains event.id.token then
              none

          -- Event descriptions: every described Event must exist.
          for entry in evidence.descriptions.entries do
            if !retainedEvents.contains entry.event.token then
              none

          -- Merchant dispositions: every classified Event must exist.
          if !EventMerchantEvidenceMemory.referencesOnlyKnownEvents
              evidence.events evidence.merchants then
            none

          -- Movement operation evidence: every mapped Event must exist.
          if !MovementOperationEvidenceMemory.referencesOnlyKnownEvents
              evidence.events evidence.movementOperations then
            none

          -- Reversals: Core memory already proves global endpoint uniqueness.
          -- Persistence admits target balance once, proves exact physical inversion,
          -- and derives reversal balance from those proofs without a second runtime check.
          for reversal in evidence.reversals.reversals do
            let targetEvent ← retainedEvents[reversal.target.token]?
            let reversalEvent ← retainedEvents[reversal.reversal.token]?
            if hExact :
                ActualReversal.exactPhysicalInverse?
                    targetEvent.effects reversalEvent.effects = true then
              for measure in representedMeasures targetEvent.effects do
                let targetChanges :=
                  ActualReversalBalance.movementChangesForMeasure
                    measure targetEvent.effects
                if hTarget : movementTotalQuanta targetChanges = 0 then
                  let _derivedReversal : BalancedMovement LocusId := {
                    measure := measure
                    changes :=
                      ActualReversalBalance.movementChangesForMeasure
                        measure reversalEvent.effects
                    balanced :=
                      ActualReversalBalance.reversalMeasureZero_of_targetMeasureZero_exactPhysicalInverse
                        targetEvent.effects
                        reversalEvent.effects
                        measure
                        hTarget
                        hExact
                  }
                  pure ()
                else
                  none
            else
              none

          -- Relations: whole-family frontier owns source resolution, shape,
          -- quantity bounds, aggregate coverage, and stable identity uniqueness.
          match hRelations :
              admittedRelationFrontier? evidence.events evidence.relations with
          | none => none
          | some admittedRelations => do
              -- Discharges: persistence owns same-generation reference closure.
              for discharge in evidence.discharges do
                let _ ← retainedEvents[discharge.event.token]?
                let _ ← evidence.relations.find? fun r => r.id = discharge.target

              -- Reuse the already-admitted whole RelationUnit frontier. Target-local
              -- discharge admission must not re-enter whole-family relation admission.
              let _ ← admitRelationDischargesForFrontier?
                evidence.events
                evidence.relations
                admittedRelations
                hRelations
                evidence.discharges

              some {
                evidence := evidence
                currentEvents := currentEvents
                currentValidities := admittedDates
                currentEvents_admitted := hFrontier
                currentValidities_admitted := hValidity
              }

/--
Compatibility entrance returning only retained ActualEvidence.
Writers that mutate a candidate continue to use this raw aggregate and therefore
must requalify the changed candidate before publication.
-/
def admitActualEvidence? (evidence : ActualEvidence) : Option ActualEvidence := do
  let image ← admitActualImage? evidence
  some image.evidence

end Loam.Persistence
