import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.MovementManifestAuthority
import Loam.Persistence.ActualReversalPersistence
import Loam.Persistence.EventCorrectionPersistence

open Loam.Core

set_option autoImplicit false

private def endpointText : RelationEndpoint → String
  | .household => "household"
  | .external id => "external:" ++ id.token

private def sourceKeyRetained
    (relations : List RelationUnit) (event : EventId) (effect : Effect) : Bool :=
  relations.any fun relation =>
    decide (relation.sourceEvent = event ∧ relation.sourceEffect = effect.key)

private def predecessorText?
    (history : ActualValidityHistory String)
    (replacement : ActualValidityRevisionId) : Option String := do
  let correction ← history.corrections.find? fun correction =>
    decide (correction.replacement = replacement)
  match correction.target with
  | .root _ => some "ROOT"
  | .revision id => some ("REV:" ++ id.token)

private def loadCorrections
    (path : System.FilePath) : IO EventCorrectionMemory := do
  let some memory ← Loam.Persistence.loadEventCorrectionMemoryOrEmpty? path
    | throw (IO.userError "production correction authority malformed")
  pure memory

private def loadReversals
    (path : System.FilePath) : IO ActualReversalMemory := do
  let some memory ← Loam.Persistence.loadActualReversalMemory? path
    | throw (IO.userError "production reversal authority malformed")
  pure memory

private def printTx
    (evidence : Loam.MovementManifestAuthority.EvidenceWorld)
    (dates : ActualValidityMemory String)
    (event : Event) : IO Unit := do
  let some date := dates.findByEventId? event.id
    | throw (IO.userError ("missing current occurrence date for " ++ event.id.token))
  let description :=
    match evidence.descriptions.findText? event.id with
    | none => "NODESC"
    | some text => "DESC=" ++ text
  IO.println <| String.intercalate "\t" ["TX", event.id.token, date, description]

  for effect in event.effects do
    let key :=
      if sourceKeyRetained evidence.relations event.id effect then effect.key.token else ""
    IO.println <| String.intercalate "\t" [
      "EFFECT", event.id.token, key, effect.locus.token, effect.measure.token,
      toString effect.quantity.quanta
    ]

  for fact in evidence.validity.facts do
    match fact with
    | .base _ _ => pure ()
    | .revision revision owner validOn =>
        if owner = event.id then
          let some predecessor := predecessorText? evidence.validity revision
            | throw (IO.userError ("date revision lacks admitted predecessor: " ++ revision.token))
          IO.println <| String.intercalate "\t" [
            "DATE-REV", event.id.token, revision.token, validOn, predecessor
          ]
        else
          pure ()

  for discharge in evidence.discharges do
    if discharge.event = event.id then
      IO.println <| String.intercalate "\t" [
        "DISCHARGE", event.id.token, discharge.target.token,
        toString discharge.quantity.quanta
      ]
    else
      pure ()

private def printRelations
    (evidence : Loam.MovementManifestAuthority.EvidenceWorld) : IO Unit := do
  for relation in evidence.relations do
    let some outstanding := Loam.Application.relationOutstandingQuantity?
        evidence.events evidence.relations evidence.discharges relation.id
      | throw (IO.userError ("production relation frontier unresolved: " ++ relation.id.token))
    IO.println <| String.intercalate "\t" [
      "RELATION",
      relation.id.token,
      relation.sourceEvent.token,
      relation.sourceEffect.token,
      endpointText relation.debtor,
      endpointText relation.creditor,
      toString relation.quantity.quanta,
      toString outstanding.quanta
    ]

/--
Test-only observer for differential qualification of the normalized Actual model.
All semantic calculations delegate to current production read boundaries.  This is
not a second canonical reader and is not an application entrance.
-/
def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "usage: NormalizedActualProductionObservation DATA_ROOT")
  let root := System.FilePath.mk rootText
  let movementRoot := root / "movement-authority"

  let evidenceResult ← Loam.MovementManifestAuthority.loadSelectedEvidence? movementRoot
  let .ok evidence := evidenceResult
    | throw (IO.userError "selected production Movement evidence unavailable")
  let corrections ← loadCorrections (root / "corrections.loam")
  let reversals ← loadReversals (root / "actual-reversals.loam")

  let some _ := Loam.Application.correctionFrontierMemory? evidence.events corrections
    | throw (IO.userError "production Event correction frontier unresolved")
  let some dates := Loam.Application.admittedActualValidityMemory? evidence.validity
    | throw (IO.userError "production ActualValidity frontier unresolved")

  for event in evidence.events.events do
    printTx evidence dates event

  for correction in corrections.corrections do
    IO.println <| String.intercalate "\t" [
      "CORRECTION", correction.target.token, correction.replacement.token
    ]

  for reversal in reversals.reversals do
    unless (evidence.events.findById? reversal.target).isSome &&
        (evidence.events.findById? reversal.reversal).isSome do
      throw (IO.userError "production reversal relation has an open endpoint")
    IO.println <| String.intercalate "\t" [
      "REVERSAL", reversal.target.token, reversal.reversal.token
    ]

  printRelations evidence
  IO.println "STATUS\tcomplete"
