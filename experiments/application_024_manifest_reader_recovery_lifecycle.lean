import Loam.Sha256
import Std

namespace Loam.Application024

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def requireOk {α : Type} (value : Except String α) : IO α :=
  match value with
  | .ok result => pure result
  | .error message => throw <| IO.userError message

private def expectError {α : Type} (value : Except String α) (message : String) : IO Unit :=
  match value with
  | .error _ => pure ()
  | .ok _ => throw <| IO.userError message

-- APPLICATION024_PHYSICAL_LIFECYCLE_START
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

private structure Generation where
  manifest : Manifest
  payloads : List (Family × String)
  deriving Repr, BEq

private structure PreparedChange where
  family : Family
  ref : FamilyRef
  created : Bool

private def manifestHeader : String := "LOAM-GENERATION-MANIFEST\t2"

private def objectRelativePath (family : Family) (digest : String) : String :=
  "objects/" ++ familyName family ++ "/" ++ digest ++ ".loam"

private def validDigestShape (digest : String) : Bool :=
  digest.length == 64 && digest.toList.all (fun c => "0123456789abcdef".contains c)

private def findRef? : List (Family × FamilyRef) → Family → Option FamilyRef
  | [], _ => none
  | (family, ref) :: rest, wanted =>
      if family == wanted then some ref else findRef? rest wanted

private def manifestRef? (manifest : Manifest) (family : Family) : Option FamilyRef :=
  findRef? manifest.refs family

private def payloadFor? : List (Family × String) → Family → Option String
  | [], _ => none
  | (family, text) :: rest, wanted =>
      if family == wanted then some text else payloadFor? rest wanted

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
      if name == familyName expected && validDigestShape digest &&
          path == objectRelativePath expected digest then
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

private def ensureObject
    (root : System.FilePath) (family : Family) (text : String) : IO PreparedChange := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    unless existing == text do
      throw <| IO.userError s!"content-addressed object mismatch: {relative}"
    pure { family := family, ref := { path := relative, sha256 := digest }, created := false }
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    unless staged == text do
      throw <| IO.userError s!"staged object mismatch: {relative}"
    IO.FS.rename stage target
    pure { family := family, ref := { path := relative, sha256 := digest }, created := true }

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

private def loadManifestStrict (root : System.FilePath) : IO (Except String Manifest) := do
  let target := root / "CURRENT"
  if !(← target.pathExists) then
    return .error "CURRENT is missing"
  let text ← IO.FS.readFile target
  match decodeManifest? text with
  | none => return .error "CURRENT is malformed"
  | some manifest => return .ok manifest

private def readByManifest
    (root : System.FilePath) (manifest : Manifest) : IO (Except String Generation) := do
  let mut payloads : List (Family × String) := []
  for family in allFamilies do
    let ref ←
      match manifestRef? manifest family with
      | some ref => pure ref
      | none => return .error s!"manifest omitted {familyName family}"
    let target := root / ref.path
    if !(← target.pathExists) then
      return .error s!"selected {familyName family} object is missing"
    let text ← IO.FS.readFile target
    if Loam.Sha256.hash text.toUTF8 != ref.sha256 then
      return .error s!"selected {familyName family} object failed digest verification"
    payloads := payloads ++ [(family, text)]
  return .ok { manifest := manifest, payloads := payloads }

private def readCurrent (root : System.FilePath) : IO (Except String Generation) := do
  match ← loadManifestStrict root with
  | .error message => return .error message
  | .ok manifest => readByManifest root manifest

private def replaceRef (manifest : Manifest) (family : Family) (ref : FamilyRef) : Manifest :=
  { refs := manifest.refs.map fun row =>
      if row.1 == family then (family, ref) else row }

private def uniqueFamilies : List Family → Bool
  | [] => true
  | family :: rest => !rest.contains family && uniqueFamilies rest

private def publishChangesFromCurrent
    (root : System.FilePath)
    (changes : List (Family × String)) : IO (Manifest × Nat) := do
  unless uniqueFamilies (changes.map Prod.fst) do
    throw <| IO.userError "one publication attempted to prepare the same family twice"
  let current ← requireOk (← loadManifestStrict root)
  let prepared ← changes.mapM fun change => ensureObject root change.1 change.2
  let next := prepared.foldl (fun manifest change => replaceRef manifest change.family change.ref) current
  publishManifest root next
  let createdCount := prepared.foldl (fun count change => if change.created then count + 1 else count) 0
  pure (next, createdCount)

private def refSelected (manifest : Manifest) (ref : FamilyRef) : Bool :=
  manifest.refs.any fun row => row.2 == ref

/--
Online readers are not owned by the writer lock. Therefore an object not selected
by the newest CURRENT may still be needed by a reader that already loaded the
previous manifest. The conservative online policy is intentionally no deletion.
Offline/quiescent garbage collection remains a separate maintenance question.
-/
private def deleteOnline (_root : System.FilePath) (_ref : FamilyRef) : IO Bool :=
  pure false
-- APPLICATION024_PHYSICAL_LIFECYCLE_END

private def seedManifest (root : System.FilePath) : IO Manifest := do
  let prepared ← allFamilies.mapM fun family =>
    ensureObject root family ("old-" ++ familyName family ++ "\n")
  let manifest : Manifest := {
    refs := prepared.map fun item => (item.family, item.ref)
  }
  publishManifest root manifest
  pure manifest

private def pathFor (root : System.FilePath) (ref : FamilyRef) : System.FilePath :=
  root / ref.path

private def assertCurrentEvent (root : System.FilePath) (expected : String) : IO Unit := do
  let generation ← requireOk (← readCurrent root)
  expect (payloadFor? generation.payloads .event == some expected)
    "CURRENT selected the wrong Event object"

private def failClosedCases (root : System.FilePath) : IO Nat := do
  let currentPath := root / "CURRENT"
  let savedManifest ← IO.FS.readFile currentPath

  let hiddenCurrent := root / "CURRENT.hidden"
  IO.FS.rename currentPath hiddenCurrent
  expectError (← readCurrent root) "reader accepted a missing CURRENT"
  IO.FS.rename hiddenCurrent currentPath

  IO.FS.writeFile currentPath "BROKEN\n"
  expectError (← readCurrent root) "reader accepted a malformed CURRENT"
  IO.FS.writeFile currentPath savedManifest

  let selected ← requireOk (← loadManifestStrict root)
  let eventRef ← requireSome (manifestRef? selected .event) "selected manifest omitted Event"
  let eventPath := pathFor root eventRef
  let hiddenEvent := System.FilePath.mk (eventPath.toString ++ ".hidden")
  IO.FS.rename eventPath hiddenEvent
  expectError (← readCurrent root) "reader accepted a missing selected object"
  IO.FS.rename hiddenEvent eventPath

  let savedEvent ← IO.FS.readFile eventPath
  IO.FS.writeFile eventPath (savedEvent ++ "tampered")
  expectError (← readCurrent root) "reader accepted a digest-mismatched selected object"
  IO.FS.writeFile eventPath savedEvent

  pure 4

def run : IO Unit := do
  let root := System.FilePath.mk "scratch/application-024-manifest-lifecycle"
  if ← root.pathExists then
    IO.FS.removeDirAll root
  IO.FS.createDirAll root

  let initial ← seedManifest root
  let initialRead ← requireOk (← readCurrent root)
  expect (payloadFor? initialRead.payloads .event == some "old-Event\n")
    "initial generation did not decode"

  -- Simulate interruption after off-authority object preparation but before CURRENT.
  let preparedEvent ← ensureObject root .event "next-events\n"
  expect preparedEvent.created "interrupted Event object was not freshly prepared"
  let abandoned ← ensureObject root .relationUnit "abandoned-relations\n"
  expect abandoned.created "abandoned relation object was not freshly prepared"
  expect (!refSelected initial preparedEvent.ref)
    "off-authority Event object unexpectedly changed authority"
  expect (!refSelected initial abandoned.ref)
    "off-authority RelationUnit object unexpectedly changed authority"

  -- Restart from disk only: unreferenced objects must not affect the selected generation.
  let restarted ← requireOk (← readCurrent root)
  expect (restarted == initialRead)
    "restart observed an unreferenced prepared object"

  -- Retry the intended update. Content addressing should reuse the prepared Event object.
  let (next, createdOnRetry) ← publishChangesFromCurrent root [
    (.event, "next-events\n"),
    (.actualValidity, "next-validity\n")
  ]
  expect (createdOnRetry == 1)
    "retry did not reuse the already-prepared Event object"
  assertCurrentEvent root "next-events\n"
  expect (!refSelected next abandoned.ref)
    "unrelated abandoned object became authoritative"

  -- A reader holding the old manifest must still be able to finish after publication.
  let staleReader ← requireOk (← readByManifest root initial)
  expect (payloadFor? staleReader.payloads .event == some "old-Event\n")
    "old immutable generation disappeared beneath a stale reader"

  let oldEventRef ← requireSome (manifestRef? initial .event) "initial manifest omitted Event"
  expect (!refSelected next oldEventRef)
    "old Event unexpectedly remained selected"
  expect (← (pathFor root oldEventRef).pathExists)
    "old Event object was deleted while a stale reader may still need it"
  expect (← (pathFor root abandoned.ref).pathExists)
    "abandoned object was eagerly deleted"
  expect (!(← deleteOnline root abandoned.ref))
    "online GC deleted an object without a reader-quiescence proof"

  let failClosed ← failClosedCases root
  assertCurrentEvent root "next-events\n"

  IO.FS.removeDirAll root
  IO.println "Application 024 manifest reader/recovery lifecycle PASS"
  IO.println "fail_closed_reader_cases=4"
  IO.println "interrupted_unreferenced_restart_kept_authority=1"
  IO.println "retry_reused_prepared_object=1"
  IO.println "stale_reader_old_generation_survives=1"
  IO.println "online_gc_deletions=0"
  IO.println "orphan_objects_reserve_semantic_identity=0"
  IO.println ("verified_fail_closed_cases=" ++ toString failClosed)

end Loam.Application024

def main : IO Unit :=
  Loam.Application024.run
