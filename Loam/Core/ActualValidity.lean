import Loam.Core.Event
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/-!
# Actual validity evidence

Observation 111 demonstrates that Actual occurrence valid coordinates are
independently observable for historical Consumption routing, while
Observations 092–094 did not earn a built-in production Event temporal field.

This file provides the separate typed validity evidence linking an `EventId` to
its valid coordinate in a polymorphic time parameter.
-/

/--
Actual validity evidence attaching an occurrence-valid coordinate to an EventId.
Event structure itself remains free of date/time fields.
-/
structure ActualValidity (Time : Type) where
  event : EventId
  validOn : Time
deriving Repr, DecidableEq

/--
A practical memory of Actual occurrence valid coordinates.
Each `EventId` may have at most one valid coordinate. Representation order
carries no temporal, causal, or priority meaning.
-/
structure ActualValidityMemory (Time : Type) where
  entries : List (ActualValidity Time)
  eventNodup : (entries.map ActualValidity.event).Nodup

namespace ActualValidityMemory

variable {Time : Type}

/--
Admit a collection of validity evidence only when no EventId is repeated.
Duplicate valid coordinates for the same EventId are rejected (fail closed).
-/
def ofEntries?
    (entries : List (ActualValidity Time)) : Option (ActualValidityMemory Time) :=
  if h : (entries.map ActualValidity.event).Nodup then
    some { entries := entries, eventNodup := h }
  else
    none

/-- Empty validity memory is valid. -/
@[simp] theorem ofEntries?_nil :
    ofEntries? ([] : List (ActualValidity Time)) =
      some { entries := [], eventNodup := by simp } := by
  simp [ofEntries?]

/-- Single validity entry is valid. -/
@[simp] theorem ofEntries?_singleton (entry : ActualValidity Time) :
    ofEntries? [entry] = some { entries := [entry], eventNodup := by simp } := by
  simp [ofEntries?]

/--
Find the valid coordinate for an EventId.
Because `eventNodup` ensures at most one entry per EventId, lookup is
independent of list order.
-/
def findByEventId? (memory : ActualValidityMemory Time) (id : EventId) : Option Time :=
  (FiniteKeyed.findBy? ActualValidity.event memory.entries id).map ActualValidity.validOn

/--
Event validity lookup is invariant under permutation of ActualValidityMemory's entries.
-/
theorem findByEventId?_perm
    (left right : ActualValidityMemory Time)
    (hPerm : left.entries.Perm right.entries)
    (id : EventId) :
    findByEventId? left id = findByEventId? right id := by
  simpa [findByEventId?] using
    congrArg (fun result => result.map ActualValidity.validOn)
      (FiniteKeyed.findBy?_perm ActualValidity.event hPerm left.eventNodup id)

end ActualValidityMemory

end Loam.Core
