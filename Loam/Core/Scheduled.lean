import Loam.Core.BalancedMovement
import Loam.Core.Effect

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled evidence

A Scheduled occurrence is an expectation, not a physical Actual Event.
Observation 105 earned stable scheduled identity plus a scheduled coordinate and
neutral quantity changes as the small content needed before lifecycle evidence.
Observation 106 allows the same exact balanced movement algebra to be reused
without collapsing semantic families.

The first practical entrance therefore stores no Plan object, status enum,
recurrence, completion flag, or lifecycle operation kind.
-/

/-- Stable identity for one retained scheduled occurrence. -/
structure ScheduledId where
  token : String
deriving Repr, DecidableEq

/--
One expected balanced movement at an explicit scheduled coordinate.

`Time` remains a parameter in Core. The practical adapter currently supplies an
ISO calendar-day string, but the semantic value does not depend on that parser.
-/
structure ScheduledOccurrence (Time : Type) where
  id : ScheduledId
  scheduledOn : Time
  movement : BalancedMovement LocusId

namespace ScheduledOccurrence

/-- Recover the explicit Measure carried by the mechanical movement. -/
def measure {Time : Type} (scheduled : ScheduledOccurrence Time) : MeasureId :=
  scheduled.movement.measure

/-- Project one expected signed quantity at a physical Locus coordinate. -/
def quantityAt {Time : Type}
    (scheduled : ScheduledOccurrence Time)
    (locus : LocusId) : Quantity :=
  BalancedMovement.quantityAt scheduled.movement locus

end ScheduledOccurrence

end Loam.Core
