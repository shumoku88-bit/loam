import Loam.Review.AnnualSelectedHomePreview
import Loam.Authority.AnnualSandboxDurabilityBarriers

namespace Loam.AnnualSingleOwnerSandbox

set_option autoImplicit false

/-!
# Experimental, single-source annual read/write session

One *explicitly expected* native annual HEAD is both the read generation
and the compare-and-swap predecessor of a new native source publication.
No `household.loam` owner exists in the selected annual root, and there
is no legacy write-through, fallback read, or automatic source selection.

A caller-provided expectation can itself be old: it is NOT a monotonic
freshness anchor, an authenticated receipt, or a production cutover gate.
Only marked throwaway roots are admitted. Ordinary LOAM writers are unchanged.
-/

structure Pinned where
  root : System.FilePath
  selected : Loam.AnnualSourceHeadSandbox.Selected

/-- Admit only an isolated source. The marker guards accidental tests, NOT
adversarial filesystem access. Crucially never create it from this API. -/
private def eligible?
    (root : System.FilePath) : IO (Except String Unit) := do
  try
    let marker := root / Loam.AnnualSandboxDurabilityBarriers.markerFile
    if !(← marker.pathExists) ||
        (← IO.FS.readFile marker) !=
          Loam.AnnualSandboxDurabilityBarriers.markerBody then
      return .error "loam: annual session requires marked disposable source root"
    if ← (Loam.HouseholdAuthority.path root).pathExists then
      return .error "loam: annual session refuses a competing household.loam owner"
    if !(← (Loam.AnnualSourceHeadSandbox.headPath root).pathExists) then
      return .error "loam: annual session does not bootstrap an absent HEAD"
    return .ok ()
  catch error =>
    return .error s!"loam: annual session root qualification failed: {error}"

/-- Open ONLY the exact externally expected selected HEAD under its writer
lock. Never infer a newest year by scanning the directory or accept .prev. -/
def open?
    (root : System.FilePath) (expectedHeadWire : String) :
    IO (Except String Pinned) := do
  let .ok () ← eligible? root
    | return .error "loam: annual session source not qualified"
  try
    Loam.WriterOwnership.withOwnership
        (Loam.AnnualSourceHeadSandbox.headPath root) do
      let .ok () ← eligible? root
        | return .error "loam: annual source changed during selection"
      let .ok selected ← Loam.AnnualSourceHeadSandbox.readSelected? root
        | return .error "loam: annual selected HEAD or its closure is not replayable"
      if selected.headWire != expectedHeadWire then
        return .error "loam: annual session refuses an unpinned or stale HEAD"
      return .ok { root, selected }
  catch error =>
    return .error s!"loam: annual session selection failed: {error}"

/-- Reuse the EXACT ordinary TUI Home composition. If the selected HEAD has
changed since this pin, this returns a refusal rather than a silent refresh. -/
def Pinned.readHome?
    (pin : Pinned) (configRoot : System.FilePath) (today : String) :
    IO (Except String Loam.AnnualSelectedHomePreview.Snapshot) := do
  let .ok () ← eligible? pin.root
    | return .error "loam: annual Home read source no longer qualified"
  Loam.AnnualSelectedHomePreview.load?
    configRoot pin.root pin.selected.headWire today

/-- Publication is exclusively through the *same* annual HEAD. The underlying
native Lean writer acquires its existing HEAD lock and uses `observedHeadWire`
as a CAS guard, then synchronizes source and HEAD through Linux fsync /
Darwin APFS F_FULLFSYNC. No competing household image is written.

An error after the HEAD rename is `.outcomeUnknown`, not success/failure.
The caller must NOT retry an uncertain operation blindly. -/
def Pinned.append?
    (pin : Pinned)
    (admittedDay operation : String)
    (changedNames : List String)
    (candidate : Loam.Persistence.HouseholdImage.Image) :
    IO Loam.AnnualSourceHeadSandbox.AppendOutcome := do
  let .ok () ← eligible? pin.root
    | return .refusedBeforeHead
        "loam: annual append requires one isolated marked source owner"
  Loam.AnnualSourceHeadSandbox.appendWithOutcome?
    pin.root pin.selected.headWire admittedDay operation
    changedNames candidate
    (Loam.AnnualSandboxDurabilityBarriers.barriers pin.root)

end Loam.AnnualSingleOwnerSandbox
