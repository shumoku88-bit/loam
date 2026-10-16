import Loam.Authority.AnnualSourceMaterialization
import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview

namespace Loam.AnnualSourceReadView

set_option autoImplicit false

/-!
# One-generation source read view, behind native cutover parity

Future annual journal readers can supply a reconstructed full HouseholdImage,
but cannot independently select production source authority. This adapter
compares against the installed canonical HouseholdImage first, then composes
Actual and Scheduled from that **same immutable captured generation**.

No separate Actual/Scheduled file loads, mixed head reads, fallback to .prev,
new year initialization, source publication, or stored annual head selection.
-/

structure Snapshot where
  generation : Loam.HouseholdAuthority.Generation
  actual : Loam.ActualAuthority.Image
  actualRecords : List Loam.ActualReview.Record
  scheduled : Loam.ScheduledReview.EvidenceSnapshot
  openScheduled : List Loam.ScheduledReview.Record

/-- Compose all required evidence from one already-qualified generation.
A missing Actual, missing Scheduled, unclosed Scheduled completion, or invalid
current-open topology is an error, never a guessed empty answer. -/
def fromGeneration?
    (generation : Loam.HouseholdAuthority.Generation) :
    Except String Snapshot := do
  let actual ← Loam.ActualAuthority.decodeHouseholdGeneration? generation
  let scheduled ←
    Loam.ScheduledReview.fromGenerationForEvents
      generation actual.evidence.events
  let openScheduled ← Loam.ScheduledReview.orderedCurrentOpenRecords scheduled
  let actualRecords := Loam.ActualReview.recordsFromActualImage actual
  return { generation, actual, actualRecords, scheduled, openScheduled }

/-- Explicit read-only preflight. Only an exact byte-equivalent current-source
candidate can reach this read view; a previous but valid generation is refused.
Capture once under the existing writer lock and never reopen individual
families while constructing the view. -/
def compareInstalled?
    (root : System.FilePath)
    (candidateWire : String) : IO (Except String Snapshot) := do
  match ← Loam.AnnualSourceMaterialization.compareInstalled? root candidateWire with
  | .error message => return .error message
  | .ok generation => return fromGeneration? generation

end Loam.AnnualSourceReadView
