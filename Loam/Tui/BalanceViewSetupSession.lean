import Loam.Authority.LocusAdmissionAuthority
import Loam.Config.BalanceViewConfig
import Loam.HouseholdPaths
import Loam.Persistence.SiblingStage
import Loam.Tui.DailyPacePoolSetup
import Loam.Tui.EditorSession
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.BalanceViewSetupSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
Balance presentation is a neutral coordinate selection, NOT Daily Pace
eligibility or evidence of an exact current quantity. In particular, a selected
unknown coordinate must remain '?' in Balances. Reuse the existing coordinate
picker without cloning a second state machine.
-/

structure Ready where
  candidates : List EffectCoordinate
  previous : List EffectCoordinate
  rawBefore : Option String

private def rawConfig (path : System.FilePath) :
    IO (Except String (Option String)) := do
  try
    if ← path.pathExists then return .ok (some (← IO.FS.readFile path))
    return .ok none
  catch error =>
    return .error ("Balance view configuration unreadable: " ++ error.toString)

private def admittedCandidates (root : System.FilePath) (measure : MeasureId)
    (previous : List EffectCoordinate) :
    IO (Except String (List EffectCoordinate)) := do
  let vocab ←
    match ← Loam.LocusAdmissionAuthority.loadHouseholdCurrent? root with
    | .ok admitted => pure admitted
    | .error message => return .error message
  -- Existing presentation selections may include historical/retired Loci.
  -- Keep those visible for deliberate removal, never silently erase them.
  let active := previous.filter (fun coordinate => coordinate.measure == measure)
  let admitted := vocab.approved.map fun locus =>
    ({ locus := locus, measure := measure } : EffectCoordinate)
  return .ok (active ++ admitted).eraseDups

/-- Malformed existing view config is not equivalent to no selection. -/
def prepare (root : System.FilePath) (measure : MeasureId) :
    IO (Except String Ready) := do
  let raw ←
    match ← rawConfig (Loam.HouseholdPaths.balanceView root) with
    | .ok raw => pure raw
    | .error message => return .error message
  let old ←
    match raw with
    | none => pure []
    | some body =>
        match Loam.BalanceViewConfig.decode? body with
        | some coords => pure coords.eraseDups
        | none => return .error "Existing balance-view.tsv is malformed. No changes made."
  let choices ←
    match ← admittedCandidates root measure old with
    | .ok rows => pure rows
    | .error message => return .error message
  return .ok { candidates := choices
               previous := old
               rawBefore := raw }

/--
Save only the chosen active-Measure display rows. Existing other-Measure
selections are retained; unknown amounts never become 0 or disappear from the
underlying household. A stale config/admission change must be reopened.
-/
def save (root : System.FilePath) (measure : MeasureId)
    (ready : Ready) (chosen : List EffectCoordinate) :
    IO (Except String Unit) := do
  if !decide chosen.Nodup ||
      !chosen.all (fun c => c.measure == measure && ready.candidates.contains c) then
    return .error "Balance view selection contains duplicates or unknown coordinates."
  let candidates ←
    match ← admittedCandidates root measure ready.previous with
    | .ok rows => pure rows
    | .error message => return .error message
  if candidates != ready.candidates then
    return .error "Admitted accounts changed. Reopen Balance display setup."
  let path := Loam.HouseholdPaths.balanceView root
  let raw ←
    match ← rawConfig path with
    | .ok raw => pure raw
    | .error message => return .error message
  if raw != ready.rawBefore then
    return .error "Balance view changed while editing. Reopen setup."
  let otherMeasures := ready.previous.filter (fun c => c.measure != measure)
  let updated := otherMeasures ++ chosen
  let body := String.intercalate "" (updated.map fun c =>
    c.locus.token ++ "\t" ++ c.measure.token ++ "\n")
  if Loam.BalanceViewConfig.decode? body != some updated then
    return .error "Balance view could not be encoded. No changes made."
  if raw == some body then return .ok ()
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  try
    if ← stage.pathExists then
      return .error "A previous Balance view staging file exists; inspect before saving."
    IO.FS.createDirAll (Loam.HouseholdPaths.configDir root)
    Loam.Persistence.replaceTextViaSiblingStage path body
    match ← Loam.BalanceViewConfig.load? path with
    | some actual =>
        if actual == updated then return .ok ()
        return .error "Saved Balance view differs from selection."
    | none => return .error "Saved Balance view could not be decoded."
  catch error =>
    return .error ("Balance view publication refused: " ++ error.toString)

def run (bounds : Bounds) (root : System.FilePath) (measure : MeasureId) :
    IO String := do
  let ready ←
    match ← prepare root measure with
    | .ok ready => pure ready
    | .error message => return ("Balance display setup unavailable: " ++ message)
  let chosen := ready.previous.filter (fun c => c.measure == measure)
  let state := Loam.Tui.DailyPacePoolSetup.initialBalanceDisplay
    measure ready.candidates chosen
  let frame := compileWidget (Loam.Tui.DailyPacePoolSetup.view bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  Loam.Tui.EditorSession.runUntilPublishedResizing
    bounds
    (fun _ state key => Loam.Tui.DailyPacePoolSetup.update state key)
    Loam.Tui.DailyPacePoolSetup.view
    Loam.Tui.DailyPacePoolSetup.withError
    "Balance display setup cancelled."
    (fun selected => do
      match ← save root measure ready selected with
      | .ok () => return .ok "Visible Balance accounts saved. Unknown values remain '?'."
      | .error message => return .error message)
    state frame

end Loam.Tui.BalanceViewSetupSession
