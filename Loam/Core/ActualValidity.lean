import Loam.Core.Event
import Init.Data.List.Perm

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

private def findEntryByEventId? : List (ActualValidity Time) → EventId → Option Time
  | [], _ => none
  | entry :: rest, id =>
      if entry.event = id then
        some entry.validOn
      else
        findEntryByEventId? rest id

private theorem findEntryByEventId?_perm
    {left right : List (ActualValidity Time)}
    (hPerm : left.Perm right)
    (hNodup : (left.map ActualValidity.event).Nodup)
    (id : EventId) :
    findEntryByEventId? left id = findEntryByEventId? right id := by
  induction hPerm with
  | nil => rfl
  | cons entry hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : entry.event = id
      · simp [findEntryByEventId?, h]
      · simp [findEntryByEventId?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : y.event ≠ x.event := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : y.event = id
      · have hx : x.event ≠ id := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findEntryByEventId?, hy, hx]
      · by_cases hx : x.event = id
        · simp [findEntryByEventId?, hy, hx]
        · simp [findEntryByEventId?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map ActualValidity.event).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/--
Find the valid coordinate for an EventId.
Because `eventNodup` ensures at most one entry per EventId, lookup is
independent of list order.
-/
def findByEventId? (memory : ActualValidityMemory Time) (id : EventId) : Option Time :=
  findEntryByEventId? memory.entries id

/--
Event validity lookup is invariant under permutation of ActualValidityMemory's entries.
-/
theorem findByEventId?_perm
    (left right : ActualValidityMemory Time)
    (hPerm : left.entries.Perm right.entries)
    (id : EventId) :
    findByEventId? left id = findByEventId? right id := by
  simpa [findByEventId?] using
    findEntryByEventId?_perm hPerm left.eventNodup id

end ActualValidityMemory

end Loam.Core
