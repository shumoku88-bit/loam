import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled retirement evidence

Observation 105 showed that a mutable open/closed summary is too small for
Scheduled lifecycle. Cancellation therefore enters Practical Core as explicit
retirement evidence rather than by mutating a Scheduled occurrence.

The first practical shape retains only the Scheduled identity whose expectation
has been retired. It deliberately has no independent identity, reason enum,
operation kind, or time coordinate. Those distinctions remain future pressure.
The practical CLI may present this evidence as cancellation without claiming
that every future retirement must mean exactly the same thing.
-/

/-- Explicit evidence that one Scheduled occurrence is retired from future expectation. -/
structure ScheduledRetirement where
  scheduled : ScheduledId
deriving Repr, DecidableEq

/-- Append-oriented retirement evidence with at most one retirement per Scheduled identity. -/
structure ScheduledRetirementMemory where
  retirements : List ScheduledRetirement
  scheduledNodup : (retirements.map ScheduledRetirement.scheduled).Nodup

namespace ScheduledRetirementMemory

/-- Admit retirement evidence only when Scheduled identities are unique. -/
def ofRetirements? (retirements : List ScheduledRetirement) : Option ScheduledRetirementMemory :=
  if hScheduled : (retirements.map ScheduledRetirement.scheduled).Nodup then
    some {
      retirements := retirements
      scheduledNodup := hScheduled
    }
  else
    none

/-- Append one retirement while preserving Scheduled-identity uniqueness. -/
def add?
    (memory : ScheduledRetirementMemory)
    (retirement : ScheduledRetirement) : Option ScheduledRetirementMemory :=
  ofRetirements? (memory.retirements ++ [retirement])

private def findByScheduledIn :
    List ScheduledRetirement → ScheduledId → Option ScheduledRetirement
  | [], _ => none
  | retirement :: rest, id =>
      if retirement.scheduled = id then
        some retirement
      else
        findByScheduledIn rest id

/-- Find retained retirement evidence for one Scheduled identity. -/
def findByScheduled?
    (memory : ScheduledRetirementMemory)
    (id : ScheduledId) : Option ScheduledRetirement :=
  findByScheduledIn memory.retirements id

@[simp] theorem ofRetirements?_nil :
    ofRetirements? [] =
      some {
        retirements := []
        scheduledNodup := by simp
      } := by
  simp [ofRetirements?]

end ScheduledRetirementMemory

end Loam.Core
