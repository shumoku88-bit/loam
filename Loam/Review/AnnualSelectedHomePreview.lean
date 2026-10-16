import Loam.Authority.AnnualSandboxDurabilityBarriers
import Loam.Review.AnnualSourceReadView
import Loam.Tui.Cli
import Loam.ActualDate
import Loam.Persistence.WriterOwnership

namespace Loam.AnnualSelectedHomePreview

set_option autoImplicit false

/-!
# Read-only preview of a selected native year-source in real Home composition

**Research only.** This intentionally does NOT register a second production
authority or change the CLI/TUI's default source root. The annual source is
selected via ONE externally pinned HEAD on a *marked disposable root*, and its
entire native HouseholdImage is supplied to the existing Home composer.

The caller's config root supplies current query/presentation TSVs. These are
not persisted by the annual source, nor claimed to be as-known historical policy.
The caller-supplied HEAD pin is a test oracle, not a trusted monotonic receipt.
-/

structure Snapshot where
  selected : Loam.AnnualSourceHeadSandbox.Selected
  view : Loam.AnnualSourceReadView.Snapshot
  home : Loam.Tui.Main.Snapshot

/-- Reuse the production Home composition from ONE qualified annual HEAD.
The required independent expected HEAD rules out silent valid-old rollback
within this experiment. The final user-facing TUI is still unchanged. -/
def load?
    (configRoot annualRoot : System.FilePath)
    (expectedHeadWire today : String) : IO (Except String Snapshot) := do
  if configRoot.toString == annualRoot.toString then
    return .error "loam: annual preview needs a separate disposable source root"
  if !Loam.ActualDate.validIsoDate today then
    return .error "loam: annual Home observation day invalid"
  try
    let markerPath := annualRoot / Loam.AnnualSandboxDurabilityBarriers.markerFile
    if !(← markerPath.pathExists) ||
        (← IO.FS.readFile markerPath) !=
          Loam.AnnualSandboxDurabilityBarriers.markerBody then
      return .error "loam: annual Home preview requires a marked disposable root"
    if ← (annualRoot / Loam.HouseholdAuthority.fileName).pathExists then
      return .error "loam: annual Home preview refuses a second HouseholdImage owner"
    Loam.WriterOwnership.withOwnership
        (Loam.AnnualSourceHeadSandbox.headPath annualRoot) do
      let .ok selected ← Loam.AnnualSourceHeadSandbox.readSelected? annualRoot
        | return .error "loam: selected annual HEAD missing, corrupt, or not replayable"
      if selected.headWire != expectedHeadWire then
        return .error "loam: annual Home preview selected a stale or unpinned HEAD"
      let .ok view := Loam.AnnualSourceReadView.fromGeneration? selected.generation
        | return .error "loam: annual Home native required evidence is invalid"
      let .ok home ← Loam.Tui.Cli.loadSnapshotFromActualImage
          configRoot today view.actual (some selected.generation) false
        | return .error "loam: annual selected generation failed Home composition"
      if !home.scheduled.isOk then
        return .error "loam: annual Home Scheduled is not qualified"
      return .ok { selected, view, home }
  catch error =>
    return .error s!"loam: annual Home selected read refused: {error}"

end Loam.AnnualSelectedHomePreview
