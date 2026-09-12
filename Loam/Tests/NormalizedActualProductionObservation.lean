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
    IO.eprintln ("diagnostic: relation frontier begin " ++ relation.id.token)
    let some outstanding := Loam.Application.relationOutstandingQuantity?
        evidence.events evidence.relations evidence.discharges relation.id
      | throw (IO.userError ("production relation frontier unresolved: " ++ relation.id.token))
    IO.eprintln ("diagnostic: relation frontier end " ++ relation.id.token)
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

private def selected
    (mode wanted : String) : Bool :=
  mode = "all" || mode = wanted

/--
Test-only observer for differential qualification of the normalized Actual model.
All semantic calculations delegate to current production read boundaries. This is
not a second canonical reader and is not an application entrance.

An optional diagnostic phase isolates native crashes without changing semantics:
`frontiers`, `events`, `corrections`, `reversals`, `relations`, or `all`.
-/
def main (args : List String) : IO Unit := do
  let (rootText, mode) ←
    match args with
    | [rootText] => pure (rootText, "all")
    | [rootText, mode] => pure (rootText, mode)
    | _ => throw (IO.userError
        "usage: NormalizedActualProductionObservation DATA_ROOT [frontiers|events|corrections|reversals|relations|all]")
  unless ["frontiers", "events", "corrections", "reversals", "relations", "all"].contains mode do
    throw (IO.userError ("unknown diagnostic phase: " ++ mode))

  let root := System.FilePath.mk rootText
  let movementRoot := root / "movement-authority"

  IO.eprintln "diagnostic: load selected evidence begin"
  let evidenceResult ← Loam.MovementManifestAuthority.loadSelectedEvidence? movementRoot
  let .ok evidence := evidenceResult
    | throw (IO.userError "selected production Movement evidence unavailable")
  IO.eprintln "diagnostic: load selected evidence end"

  IO.eprintln "diagnostic: load correction/reversal side authorities begin"
  let corrections ← loadCorrections (root / "corrections.loam")
  let reversals ← loadReversals (root / "actual-reversals.loam")
  IO.eprintln "diagnostic: load correction/reversal side authorities end"

  IO.eprintln "diagnostic: correction frontier begin"
  let some _ := Loam.Application.correctionFrontierMemory? evidence.events corrections
    | throw (IO.userError "production Event correction frontier unresolved")
  IO.eprintln "diagnostic: correction frontier end"

  IO.eprintln "diagnostic: validity frontier begin"
  let some dates := Loam.Application.admittedActualValidityMemory? evidence.validity
    | throw (IO.userError "production ActualValidity frontier unresolved")
  IO.eprintln "diagnostic: validity frontier end"

  if mode = "frontiers" then
    IO.println "STATUS\tfrontiers"

  if selected mode "events" then
    IO.eprintln "diagnostic: events begin"
    for event in evidence.events.events do
      printTx evidence dates event
    IO.eprintln "diagnostic: events end"

  if selected mode "corrections" then
    IO.eprintln "diagnostic: corrections begin"
    for correction in corrections.corrections do
      IO.println <| String.intercalate "\t" [
        "CORRECTION", correction.target.token, correction.replacement.token
      ]
    IO.eprintln "diagnostic: corrections end"

  if selected mode "reversals" then
    IO.eprintln "diagnostic: reversals begin"
    for reversal in reversals.reversals do
      unless (evidence.events.findById? reversal.target).isSome &&
          (evidence.events.findById? reversal.reversal).isSome do
        throw (IO.userError "production reversal relation has an open endpoint")
      IO.println <| String.intercalate "\t" [
        "REVERSAL", reversal.target.token, reversal.reversal.token
      ]
    IO.eprintln "diagnostic: reversals end"

  if selected mode "relations" then
    IO.eprintln "diagnostic: relations begin"
    printRelations evidence
    IO.eprintln "diagnostic: relations end"

  if mode = "all" then
    IO.println "STATUS\tcomplete"
