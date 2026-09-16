import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledContinuationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled continuation session

This session starts only after one Scheduled completion has already been
published. It owns the optional next-Scheduled interaction that follows that
fact: seed the next editor from the completed expectation, run the existing
creation session, inherit predecessor routing when a continuation is created,
and compose the final human-facing notice.

It deliberately does not own completion publication, Locus-catalog loading
policy, canonical reload, or destination-workspace refresh. The catalog loader
is passed as an `IO` action so it is executed only after the next editor can be
seeded, preserving the existing effect order.
-/

private def completedNotice (record : Loam.Tui.Main.ScheduledRecord) : String :=
  "Completed " ++ record.id.token ++ "."

private def routingNotice
    (root : System.FilePath) (record : Loam.Tui.Main.ScheduledRecord)
    (created : Loam.Core.ScheduledId) (effectiveOn : String) : IO String := do
  match ← Loam.HouseholdCommand.inheritScheduledRouting
      root record.id created effectiveOn with
  | .error err =>
      return s!" (routing inheritance failed: {err})"
  | .ok report =>
      let notices := report.formatOutcomes
      return if notices.isEmpty then "" else " (" ++ String.intercalate ", " notices ++ ")"

/--
Run the optional continuation interaction after completion has already published.
The returned notice includes the completed predecessor result.
-/
def runAfterCompletion
    (bounds : Bounds) (root : System.FilePath)
    (known : List String) (record : Loam.Tui.Main.ScheduledRecord)
    (effectiveOn : String) (loadCatalog : IO Loam.LocusCatalog.Catalog) : IO String := do
  let completed := completedNotice record
  match Loam.Tui.ScheduledCreation.initialFromScheduled? record with
  | .error message =>
      return completed ++ " Next Scheduled editor unavailable: " ++ message
  | .ok editor =>
      let catalog ← loadCatalog
      let editor := Loam.Tui.ScheduledCreation.withCatalog editor catalog
      let frame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
      Loam.Tui.Terminal.redrawFromBlank bounds frame
      let (created?, creationNotice) ← Loam.Tui.ScheduledCreationSession.runWithScheduledId
        bounds root known editor frame
      match created? with
      | none =>
          return completed ++ " No next Scheduled created."
      | some created =>
          let routeNotice ← routingNotice root record created effectiveOn
          return completed ++ " " ++ creationNotice ++ routeNotice

end Loam.Tui.ScheduledContinuationSession
