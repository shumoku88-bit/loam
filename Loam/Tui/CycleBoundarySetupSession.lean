import Loam.Authority.HouseholdAuthority
import Loam.Config.BoundaryPresetConfig
import Loam.HouseholdPaths
import Loam.Persistence.SiblingStage
import Loam.Tui.CycleBoundarySetup
import Loam.Tui.EditorSession
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.CycleBoundarySetupSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

structure Ready where
  presets : List Loam.BoundaryPresetConfig.Preset
  rawBefore : Option String
  current : Option Loam.BoundaryPresetConfig.Preset

private def rawConfig (path : System.FilePath) : IO (Except String (Option String)) := do
  try
    if ← path.pathExists then return .ok (some (← IO.FS.readFile path))
    return .ok none
  catch error =>
    return .error ("Boundary preset config unreadable: " ++ error.toString)

/-- A malformed household/config cannot be repaired by opening a query editor. -/
def prepare (root : System.FilePath) (today : String) : IO (Except String Ready) := do
  match ← Loam.HouseholdAuthority.loadCurrent? root with
  | .error message => return .error ("Household is not qualified: " ++ message)
  | .ok _ => pure ()
  let raw ←
    match ← rawConfig (Loam.HouseholdPaths.boundaryPresets root) with
    | .ok text => pure text
    | .error message => return .error message
  let presets ←
    match raw with
    | none => pure []
    | some text =>
        match Loam.BoundaryPresetConfig.decode? text with
        | none => return .error "Boundary preset config malformed. Refusing implicit replacement."
        | some presets => pure presets
  let active :=
    match Loam.BoundaryPresetConfig.currentWindowFor? presets today with
    | .ok window => presets.find? (fun preset => preset.name == window.source)
    | .error _ => if presets.length == 1 then presets.head? else none
  return .ok { presets, rawBefore := raw, current := active }

private def wire (presets : List Loam.BoundaryPresetConfig.Preset) : String :=
  String.intercalate "" <| presets.map fun preset =>
    preset.name ++ "\t" ++ String.intercalate "\t" preset.boundaries ++ "\n"

/--
Replace one selected named *query* preset and retain all other presets.
Refuse stale bytes, a conflicting current-date window, invalid dates, and a
leftover staging file. Never touch household.loam or infer recurrence.
-/
def save (root : System.FilePath) (today : String) (ready : Ready)
    (draft : Loam.BoundaryPresetConfig.Preset) : IO (Except String Unit) := do
  let some [replacement] :=
      Loam.BoundaryPresetConfig.decode?
        (draft.name ++ "\t" ++ String.intercalate "\t" draft.boundaries ++ "\n")
    | return .error "Invalid explicit cycle dates. No change made."
  let next :=
    if ready.presets.any (fun preset => preset.name == replacement.name) then
      ready.presets.map (fun preset =>
        if preset.name == replacement.name then replacement else preset)
    else ready.presets ++ [replacement]
  let body := wire next
  if Loam.BoundaryPresetConfig.decode? body != some next then
    return .error "The updated preset configuration could not be admitted."
  match Loam.BoundaryPresetConfig.currentWindowFor? next today with
  | .error message =>
      return .error ("Explicit dates must define exactly one current cycle: " ++ message)
  | .ok window =>
      if window.source != replacement.name then
        return .error "These dates do not cover the current cycle. Edit the current preset instead."
  match ← Loam.HouseholdAuthority.loadCurrent? root with
  | .error message => return .error ("Household changed or is unreadable: " ++ message)
  | .ok _ => pure ()
  let path := Loam.HouseholdPaths.boundaryPresets root
  let raw ←
    match ← rawConfig path with
    | .ok text => pure text
    | .error message => return .error message
  if raw != ready.rawBefore then
    return .error "Cycle configuration changed while editing. Exit and reopen setup."
  if raw == some body then return .ok ()
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  try
    if ← stage.pathExists then
      return .error "A previous boundary preset stage exists. Inspect it before saving."
    IO.FS.createDirAll (Loam.HouseholdPaths.configDir root)
    Loam.Persistence.replaceTextViaSiblingStage path body
    match ← Loam.BoundaryPresetConfig.load? path with
    | some observed =>
        if observed == next then return .ok ()
        return .error "Saved boundary presets failed qualification."
    | none => return .error "Saved boundary preset configuration cannot be decoded."
  catch error =>
    return .error ("Boundary preset config update refused: " ++ error.toString)

def run (bounds : Bounds) (root : System.FilePath) (today : String) : IO String := do
  let ready ←
    match ← prepare root today with
    | .ok value => pure value
    | .error message => return ("Cycle setup unavailable: " ++ message)
  let state := Loam.Tui.CycleBoundarySetup.initial ready.current
  let frame := compileWidget (Loam.Tui.CycleBoundarySetup.view bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  Loam.Tui.EditorSession.runUntilPublishedResizing
    bounds
    (fun _ state key => Loam.Tui.CycleBoundarySetup.update state key)
    Loam.Tui.CycleBoundarySetup.view
    Loam.Tui.CycleBoundarySetup.withError
    "Cycle boundary setup cancelled."
    (fun draft => do
      match ← save root today ready draft with
      | .ok () => return .ok "Explicit Daily Pace cycle boundaries saved."
      | .error message => return .error message)
    state frame

end Loam.Tui.CycleBoundarySetupSession
