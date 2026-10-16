import Loam.Config.DailyPaceConfig
import Loam.Review.CurrentBalanceReview
import Loam.HouseholdPaths
import Loam.Persistence.SiblingStage
import Loam.Tui.DailyPacePoolSetup
import Loam.Tui.EditorSession
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.DailyPacePoolSetupSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

private def rawConfig (path : System.FilePath) : IO (Except String (Option String)) := do
  try
    if ← path.pathExists then
      return .ok (some (← IO.FS.readFile path))
    return .ok none
  catch error =>
    return .error ("Daily Pace pool config unreadable: " ++ error.toString)

/-- Only exact current balances are eligible for an explicit pool choice. -/
def candidates (root : System.FilePath) (measure : MeasureId) :
    IO (Except String (List EffectCoordinate)) := do
  match ← Loam.CurrentBalanceReview.loadSnapshot root root with
  | .error message => return .error message
  | .ok snapshot =>
      return .ok ((snapshot.rows.filter fun row =>
        row.coordinate.measure == measure).map (·.coordinate)).eraseDups

structure Ready where
  candidates : List EffectCoordinate
  previous : List EffectCoordinate
  rawBefore : Option String

/-- Refuse malformed configs without silently resetting the original selection. -/
def prepare (root : System.FilePath) (measure : MeasureId) :
    IO (Except String Ready) := do
  let current ←
    match ← candidates root measure with
    | .ok available => pure available
    | .error message => return .error message
  let raw ←
    match ← rawConfig (Loam.HouseholdPaths.dailyPace root) with
    | .ok value => pure value
    | .error message => return .error message
  let old ←
    match raw with
    | none => pure []
    | some body =>
        match Loam.DailyPaceConfig.decodeForMeasure? measure body with
        | some rows => pure rows
        | none =>
            return .error "Existing Daily Pace pool config is malformed or uses another Measure. No changes made."
  if !old.all current.contains then
    return .error
      "Existing pool includes a balance that is not exact-current. Review that balance before editing the pool; no changes made."
  return .ok { candidates := current, previous := old, rawBefore := raw }

/--
Publish replaceable query configuration, never financial authority. A stale or
malformed file and a changed exact-current candidate set refuse to publish.
A sibling stage is used instead of direct truncation of the installed config.
-/
def save (root : System.FilePath) (measure : MeasureId)
    (ready : Ready) (selection : List EffectCoordinate) :
    IO (Except String Unit) := do
  if selection.isEmpty || !decide selection.Nodup ||
      !selection.all (fun coordinate =>
        coordinate.measure == measure && ready.candidates.contains coordinate) then
    return .error "Select at least one distinct, exact-current balance for this Measure."
  let current ←
    match ← candidates root measure with
    | .ok available => pure available
    | .error message => return .error message
  if current != ready.candidates then
    return .error "Current balances changed while setting the pool. Exit and reopen setup."
  let path := Loam.HouseholdPaths.dailyPace root
  let raw ←
    match ← rawConfig path with
    | .ok value => pure value
    | .error message => return .error message
  if raw != ready.rawBefore then
    return .error "Daily Pace config changed while editing. Exit and reopen setup."
  let body := String.intercalate "" (selection.map fun coordinate =>
    coordinate.locus.token ++ "\t" ++ coordinate.measure.token ++ "\n")
  if Loam.DailyPaceConfig.decodeForMeasure? measure body != some selection then
    return .error "Selected pool cannot be encoded; no configuration was changed."
  if raw == some body then return .ok ()
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  try
    if ← stage.pathExists then
      return .error "A previous Daily Pace staging file exists. Inspect it before changing the configuration."
    IO.FS.createDirAll (Loam.HouseholdPaths.configDir root)
    Loam.Persistence.replaceTextViaSiblingStage path body
    match ← Loam.DailyPaceConfig.loadForMeasure measure path with
    | .ok actual =>
        if actual == selection then return .ok ()
        else return .error "Saved Daily Pace selection could not be verified."
    | .error message =>
        return .error ("Saved Daily Pace selection could not be verified: " ++ message)
  catch error =>
    return .error ("Daily Pace config update refused: " ++ error.toString)

def run (bounds : Bounds) (root : System.FilePath) (measure : MeasureId) :
    IO String := do
  let ready ←
    match ← prepare root measure with
    | .ok ready => pure ready
    | .error message => return ("Daily Pace pool unavailable: " ++ message)
  let state := Loam.Tui.DailyPacePoolSetup.initial
    measure ready.candidates ready.previous
  let frame := compileWidget (Loam.Tui.DailyPacePoolSetup.view bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  Loam.Tui.EditorSession.runUntilPublishedResizing
    bounds
    (fun _ state key => Loam.Tui.DailyPacePoolSetup.update state key)
    Loam.Tui.DailyPacePoolSetup.view
    Loam.Tui.DailyPacePoolSetup.withError
    "Daily Pace pool setup cancelled."
    (fun chosen => do
      match ← save root measure ready chosen with
      | .ok () => return .ok "Daily Pace pool saved. Pension-cycle dates are configured separately."
      | .error message => return .error message)
    state frame

end Loam.Tui.DailyPacePoolSetupSession
