import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.MovementWorldLoader
import Loam.Tui.Record

namespace Loam.Tui.UnresolvedActivation

set_option autoImplicit false

/-!
# On-demand unresolved-recording activation

This is presentation orchestration only.

The semantic operation remains one ordinary add-only LocusAdmission publication
for `suspense`. No Core suspense type, authority, Measure, AccountingRole,
Purpose, or Attention fact is created here.

After that independent policy publication, the selected Movement world is
reloaded before any Record-shaped draft is changed.
-/

structure Enabled where
  world : Loam.MovementAdmission.World
  known : List String
  catalog : Loam.LocusCatalog.Catalog

structure EnabledEditor where
  world : Loam.MovementAdmission.World
  known : List String
  editor : Loam.Tui.Record.State

private def fromWorld
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO Enabled := do
  let catalog ←
    match ← Loam.LocusCatalog.loadForVocabulary root world.locusAdmission with
    | .ok catalog => pure catalog
    | .error _ => pure (Loam.LocusCatalog.fallback world.locusAdmission)
  return {
    world := world
    known := world.locusAdmission.approved.map (fun locus => locus.token)
    catalog := catalog }

/--
Enable the ordinary unresolved Locus and then re-read canonical Movement policy.

If another writer admitted the same Locus between confirmation and publication,
the add-only publisher may report a duplicate. A fresh authoritative re-read is
then sufficient to treat the requested capability as enabled when the Locus is
indeed present.
-/
def enable?
    (root : System.FilePath) : IO (Except String Enabled) := do
  let admission ← Loam.HouseholdCommand.admitLocus root {
    token := Loam.Tui.Record.unresolvedLocus.token }
  match admission with
  | .ok () =>
      match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
      | .error message =>
          return .error
            ("Unresolved recording was enabled, but the refreshed household world could not be loaded: " ++
              message)
      | .ok world =>
          if world.locusAdmission.allows Loam.Tui.Record.unresolvedLocus then
            return .ok (← fromWorld root world)
          else
            return .error
              "Unresolved recording admission completed, but the refreshed policy does not contain suspense."
  | .error admissionMessage =>
      match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
      | .ok world =>
          if world.locusAdmission.allows Loam.Tui.Record.unresolvedLocus then
            return .ok (← fromWorld root world)
          else
            return .error admissionMessage
      | .error _ =>
          return .error admissionMessage

def withEnableError
    (editor : Loam.Tui.Record.State) (message : String) : Loam.Tui.Record.State :=
  { editor with mode := .editing, notice := "Unresolved recording was not enabled: " ++ message }

/-- Enable unresolved recording and rebuild one Record-shaped editor from the refreshed world. -/
def enableEditor?
    (root : System.FilePath)
    (editor : Loam.Tui.Record.State) : IO (Except String EnabledEditor) := do
  let enabled ← enable? root
  match enabled with
  | .error message => return .error message
  | .ok enabled =>
      let base := Loam.Tui.Record.withCatalog { editor with mode := .editing } enabled.catalog
      let editor :=
        match Loam.Tui.Record.fillUnresolvedRemainder? enabled.world base with
        | .ok filled =>
            { filled with notice := "Unresolved recording enabled; remainder filled." }
        | .error message =>
            { base with notice := "Unresolved recording enabled. " ++ message }
      return .ok { world := enabled.world, known := enabled.known, editor := editor }

end Loam.Tui.UnresolvedActivation
