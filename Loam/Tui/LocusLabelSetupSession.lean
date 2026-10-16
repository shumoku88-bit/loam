import Loam.Authority.LocusAdmissionAuthority
import Loam.HouseholdPaths
import Loam.Persistence.SiblingStage
import Loam.Presentation.LocusCatalog
import Loam.Tui.EditorSession
import Loam.Tui.LocusLabelSetup
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.LocusLabelSetupSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
A replaceable display dictionary, not a second Locus admission or accounting
authority. Keep old/historical-only rows and existing help text when setting a
friendly name for an admitted Locus.
-/

structure Ready where
  catalog : Loam.LocusCatalog.Catalog
  admitted : List LocusId
  metadata : List Loam.LocusCatalog.Metadata
  rawBefore : Option String

private def rawConfig (path : System.FilePath) :
    IO (Except String (Option String)) := do
  try
    if ← path.pathExists then return .ok (some (← IO.FS.readFile path))
    return .ok none
  catch error =>
    return .error ("Locus display catalog unreadable: " ++ error.toString)

def prepare (root : System.FilePath) : IO (Except String Ready) := do
  let vocab ←
    match ← Loam.LocusAdmissionAuthority.loadHouseholdCurrent? root with
    | .ok value => pure value
    | .error message => return .error message
  let raw ←
    match ← rawConfig (Loam.HouseholdPaths.locusCatalog root) with
    | .ok value => pure value
    | .error message => return .error message
  let metadata ←
    match raw with
    | none => pure []
    | some body =>
        match Loam.LocusCatalog.decode? body with
        | some records => pure records
        | none => return .error "Existing Locus catalog is malformed. No changes made."
  return .ok {
    admitted := vocab.approved
    metadata
    rawBefore := raw
    catalog := Loam.LocusCatalog.forVocabulary vocab metadata
  }

/-- Save one display label without changing canonical household/old metadata. -/
def save (root : System.FilePath) (ready : Ready)
    (draft : Loam.Tui.LocusLabelSetup.Draft) : IO (Except String Unit) := do
  let some _ := ready.admitted.find? (fun locus => locus.token == draft.token)
    | return .error "Only an admitted Locus may be edited in this setup screen."
  let name := draft.label.trimAscii.toString
  if name.isEmpty || name.toList.length > 80 ||
      !name.toList.all (fun char => char.toNat >= 32 &&
        !(char.toNat >= 0x7f && char.toNat <= 0x9f)) then
    return .error "Invalid single-line friendly display name."
  let vocab ←
    match ← Loam.LocusAdmissionAuthority.loadHouseholdCurrent? root with
    | .ok value => pure value
    | .error message => return .error message
  if vocab.approved != ready.admitted then
    return .error "Locus admission changed while editing. Exit and reopen setup."
  let path := Loam.HouseholdPaths.locusCatalog root
  let raw ←
    match ← rawConfig path with
    | .ok current => pure current
    | .error message => return .error message
  if raw != ready.rawBefore then
    return .error "Display metadata changed while editing. Exit and reopen setup."
  let previous := Loam.LocusCatalog.metadataForToken? ready.metadata draft.token
  let entry : Loam.LocusCatalog.Metadata := {
    token := draft.token
    label := name
    -- The codec requires nonempty help. Preserve old help, otherwise use the
    -- user-entered label rather than manufacturing explanatory semantics.
    help := previous.map (·.help) |>.getD name
  }
  let next :=
    if previous.isSome then
      ready.metadata.map (fun record =>
        if record.token == draft.token then entry else record)
    else ready.metadata ++ [entry]
  let body := String.intercalate "" (next.map fun record =>
    record.token ++ "\t" ++ record.label ++ "\t" ++ record.help ++ "\n")
  if Loam.LocusCatalog.decode? body != some next then
    return .error "Display metadata cannot be encoded; nothing changed."
  if raw == some body then return .ok ()
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  try
    if ← stage.pathExists then
      return .error "A previous Locus catalog stage exists. Inspect before saving."
    IO.FS.createDirAll (Loam.HouseholdPaths.configDir root)
    Loam.Persistence.replaceTextViaSiblingStage path body
    let observed ←
      match ← Loam.LocusCatalog.loadMetadata root with
      | .ok value => pure value
      | .error message => return .error message
    if observed == next then return .ok ()
    return .error "Saved display catalog does not match the selected labels."
  catch error =>
    return .error ("Locus label publication refused: " ++ error.toString)

def run (bounds : Bounds) (root : System.FilePath) : IO String := do
  let ready ←
    match ← prepare root with
    | .ok value => pure value
    | .error message => return "Friendly names unavailable: " ++ message
  let state := Loam.Tui.LocusLabelSetup.initial ready.catalog
  let frame := compileWidget (Loam.Tui.LocusLabelSetup.view bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  Loam.Tui.EditorSession.runUntilPublishedResizing
    bounds
    (fun _ state key => Loam.Tui.LocusLabelSetup.update state key)
    Loam.Tui.LocusLabelSetup.view
    Loam.Tui.LocusLabelSetup.withError
    "Friendly-name setup cancelled."
    (fun draft => do
      match ← save root ready draft with
      | .ok () => return .ok ("Display name saved for " ++ draft.token ++ ".")
      | .error message => return .error message)
    state frame

end Loam.Tui.LocusLabelSetupSession
