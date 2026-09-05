import Loam.Sha256
import Std

namespace Loam.Application022

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

-- APPLICATION022_INFRA_START
inductive Family where
  | event
  | actualValidity
  | eventDescription
  | relationUnit
  | relationDischarge
  | actualRouting
  | scheduledCompletion
  | eventCorrection
  | capacity
  | capacityEffective
  | quantityBasis
  | quantityBasisCorrection
  deriving Repr, BEq, DecidableEq

private def allFamilies : List Family :=
  [ .event, .actualValidity, .eventDescription, .relationUnit, .relationDischarge,
    .actualRouting, .scheduledCompletion, .eventCorrection, .capacity,
    .capacityEffective, .quantityBasis, .quantityBasisCorrection ]

private def familyName : Family → String
  | .event => "Event"
  | .actualValidity => "ActualValidity"
  | .eventDescription => "EventDescription"
  | .relationUnit => "RelationUnit"
  | .relationDischarge => "RelationDischarge"
  | .actualRouting => "ActualRouting"
  | .scheduledCompletion => "ScheduledCompletion"
  | .eventCorrection => "EventCorrection"
  | .capacity => "Capacity"
  | .capacityEffective => "CapacityEffective"
  | .quantityBasis => "QuantityBasis"
  | .quantityBasisCorrection => "QuantityBasisCorrection"

private structure FamilyRef where
  path : String
  sha256 : String
  deriving Repr, BEq

private structure Manifest where
  refs : List (Family × FamilyRef)
  deriving Repr, BEq

private def manifestHeader : String := "LOAM-GENERATION-MANIFEST\t2"

private def findRef? : List (Family × FamilyRef) → Family → Option FamilyRef
  | [], _ => none
  | (family, ref) :: rest, wanted =>
      if family == wanted then some ref else findRef? rest wanted

private def manifestRef? (manifest : Manifest) (family : Family) : Option FamilyRef :=
  findRef? manifest.refs family

private def manifestRow (family : Family) (ref : FamilyRef) : String :=
  familyName family ++ "\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest? (manifest : Manifest) : Option String := do
  let rows ← allFamilies.mapM fun family => do
    let ref ← manifestRef? manifest family
    pure (manifestRow family ref)
  pure (String.intercalate "\n" (manifestHeader :: rows) ++ "\n")

private def decodeManifestRow? (expected : Family) (row : String) : Option (Family × FamilyRef) :=
  match row.splitOn "\t" with
  | [name, path, digest] =>
      if name == familyName expected && !path.isEmpty && digest.length == 64 then
        some (expected, { path := path, sha256 := digest })
      else
        none
  | _ => none

private def decodeRows? : List Family → List String → Option (List (Family × FamilyRef))
  | [], [] => some []
  | family :: families, row :: rows => do
      let decoded ← decodeManifestRow? family row
      let rest ← decodeRows? families rows
      pure (decoded :: rest)
  | _, _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [] => none
  | header :: rest =>
      if header != manifestHeader then
        none
      else
        match rest.reverse with
        | "" :: reversedRows => do
            let refs ← decodeRows? allFamilies reversedRows.reverse
            some { refs := refs }
        | _ => none

private def objectRelativePath (family : Family) (digest : String) : String :=
  "objects/" ++ familyName family ++ "/" ++ digest ++ ".loam"

private def ensureObject
    (root : System.FilePath) (family : Family) (text : String) : IO FamilyRef := do
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
  let text ← requireSome (encodeManifest? manifest) "manifest omitted a typed family reference"
  let target := root / "CURRENT"
  let stage := root / "CURRENT.loam-stage"
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  match decodeManifest? staged with
  | some decoded =>
      unless decoded == manifest do
        throw <| IO.userError "staged manifest changed typed references"
  | none => throw <| IO.userError "staged manifest failed its own decoder"
  IO.FS.rename stage target

private def loadManifest? (root : System.FilePath) : IO (Option Manifest) := do
  let target := root / "CURRENT"
  if !(← target.pathExists) then
    return none
  decodeManifest? <$> IO.FS.readFile target

private def loadReferenced? (root : System.FilePath) (ref : FamilyRef) : IO (Option String) := do
  let target := root / ref.path
  if !(← target.pathExists) then
    return none
  let text ← IO.FS.readFile target
  if Loam.Sha256.hash text.toUTF8 == ref.sha256 then some text else none

private def replaceRef (manifest : Manifest) (family : Family) (ref : FamilyRef) : Manifest :=
  { refs := manifest.refs.map fun row =>
      if row.1 == family then (family, ref) else row }

private def uniqueFamilies : List Family → Bool
  | [] => true
  | family :: rest => !rest.contains family && uniqueFamilies rest

private def publishChanges
    (root : System.FilePath)
    (current : Manifest)
    (changes : List (Family × String)) : IO Manifest := do
  unless uniqueFamilies (changes.map Prod.fst) do
    throw <| IO.userError "one publication attempted to prepare the same family twice"
  let prepared ← changes.mapM fun change => do
    let ref ← ensureObject root change.1 change.2
    pure (change.1, ref)
  let next := prepared.foldl (fun manifest change => replaceRef manifest change.1 change.2) current
  publishManifest root next
  pure next

private def changedFamilies (before after : Manifest) : List Family :=
  allFamilies.filter fun family => manifestRef? before family != manifestRef? after family
-- APPLICATION022_INFRA_END

-- APPLICATION022_ADAPTERS_START
private def publishMovement
    (root : System.FilePath) (current : Manifest)
    (events validity descriptions relations discharges : String) : IO Manifest :=
  publishChanges root current [
    (.event, events), (.actualValidity, validity), (.eventDescription, descriptions),
    (.relationUnit, relations), (.relationDischarge, discharges)
  ]

private def publishScheduledCompletion
    (root : System.FilePath) (current : Manifest)
    (events validity descriptions completion : String) : IO Manifest :=
  publishChanges root current [
    (.event, events), (.actualValidity, validity), (.eventDescription, descriptions),
    (.scheduledCompletion, completion)
  ]

private def publishEventCorrection
    (root : System.FilePath) (current : Manifest)
    (events validity corrections : String) : IO Manifest :=
  publishChanges root current [
    (.event, events), (.actualValidity, validity), (.eventCorrection, corrections)
  ]

private def publishCapacity
    (root : System.FilePath) (current : Manifest)
    (capacity effective : String) : IO Manifest :=
  publishChanges root current [(.capacity, capacity), (.capacityEffective, effective)]

private def publishQuantityBasisCorrection
    (root : System.FilePath) (current : Manifest)
    (basis corrections : String) : IO Manifest :=
  publishChanges root current [(.quantityBasis, basis), (.quantityBasisCorrection, corrections)]
-- APPLICATION022_ADAPTERS_END

private def seedManifest (root : System.FilePath) : IO Manifest := do
  let refs ← allFamilies.mapM fun family => do
    let ref ← ensureObject root family ("old-" ++ familyName family ++ "\n")
    pure (family, ref)
  let manifest : Manifest := { refs := refs }
  publishManifest root manifest
  pure manifest

private def everyRefStillExists (root : System.FilePath) (manifest : Manifest) : IO Bool := do
  let mut result := true
  for row in manifest.refs do
    if !(← (root / row.2.path).pathExists) then
      result := false
  pure result

private def requireChanged
    (label : String)
    (before after : Manifest)
    (expected : List Family) : IO Nat := do
  let actual := changedFamilies before after
  expect (actual == expected) s!"{label} changed an unexpected family set: {repr actual}"
  pure actual.length

def run : IO Unit := do
  let root := System.FilePath.mk "scratch/application-022-manifest-writers"
  if ← root.pathExists then
    IO.FS.removeDirAll root
  IO.FS.createDirAll root

  let initial ← seedManifest root

  let movement ← publishMovement root initial
    "movement-events\n" "movement-validity\n" "movement-descriptions\n"
    "movement-relations\n" "movement-discharges\n"
  let movementChanged ← requireChanged "Movement" initial movement
    [.event, .actualValidity, .eventDescription, .relationUnit, .relationDischarge]

  let scheduled ← publishScheduledCompletion root movement
    "scheduled-events\n" "scheduled-validity\n" "scheduled-descriptions\n"
    "scheduled-completion\n"
  let scheduledChanged ← requireChanged "Scheduled completion" movement scheduled
    [.event, .actualValidity, .eventDescription, .scheduledCompletion]

  let correction ← publishEventCorrection root scheduled
    "correction-events\n" "correction-validity\n" "event-corrections\n"
  let correctionChanged ← requireChanged "Event correction" scheduled correction
    [.event, .actualValidity, .eventCorrection]

  let capacity ← publishCapacity root correction "capacity\n" "capacity-effective\n"
  let capacityChanged ← requireChanged "Capacity" correction capacity
    [.capacity, .capacityEffective]

  let basis ← publishQuantityBasisCorrection root capacity
    "quantity-basis\n" "quantity-basis-corrections\n"
  let basisChanged ← requireChanged "QuantityBasis correction" capacity basis
    [.quantityBasis, .quantityBasisCorrection]

  let selected ← requireSome (← loadManifest? root) "CURRENT manifest could not be decoded"
  expect (selected == basis) "reader did not select the final coherent generation"
  for family in allFamilies do
    let ref ← requireSome (manifestRef? selected family)
      s!"selected manifest omitted {familyName family}"
    expect (← loadReferenced? root ref).isSome
      s!"selected {familyName family} object failed digest-checked read"
  expect (← everyRefStillExists root initial)
    "later publication deleted an older immutable family object"

  let changedTotal :=
    movementChanged + scheduledChanged + correctionChanged + capacityChanged + basisChanged
  expect (changedTotal == 16) "five writer probes did not prepare the expected 16 changed families"

  IO.FS.removeDirAll root
  IO.println "Application 022 manifest writer amortization PASS"
  IO.println "writers=5"
  IO.println ("changed_object_preparations=" ++ toString changedTotal)
  IO.println "authority_switches=5"

end Loam.Application022

def main : IO Unit :=
  Loam.Application022.run
