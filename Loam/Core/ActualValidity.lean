import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Actual validity evidence

Observation 111 demonstrates that Actual occurrence valid coordinates are
independently observable for historical Consumption routing, while
Observations 092–094 established that Event identity does not contain a built-in
temporal field.

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
def ofEntries? [DecidableEq Time]
    (entries : List (ActualValidity Time)) : Option (ActualValidityMemory Time) :=
  if h : (entries.map ActualValidity.event).Nodup then
    some { entries := entries, eventNodup := h }
  else
    none

/-- Empty validity memory is valid. -/
@[simp] theorem ofEntries?_nil [DecidableEq Time] :
    ofEntries? ([] : List (ActualValidity Time)) =
      some { entries := [], eventNodup := by simp } := by
  simp [ofEntries?]

/-- Single validity entry is valid. -/
@[simp] theorem ofEntries?_singleton [DecidableEq Time] (entry : ActualValidity Time) :
    ofEntries? [entry] = some { entries := [entry], eventNodup := by simp } := by
  simp [ofEntries?]

/--
Find the valid coordinate for an EventId.
Because `eventNodup` ensures at most one entry per EventId, lookup is
independent of list order.
-/
def findByEventId? (memory : ActualValidityMemory Time) (id : EventId) : Option Time :=
  match memory.entries.find? (fun entry => entry.event = id) with
  | some entry => some entry.validOn
  | none => none

end ActualValidityMemory

end Loam.Core
