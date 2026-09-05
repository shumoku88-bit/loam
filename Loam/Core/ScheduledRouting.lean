import Loam.Core.HistoricalRouting
import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled routing coordinate

Observation 107 qualified the shared historical `RoutingHistory` mechanics across
Actual and Scheduled meaning. Observation 153 then qualified the Scheduled-side
subject as one aggregated `ScheduledId × LocusId` coordinate: whole Scheduled
identity is too coarse for split-purpose expectations, while bare Locus identity
merges distinct Scheduled intent.

This coordinate is reusable semantic evidence, not a Claim registry, Envelope
identity, or stored Commitment value.
-/

/-- Typed routing coordinate for one aggregated quantity-bearing Scheduled Locus. -/
structure ScheduledRoutingSubject where
  scheduled : ScheduledId
  locus : LocusId
deriving Repr, DecidableEq

/-- Shared historical-routing algebra specialized to Scheduled subjects. -/
abbrev ScheduledRoutingHistory (Time : Type) := RoutingHistory ScheduledRoutingSubject Time

end Loam.Core
