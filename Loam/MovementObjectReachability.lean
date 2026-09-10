import Loam.MovementManifestAuthority

namespace Loam.MovementObjectReachability

set_option autoImplicit false

/-!
# Read-only Movement object reachability

The physical object store is not itself authority. `CURRENT` remains the sole
selected authority, while retained `recovery/manifests` are explicit off-authority
rollback roots. This audit classifies immutable object images without deleting or
rewriting anything.

A recovery manifest must pass the production recovery validator before it may keep
objects reachable. Malformed or tampered recovery evidence therefore refuses the
audit instead of silently turning potentially needed objects into apparent orphans.
-/

structure Snapshot where
  current : List String
  recoveryOnly : List String
  orphan : List String
  allObjects : List String
  recoveryManifests : Nat
  deriving Repr, BEq

private def families : List String :=
  ["Event", "ActualValidity", "EventDescription", "RelationUnit",
    "RelationDischarge", "LocusAdmission"]

private def addUnique (items : List String) (item : String) : List String :=
  if items.contains item then items else item :: items

private def unionUnique (left right : List String) : List String :=
  right.foldl addUnique left

private def rowReference? (row : String) : Option String :=
  match row.splitOn "\t" with
  | [_family, path, digest] =>
      if digest.length == 64 then some path else none
  | _ => none

private def rowReferences? : List String → Option (List String)
  | [] => some []
  | row :: rows => do
      let path ← rowReference? row
      let rest ← rowReferences? rows
      some (addUnique rest path)

/--
Project object paths from manifest bytes that have already passed the production
Movement manifest/world validator. This is deliberately not a second manifest
authority decoder.
-/
private def validatedManifestReferences? (text : String) : Option (List String) :=
  match (text.splitOn "\n").filter (fun row => !row.isEmpty) with
  | [] => none
  | header :: rows =>
      if header.startsWith "LOAM-MOVEMENT-MANIFEST\t" then
        rowReferences? rows
      else
        none

private def loadCurrentReferences?
    (root : System.FilePath) : IO (Except String (List String)) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
  | .error message => return .error message
  | .ok _ => pure ()
  let current := root / "CURRENT"
  let text ← IO.FS.readFile current
  match validatedManifestReferences? text with
  | some refs => return .ok refs
  | none => return .error "loam: validated Movement CURRENT could not be projected for reachability"

private def loadRecoveryReferences?
    (root : System.FilePath) : IO (Except String (Nat × List String)) := do
  let dir := root / "recovery" / "manifests"
  if !(← dir.pathExists) then
    return .ok (0, [])
  if !(← dir.isDir) then
    return .error "loam: Movement recovery/manifests exists but is not a directory"
  let mut count := 0
  let mut refs : List String := []
  for entry in ← dir.readDir do
    if ← entry.path.isDir then
      return .error "loam: Movement recovery/manifests contains an unexpected directory"
    let digest ←
      match entry.fileName.splitOn "." with
      | [digest, "loam"] => pure digest
      | _ => return .error "loam: Movement recovery/manifests contains an unexpected file"
    match ← Loam.MovementManifestAuthority.validateRecoveryCandidate? root digest with
    | .error message => return .error message
    | .ok () => pure ()
    let text ← IO.FS.readFile entry.path
    let manifestRefs ←
      match validatedManifestReferences? text with
      | some found => pure found
      | none => return .error "loam: validated Movement recovery manifest could not be projected for reachability"
    refs := unionUnique refs manifestRefs
    count := count + 1
  return .ok (count, refs)

private def listFamilyObjects?
    (root : System.FilePath) (family : String) : IO (Except String (List String)) := do
  let dir := root / "objects" / family
  if !(← dir.pathExists) then
    return .error s!"loam: Movement object family directory is missing: {family}"
  if !(← dir.isDir) then
    return .error s!"loam: Movement object family path is not a directory: {family}"
  let mut objects : List String := []
  for entry in ← dir.readDir do
    if ← entry.path.isDir then
      return .error s!"loam: Movement object family contains an unexpected directory: {family}"
    if !entry.fileName.endsWith ".loam" then
      return .error s!"loam: Movement object family contains an unexpected file: {family}/{entry.fileName}"
    objects := addUnique objects ("objects/" ++ family ++ "/" ++ entry.fileName)
  return .ok objects

private def listAllObjects?
    (root : System.FilePath) : IO (Except String (List String)) := do
  let mut objects : List String := []
  for family in families do
    match ← listFamilyObjects? root family with
    | .error message => return .error message
    | .ok found => objects := unionUnique objects found
  return .ok objects

/--
Classify every expected Movement object as selected, recovery-only, or orphaned.
No filesystem mutation is performed.
-/
def inspect (root : System.FilePath) : IO (Except String Snapshot) := do
  let current ←
    match ← loadCurrentReferences? root with
    | .error message => return .error message
    | .ok refs => pure refs
  let (recoveryManifests, recovery) ←
    match ← loadRecoveryReferences? root with
    | .error message => return .error message
    | .ok result => pure result
  let allObjects ←
    match ← listAllObjects? root with
    | .error message => return .error message
    | .ok found => pure found
  let reachable := unionUnique current recovery
  let recoveryOnly := recovery.filter (fun path => !current.contains path)
  let orphan := allObjects.filter (fun path => !reachable.contains path)
  return .ok { current, recoveryOnly, orphan, allObjects, recoveryManifests }

private def renderPaths (title : String) (paths : List String) : String :=
  if paths.isEmpty then
    title ++ ": none"
  else
    title ++ ":\n" ++ String.intercalate "\n" (paths.map fun path => "  " ++ path)

/-- Human-facing, read-only audit output. -/
def render (snapshot : Snapshot) : String :=
  String.intercalate "\n" [
    "LOAM Movement object reachability",
    "Status: read-only",
    s!"CURRENT objects: {snapshot.current.length}",
    s!"Recovery manifests: {snapshot.recoveryManifests}",
    s!"Recovery-only objects: {snapshot.recoveryOnly.length}",
    s!"Stored objects: {snapshot.allObjects.length}",
    s!"Orphan objects: {snapshot.orphan.length}",
    renderPaths "Recovery-only" snapshot.recoveryOnly,
    renderPaths "Orphan" snapshot.orphan
  ]

end Loam.MovementObjectReachability
