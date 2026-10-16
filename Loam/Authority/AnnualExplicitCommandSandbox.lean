import Loam.HouseholdCommand
import Loam.Authority.AnnualSingleOwnerMovementSandbox
import Loam.Authority.AnnualSandboxDurabilityBarriers

namespace Loam.AnnualExplicitCommandSandbox

open Loam.Core

set_option autoImplicit false

/-!
# Explicit single-owner Movement routing, synthetic roots only

No production CLI/TUI calls this module. Both possible target roots require
a test-only marker and cannot contain BOTH authoritative representations.
Selection is caller-explicit, never guessed from files or silently changed
after a failed write. This is a rehearsal for a future ordinary command
boundary, not a migration selector nor an adversarial filesystem guard.
-/

/-- Source choice is required as input. The annual choice carries an exact
caller-provided expected HEAD, not a guessed newest journal year. -/
inductive Target where
  | ordinary (root : System.FilePath)
  | annual (root : System.FilePath) (expectedHeadWire : String)

/-- Existing household errors and idempotent replay results remain EXACTLY
as returned by the ordinary command path. In particular a legacy .error
could follow an uncertain I/O outcome and is not converted into a definite
pre-commit refusal. The annual path retains committed/refused/unknown
distinctions and expected Event ID. -/
inductive RoutedMovement where
  | ordinary (result : Except String Loam.MovementPublisher.IdempotentResult)
  | annual (result : Loam.AnnualSingleOwnerSandbox.MovementOutcome)
  | refusedSelection (reason : String)

/-- Marker is purely an accident-prevention aid for isolated test roots.
Never create it here or automatically turn a legacy root into annual. -/
private def marked? (root : System.FilePath) : IO Bool := do
  try
    let marker := root / Loam.AnnualSandboxDurabilityBarriers.markerFile
    return (← marker.pathExists) &&
      (← IO.FS.readFile marker) ==
        Loam.AnnualSandboxDurabilityBarriers.markerBody
  catch _ =>
    return false

/-- Route precisely ONE idempotent practical Movement to the source chosen by
the caller. The ordinary branch invokes the *existing* HouseholdCommand, with
its own established admission/locking semantics. The annual branch invokes
the same pinned HEAD CAS Movement operation qualified in #2054/#2055.
Neither branch calls the other after any error or uncertain outcome.

An actual product cutover would need authenticated freshness, a trusted
admission day, robust race-free filesystem capability checks, migration and
restore UX. None is implied by this synthetic-only gate. -/
def recordIdempotent?
    (target : Target)
    (admittedDay : String)
    (operation : MovementOperationId)
    (draft : Loam.MovementAdmission.Draft) : IO RoutedMovement := do
  match target with
  | .ordinary root =>
      unless ← marked? root do
        return .refusedSelection "loam: ordinary test route needs disposable marker"
      if ← (Loam.AnnualSourceHeadSandbox.headPath root).pathExists then
        return .refusedSelection "loam: ordinary route refuses competing annual HEAD"
      if !(← (Loam.HouseholdAuthority.path root).pathExists) then
        return .refusedSelection "loam: ordinary route requires installed household.loam"
      -- No reinterpretation of legacy IO/Except as a publication receipt.
      return .ordinary
        (← Loam.HouseholdCommand.recordIdempotent root operation draft)
  | .annual root expectedHeadWire =>
      unless ← marked? root do
        return .refusedSelection "loam: annual test route needs disposable marker"
      let .ok pin ← Loam.AnnualSingleOwnerSandbox.open? root expectedHeadWire
        | return .refusedSelection
            "loam: annual route rejects invalid, mixed, corrupt or unpinned source"
      return .annual (← pin.recordMovement? admittedDay operation draft)

end Loam.AnnualExplicitCommandSandbox
