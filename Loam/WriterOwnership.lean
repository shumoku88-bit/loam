import Std

namespace Loam.WriterOwnership

set_option autoImplicit false

/-!
# Cross-process writer ownership

Whole-memory publication is a read/prepare/admit/replace operation. Atomic
replacement of one file does not by itself prevent a second process from
publishing a stale replacement after the first writer completed.

This runtime boundary provides one small process-level exclusion scope. The
anchor is the canonical EventMemory path for the writer group. A persistent
sibling lock file supplies a stable file handle, while ownership itself is the
OS-managed exclusive lock held on that handle.

The lock file is not a semantic fact, revision, manifest, Event identity, or
recovery record. It is deliberately not deleted after use. Process death
releases the OS lock, as qualified by Application 005, so no stale lock-file
cleanup protocol is introduced.
-/

/-- Stable sibling path whose handle carries process-level writer ownership. -/
private def lockPath (anchor : System.FilePath) : System.FilePath :=
  System.FilePath.mk (anchor.toString ++ ".loam-writer-lock")

/--
Run one complete writer operation under exclusive cross-process ownership.

Callers acquire ownership before observing canonical persisted state and retain
it through preparation, Core admission, and final publication. A correction
writer therefore uses the EventMemory path as the common anchor while it
publishes Correction first and Event second inside the same action.

The sibling lock file is opened in append mode only to obtain/create a stable
handle without truncating it. The OS lock, not file contents or file existence,
is the ownership primitive. `finally` releases ownership on ordinary Lean
exceptions; process termination releases the underlying OS lock.
-/
def withOwnership {α : Type}
    (anchor : System.FilePath)
    (action : IO α) : IO α := do
  let path := lockPath anchor
  IO.FS.withFile path .append fun handle => do
    handle.lock (exclusive := true)
    try
      action
    finally
      handle.unlock

end Loam.WriterOwnership
