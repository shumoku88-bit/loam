import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.Persistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.Sha256
import Std

namespace Loam.Application031

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private structure FamilyRef where
  path : String
  sha256 : String
  deriving Repr, BEq

private inductive FamilyPresence where
  | absent
  | present (ref : FamilyRef)
  deriving Repr, BEq

private structure Manifest where
  capacity : FamilyPresence
  effective : FamilyPresence
  events : FamilyPresence
  corrections : FamilyPresence
  validity : FamilyPresence
  routing : FamilyPresence
  deriving Repr, BEq

private structure GenerationSnapshot where
  root : System.FilePath
  manifest : Manifest

private structure TypedBudgetWorld where
  capacity : CapacityMemory
  effective : CapacityEffectiveMemory String
  events : EventMemory
  corrections : EventCorrectionMemory
  validity : ActualValidityHistory String
  routing : Loam.Persistence.ActualRoutingHistory

private structure PurposeProjection where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity

private def manifestHeader : String := "LOAM-APPLICATION031-MANIFEST\t1"

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

private def encodePresenceRow (family : String) : FamilyPresence → String
  | .absent => family ++ "\tABSENT"
  | .present ref =>
      family ++ "\tPRESENT\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  String.intercalate "\n" [
    manifestHeader,
    encodePresenceRow "Capacity" manifest.capacity,
    encodePresenceRow "CapacityEffective" manifest.effective,
    encodePresenceRow "Event" manifest.events,
    encodePresenceRow "EventCorrection" manifest.corrections,
    encodePresenceRow "ActualValidity" manifest.validity,
    encodePresenceRow "ActualRouting" manifest.routing
  ] ++ "\n"

private def decodePresenceRow? (expected row : String) : Option FamilyPresence :=
  match row.splitOn "\t" with
  | [family, "ABSENT"] =>
      if family == expected then some .absent else none
  | [family, "PRESENT", path, digest] =>
      if family == expected && digest.length == 64 &&
          path == objectRelativePath expected digest then
        some (.present { path := path, sha256 := digest })
      else
        none
  | _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [header, capacityRow, effectiveRow, eventRow, correctionRow, validityRow,
      routingRow, trailing] =>
      if header != manifestHeader || trailing != "" then
        none
      else do
        let capacity ← decodePresenceRow? "Capacity" capacityRow
        let effective ← decodePresenceRow? "CapacityEffective" effectiveRow
        let events ← decodePresenceRow? "Event" eventRow
        let corrections ← decodePresenceRow? "EventCorrection" correctionRow
        let validity ← decodePresenceRow? "ActualValidity" validityRow
        let routing ← decodePresenceRow? "ActualRouting" routingRow
        some { capacity, effective, events, corrections, validity, routing }
  | _ => none

private def ensureObject
    (root : System.FilePath) (family text : String) : IO FamilyRef := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    unless existing == text do
      throw <| IO.userError s!"content-addressed object mismatch: {relative}"
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    unless staged == text do
      throw <| IO.userError s!"staged object mismatch: {relative}"
    IO.FS.rename stage target
  pure { path := relative, sha256 := digest }

private def publishManifest (root : System.FilePath) (manifest : Manifest) : IO Unit := do
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  let text := encodeManifest manifest
  IO.FS.writeFile stage text
  let decoded ← requireSome (decodeManifest? (← IO.FS.readFile stage))
    "staged CURRENT failed Application 031 manifest decoding"
  expect (decoded == manifest) "staged CURRENT changed family presence or references"
  IO.FS.rename stage target

private def readOptionalFile (path : System.FilePath) : IO (Option String) := do
  if ← path.pathExists then
    return some (← IO.FS.readFile path)
  else
    return none

private def presenceFromOptional
    (root : System.FilePath) (family : String) (text : Option String) : IO FamilyPresence := do
  match text with
  | none => pure .absent
  | some value => pure (.present (← ensureObject root family value))

private def captureCurrent (root : System.FilePath) : IO GenerationSnapshot := do
  let current := root / "CURRENT"
  if !(← current.pathExists) then
    throw <| IO.userError "CURRENT is missing"
  let manifest ← requireSome (decodeManifest? (← IO.FS.readFile current))
    "CURRENT is malformed or unsupported"
  pure { root, manifest }

private def readPresence
    (snapshot : GenerationSnapshot) (family : String) : FamilyPresence → IO (Option String)
  | .absent => pure none
  | .present ref => do
      let expectedPath := objectRelativePath family ref.sha256
      unless ref.path == expectedPath do
        throw <| IO.userError s!"selected {family} path is inconsistent with its digest"
      let target := snapshot.root / ref.path
      if !(← target.pathExists) then
        throw <| IO.userError s!"selected {family} object is missing"
      let text ← IO.FS.readFile target
      unless Loam.Sha256.hash text.toUTF8 == ref.sha256 do
        throw <| IO.userError s!"selected {family} object failed digest verification"
      pure (some text)

private def requiredText
    (snapshot : GenerationSnapshot) (family : String) (presence : FamilyPresence) : IO String := do
  requireSome (← readPresence snapshot family presence)
    s!"{family} is absent from selected generation"

private def emptyCorrections : IO EventCorrectionMemory :=
  requireSome (EventCorrectionMemory.ofCorrections? [])
    "empty EventCorrection memory failed construction"

private def loadTypedBudgetWorld (snapshot : GenerationSnapshot) : IO TypedBudgetWorld := do
  let capacityText ← requiredText snapshot "Capacity" snapshot.manifest.capacity
  let capacity ← requireSome (Loam.Persistence.decodeCapacityMemory? capacityText)
    "selected Capacity bytes failed production decoding"

  let effectiveText ← requiredText snapshot "CapacityEffective" snapshot.manifest.effective
  let effective ← requireSome (Loam.Persistence.decodeCapacityEffectiveMemory? effectiveText)
    "selected CapacityEffective bytes failed production decoding"

  let eventText ← requiredText snapshot "Event" snapshot.manifest.events
  let events ← requireSome (Loam.Persistence.decodeEventMemory? eventText)
    "selected Event bytes failed production decoding"

  let correctionText? ← readPresence snapshot "EventCorrection" snapshot.manifest.corrections
  let corrections ←
    match correctionText? with
    | none => emptyCorrections
    | some text =>
        requireSome (Loam.Persistence.decodeEventCorrectionMemory? text)
          "selected EventCorrection bytes failed production decoding"

  let validityText ← requiredText snapshot "ActualValidity" snapshot.manifest.validity
  let validity ← requireSome (Loam.Persistence.decodeActualValidityHistory? validityText)
    "selected ActualValidity bytes failed production decoding"

  let routingText ← requiredText snapshot "ActualRouting" snapshot.manifest.routing
  let routing ← requireSome (Loam.Persistence.decodeActualRoutingHistory? routingText)
    "selected ActualRouting bytes failed production decoding"

  pure { capacity, effective, events, corrections, validity, routing }

private def addPurposeIfAbsent
    (purposes : List PurposeId)
    (purpose : PurposeId) : List PurposeId :=
  if purpose ∈ purposes then purposes else purposes ++ [purpose]

private def rememberedPurposes (memory : CapacityMemory) : List PurposeId :=
  memory.movements.foldl
    (fun purposes movement =>
      movement.movement.changes.foldl
        (fun current change =>
          match change.coordinate with
          | .unallocated => current
          | .purpose purpose => addPurposeIfAbsent current purpose)
        purposes)
    []

private def projectPurpose?
    (world : TypedBudgetWorld)
    (validities : ActualValidityMemory String)
    (start end_ : String)
    (purpose : PurposeId)
    (measure : MeasureId) : Option PurposeProjection := do
  let entitlement ←
    entitlementAtEffectiveWindow?
      world.capacity world.effective start end_ purpose measure
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      world.events world.corrections validities world.routing start end_ purpose measure
  return { purpose, entitlement, consumption }

private def renderOne
    (start end_ : String)
    (projection : PurposeProjection) : String :=
  let remaining := projection.entitlement - projection.consumption
  String.intercalate "\n" [
    "Budget window [" ++ start ++ ", " ++ end_ ++ ")",
    "Purpose: " ++ projection.purpose.token,
    "Entitlement: " ++ toString projection.entitlement.quanta ++ " jpy",
    "Consumption: " ++ toString projection.consumption.quanta ++ " jpy",
    "Remaining: " ++ toString remaining.quanta ++ " jpy"
  ] ++ "\n"

private def renderAll
    (start end_ : String)
    (projections : List PurposeProjection) : String :=
  let heading := "Budget window [" ++ start ++ ", " ++ end_ ++ ")\n"
  if projections.isEmpty then
    heading ++ "No spending-purpose capacity.\n"
  else
    let rows := projections.map fun projection =>
      let remaining := projection.entitlement - projection.consumption
      "  " ++ projection.purpose.token ++
        ": entitlement " ++ toString projection.entitlement.quanta ++
        " jpy, consumption " ++ toString projection.consumption.quanta ++
        " jpy, remaining " ++ toString remaining.quanta ++ " jpy"
    heading ++ "Purposes:\n" ++ String.intercalate "\n" rows ++ "\n"

private def deriveBudgetWindow?
    (world : TypedBudgetWorld)
    (start end_ purposeToken : String) : Except String String := do
  let validities ←
    match admittedActualValidityMemory? world.validity with
    | some result => Except.ok result
    | none =>
        Except.error
          "Actual validity corrections do not justify one current date per Event"
  let yen : MeasureId := ⟨"jpy"⟩
  if purposeToken == "--all" then
    let purposes := rememberedPurposes world.capacity
    let projections ←
      match purposes.mapM
          (fun purpose => projectPurpose? world validities start end_ purpose yen) with
      | some result => Except.ok result
      | none => Except.error "canonical evidence does not justify this budget-window projection"
    pure (renderAll start end_ projections)
  else
    let purpose : PurposeId := ⟨purposeToken⟩
    let projection ←
      match projectPurpose? world validities start end_ purpose yen with
      | some result => Except.ok result
      | none => Except.error "canonical evidence does not justify this budget-window projection"
    pure (renderOne start end_ projection)

private def runPublish (sidecarRootPath manifestRootPath : String) : IO UInt32 := do
  let sidecarRoot := System.FilePath.mk sidecarRootPath
  let manifestRoot := System.FilePath.mk manifestRootPath
  let capacityPath := sidecarRoot / "capacity.loam"
  let effectivePath := Loam.Persistence.capacityEffectivePathForMemory capacityPath
  let eventPath := sidecarRoot / "memory.loam"
  let correctionPath := sidecarRoot / "corrections.loam"
  let validityPath := Loam.Persistence.actualValidityPathForEventMemory eventPath
  let routingPath := sidecarRoot / "actual-routing.loam"

  let capacityText ← requireSome (← readOptionalFile capacityPath) "Capacity sidecar is missing"
  let _ ← requireSome (Loam.Persistence.decodeCapacityMemory? capacityText)
    "Capacity sidecar failed production decoding before manifest publication"
  let effectiveText ← requireSome (← readOptionalFile effectivePath) "CapacityEffective sidecar is missing"
  let _ ← requireSome (Loam.Persistence.decodeCapacityEffectiveMemory? effectiveText)
    "CapacityEffective sidecar failed production decoding before manifest publication"
  let eventText ← requireSome (← readOptionalFile eventPath) "Event sidecar is missing"
  let _ ← requireSome (Loam.Persistence.decodeEventMemory? eventText)
    "Event sidecar failed production decoding before manifest publication"
  let validityText ← requireSome (← readOptionalFile validityPath) "ActualValidity sidecar is missing"
  let _ ← requireSome (Loam.Persistence.decodeActualValidityHistory? validityText)
    "ActualValidity sidecar failed production decoding before manifest publication"
  let routingText ← requireSome (← readOptionalFile routingPath) "ActualRouting sidecar is missing"
  let _ ← requireSome (Loam.Persistence.decodeActualRoutingHistory? routingText)
    "ActualRouting sidecar failed production decoding before manifest publication"

  let correctionText? ← readOptionalFile correctionPath
  match correctionText? with
  | some text =>
      let _ ← requireSome (Loam.Persistence.decodeEventCorrectionMemory? text)
        "EventCorrection sidecar failed production decoding before manifest publication"
      pure ()
  | none => pure ()

  let capacity : FamilyPresence := .present (← ensureObject manifestRoot "Capacity" capacityText)
  let effective : FamilyPresence :=
    .present (← ensureObject manifestRoot "CapacityEffective" effectiveText)
  let events : FamilyPresence := .present (← ensureObject manifestRoot "Event" eventText)
  let corrections ← presenceFromOptional manifestRoot "EventCorrection" correctionText?
  let validity : FamilyPresence :=
    .present (← ensureObject manifestRoot "ActualValidity" validityText)
  let routing : FamilyPresence :=
    .present (← ensureObject manifestRoot "ActualRouting" routingText)

  publishManifest manifestRoot { capacity, effective, events, corrections, validity, routing }

  IO.println "Application 031 manifest BudgetWindow publication PASS"
  IO.println "authority_switches=1"
  IO.println "family_presence_entries=6"
  IO.println s!"event_correction_absent={if correctionText?.isNone then 1 else 0}"
  return 0

private def runReport
    (manifestRootPath start end_ purposeToken outputPath : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    IO.eprintln "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
    return 2
  else if purposeToken != "--all" && !Loam.Persistence.validToken purposeToken then
    IO.eprintln "loam: budget Purpose must be a nonempty single-line token or --all"
    return 2
  else
    let snapshot ← captureCurrent (System.FilePath.mk manifestRootPath)
    let world ← loadTypedBudgetWorld snapshot
    match deriveBudgetWindow? world start end_ purposeToken with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok text =>
        IO.FS.writeFile (System.FilePath.mk outputPath) text
        IO.println "Application 031 manifest BudgetWindow PASS"
        IO.println "generation_captures=1"
        IO.println "typed_family_boundaries=6"
        IO.println "derived_budget_answers=1"
        return 0

end Loam.Application031

private def usage : String :=
  "Usage: application_031_budget_window_manifest_parity (publish SIDECAR_ROOT MANIFEST_ROOT | report MANIFEST_ROOT START END PURPOSE|--all OUTPUT_FILE)"

def main (args : List String) : IO UInt32 :=
  match args with
  | ["publish", sidecarRoot, manifestRoot] =>
      Loam.Application031.runPublish sidecarRoot manifestRoot
  | ["report", manifestRoot, start, end_, purpose, outputPath] =>
      Loam.Application031.runReport manifestRoot start end_ purpose outputPath
  | _ => do
      IO.eprintln usage
      return 2
