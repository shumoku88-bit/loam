import Loam.Authority.AnnualSourceMaterialization
import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview
import Loam.Review.CurrentBalanceReview
import Loam.Review.CycleSpendingPaceReview

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
  currentBalances : Loam.CurrentBalanceReview.Snapshot

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
  let currentBalances ←
    Loam.CurrentBalanceReview.projectFromGeneration generation actual
  return { generation, actual, actualRecords, scheduled, openScheduled, currentBalances }

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

/-- Compute one current Daily Pace answer from the exact support, Actual and
Scheduled evidence already captured by this view. The caller MUST explicitly
supply its query policy (Measure, selected pool, observation day and cycle end).
A source year is not a pension-cycle boundary. Configuration files are not
captured by the annual journal here, so this deliberately never reads them or
claims to reproduce an independently edited policy's historical "as-known" view.
Unknown exact quantities fail through CurrentBalanceReview.selectExact. -/
def Snapshot.paceForMeasure?
    (view : Snapshot)
    (measure : Loam.Core.MeasureId)
    (observedAt endExclusive : String)
    (selection : List Loam.Core.EffectCoordinate) :
    Except String Loam.CycleSpendingPaceReview.Snapshot := do
  if selection.isEmpty then
    throw "loam: annual Daily Pace requires an explicitly selected nonempty pool"
  let selected ←
    Loam.CurrentBalanceReview.selectExact view.currentBalances selection
  Loam.CycleSpendingPaceReview.projectForMeasure
    measure observedAt endExclusive selection selected view.scheduled

end Loam.AnnualSourceReadView
