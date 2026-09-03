import Loam.Core.Scheduled

namespace Loam.Core

set_option autoImplicit false

/-!
# Scheduled memory

Representation order is deterministic storage only. It is not chronological,
priority, lifecycle, or winner authority. Scheduled time comes only from each
occurrence's explicit `scheduledOn` coordinate.
-/

/-- Append-oriented memory for retained Scheduled occurrences. -/
structure ScheduledMemory (Time : Type) where
  occurrences : List (ScheduledOccurrence Time)
  idNodup : (occurrences.map ScheduledOccurrence.id).Nodup

namespace ScheduledMemory

/-- Admit runtime Scheduled values only when stable identity is unique. -/
def ofOccurrences? {Time : Type}
    (occurrences : List (ScheduledOccurrence Time)) : Option (ScheduledMemory Time) :=
  if h : (occurrences.map ScheduledOccurrence.id).Nodup then
    some { occurrences := occurrences, idNodup := h }
  else
    none

/-- Append one Scheduled occurrence, rejecting repeated identity. -/
def add? {Time : Type}
    (memory : ScheduledMemory Time)
    (occurrence : ScheduledOccurrence Time) : Option (ScheduledMemory Time) :=
  ofOccurrences? (memory.occurrences ++ [occurrence])

private def findOccurrenceById? {Time : Type} :
    List (ScheduledOccurrence Time) → ScheduledId → Option (ScheduledOccurrence Time)
  | [], _ => none
  | occurrence :: rest, id =>
      if occurrence.id = id then
        some occurrence
      else
        findOccurrenceById? rest id

/-- Find one retained Scheduled occurrence by stable identity. -/
def findById? {Time : Type}
    (memory : ScheduledMemory Time)
    (id : ScheduledId) : Option (ScheduledOccurrence Time) :=
  findOccurrenceById? memory.occurrences id

@[simp] theorem ofOccurrences?_nil {Time : Type} :
    ofOccurrences? ([] : List (ScheduledOccurrence Time)) =
      some { occurrences := [], idNodup := by simp } := by
  simp [ofOccurrences?]

@[simp] theorem ofOccurrences?_singleton {Time : Type}
    (occurrence : ScheduledOccurrence Time) :
    ofOccurrences? [occurrence] =
      some { occurrences := [occurrence], idNodup := by simp } := by
  simp [ofOccurrences?]

end ScheduledMemory

end Loam.Core
