import Init.Data.List.Perm
import Loam.Core.EventMemory
import Loam.Core.ScheduledMemory
import Loam.Core.CapacityMemory
import Loam.Core.AttentionMemory

namespace Observation232

open Loam.Core

set_option autoImplicit false

/-!
Observation 232 asks whether repeated Core memory machinery is one reusable
finite-keyed-list structure without collapsing Event, Scheduled, Capacity, or
Attention into one household concept.

The candidate here is intentionally mechanical. Domain memories keep their own
semantic types and field names; the experiment only factors the finite keyed
collection shape and the representation-order-independent lookup law.
-/

/-- A finite represented list whose selected key occurs at most once. -/
structure KeyedMemory (Item Key : Type) (keyOf : Item → Key) where
  entries : List Item
  keyNodup : (entries.map keyOf).Nodup

namespace KeyedMemory

/-- Admit a represented list exactly when its selected keys are unique. -/
def ofEntries? {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    (entries : List Item) : Option (KeyedMemory Item Key keyOf) :=
  if h : (entries.map keyOf).Nodup then
    some { entries := entries, keyNodup := h }
  else
    none

/-- Append one represented value, rejecting a repeated selected key. -/
def add? {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    (memory : KeyedMemory Item Key keyOf)
    (entry : Item) : Option (KeyedMemory Item Key keyOf) :=
  ofEntries? keyOf (memory.entries ++ [entry])

private def findIn? {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key) : List Item → Key → Option Item
  | [], _ => none
  | entry :: rest, key =>
      if keyOf entry = key then
        some entry
      else
        findIn? keyOf rest key

/-- Find the unique represented value carrying one selected key. -/
def findByKey? {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    (memory : KeyedMemory Item Key keyOf)
    (key : Key) : Option Item :=
  findIn? keyOf memory.entries key

private theorem findIn?_perm
    {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    {left right : List Item}
    (hPerm : left.Perm right)
    (hNodup : (left.map keyOf).Nodup)
    (key : Key) :
    findIn? keyOf left key = findIn? keyOf right key := by
  induction hPerm with
  | nil =>
      rfl
  | cons entry hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : keyOf entry = key
      · simp [findIn?, h]
      · simp [findIn?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : keyOf y ≠ keyOf x := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : keyOf y = key
      · have hx : keyOf x ≠ key := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findIn?, hy, hx]
      · by_cases hx : keyOf x = key
        · simp [findIn?, hy, hx]
        · simp [findIn?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map keyOf).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/-- Key lookup depends on keyed membership, not list representation order. -/
theorem findByKey?_perm
    {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    (left right : KeyedMemory Item Key keyOf)
    (hPerm : left.entries.Perm right.entries)
    (key : Key) :
    findByKey? keyOf left key = findByKey? keyOf right key := by
  simpa [findByKey?] using
    findIn?_perm keyOf hPerm left.keyNodup key

end KeyedMemory

/-!
## Existing semantic memories as the same retained keyed-list shape

These adapters are deliberately bidirectional. They demonstrate representation
isomorphism while preserving the existing domain types as the public semantic
boundary.
-/

def fromEventMemory (memory : EventMemory) :
    KeyedMemory Event EventId Event.id :=
  { entries := memory.events, keyNodup := memory.idNodup }

def toEventMemory (memory : KeyedMemory Event EventId Event.id) : EventMemory :=
  { events := memory.entries, idNodup := memory.keyNodup }

@[simp] theorem event_roundtrip (memory : EventMemory) :
    toEventMemory (fromEventMemory memory) = memory := by
  cases memory
  rfl

@[simp] theorem keyed_event_roundtrip
    (memory : KeyedMemory Event EventId Event.id) :
    fromEventMemory (toEventMemory memory) = memory := by
  cases memory
  rfl


def fromScheduledMemory {Time : Type} (memory : ScheduledMemory Time) :
    KeyedMemory (ScheduledOccurrence Time) ScheduledId ScheduledOccurrence.id :=
  { entries := memory.occurrences, keyNodup := memory.idNodup }

def toScheduledMemory {Time : Type}
    (memory : KeyedMemory (ScheduledOccurrence Time) ScheduledId ScheduledOccurrence.id) :
    ScheduledMemory Time :=
  { occurrences := memory.entries, idNodup := memory.keyNodup }

@[simp] theorem scheduled_roundtrip {Time : Type} (memory : ScheduledMemory Time) :
    toScheduledMemory (fromScheduledMemory memory) = memory := by
  cases memory
  rfl

@[simp] theorem keyed_scheduled_roundtrip {Time : Type}
    (memory : KeyedMemory (ScheduledOccurrence Time) ScheduledId ScheduledOccurrence.id) :
    fromScheduledMemory (toScheduledMemory memory) = memory := by
  cases memory
  rfl


def fromCapacityMemory (memory : CapacityMemory) :
    KeyedMemory CapacityMovement CapacityMovementId CapacityMovement.id :=
  { entries := memory.movements, keyNodup := memory.idNodup }

def toCapacityMemory
    (memory : KeyedMemory CapacityMovement CapacityMovementId CapacityMovement.id) :
    CapacityMemory :=
  { movements := memory.entries, idNodup := memory.keyNodup }

@[simp] theorem capacity_roundtrip (memory : CapacityMemory) :
    toCapacityMemory (fromCapacityMemory memory) = memory := by
  cases memory
  rfl

@[simp] theorem keyed_capacity_roundtrip
    (memory : KeyedMemory CapacityMovement CapacityMovementId CapacityMovement.id) :
    fromCapacityMemory (toCapacityMemory memory) = memory := by
  cases memory
  rfl


def fromAttentionMemory {Time : Type} (memory : AttentionMemory Time) :
    KeyedMemory (Attention Time) AttentionId Attention.id :=
  { entries := memory.items, keyNodup := memory.idNodup }

def toAttentionMemory {Time : Type}
    (memory : KeyedMemory (Attention Time) AttentionId Attention.id) :
    AttentionMemory Time :=
  { items := memory.entries, idNodup := memory.keyNodup }

@[simp] theorem attention_roundtrip {Time : Type} (memory : AttentionMemory Time) :
    toAttentionMemory (fromAttentionMemory memory) = memory := by
  cases memory
  rfl

@[simp] theorem keyed_attention_roundtrip {Time : Type}
    (memory : KeyedMemory (Attention Time) AttentionId Attention.id) :
    fromAttentionMemory (toAttentionMemory memory) = memory := by
  cases memory
  rfl

/-!
## Admission equivalence

The existing domain constructors and the generic mechanical constructor ask the
same uniqueness question. Comparing `isSome` deliberately ignores proof-object
and wrapper representation while preserving the fail-closed admission answer.
-/

theorem event_admission_equivalent (events : List Event) :
    (EventMemory.ofEvents? events).isSome =
      (KeyedMemory.ofEntries? Event.id events).isSome := by
  by_cases h : (events.map Event.id).Nodup
  · simp [EventMemory.ofEvents?, KeyedMemory.ofEntries?, h]
  · simp [EventMemory.ofEvents?, KeyedMemory.ofEntries?, h]

theorem scheduled_admission_equivalent {Time : Type}
    (occurrences : List (ScheduledOccurrence Time)) :
    (ScheduledMemory.ofOccurrences? occurrences).isSome =
      (KeyedMemory.ofEntries? ScheduledOccurrence.id occurrences).isSome := by
  by_cases h : (occurrences.map ScheduledOccurrence.id).Nodup
  · simp [ScheduledMemory.ofOccurrences?, KeyedMemory.ofEntries?, h]
  · simp [ScheduledMemory.ofOccurrences?, KeyedMemory.ofEntries?, h]

theorem capacity_admission_equivalent (movements : List CapacityMovement) :
    (CapacityMemory.ofMovements? movements).isSome =
      (KeyedMemory.ofEntries? CapacityMovement.id movements).isSome := by
  by_cases h : (movements.map CapacityMovement.id).Nodup
  · simp [CapacityMemory.ofMovements?, KeyedMemory.ofEntries?, h]
  · simp [CapacityMemory.ofMovements?, KeyedMemory.ofEntries?, h]

theorem attention_admission_equivalent {Time : Type}
    (items : List (Attention Time)) :
    (AttentionMemory.ofItems? items).isSome =
      (KeyedMemory.ofEntries? Attention.id items).isSome := by
  by_cases h : (items.map Attention.id).Nodup
  · simp [AttentionMemory.ofItems?, KeyedMemory.ofEntries?, h]
  · simp [AttentionMemory.ofItems?, KeyedMemory.ofEntries?, h]

/-!
## Generic permutation law instantiated at semantic boundaries

One proof now applies to every keyed family. No Event/Scheduled/Capacity/Attention
semantic equation is asserted by this reuse.
-/

theorem event_keyed_lookup_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (id : EventId) :
    KeyedMemory.findByKey? Event.id (fromEventMemory left) id =
      KeyedMemory.findByKey? Event.id (fromEventMemory right) id := by
  exact KeyedMemory.findByKey?_perm Event.id
    (fromEventMemory left) (fromEventMemory right) hPerm id

theorem scheduled_keyed_lookup_perm {Time : Type}
    (left right : ScheduledMemory Time)
    (hPerm : left.occurrences.Perm right.occurrences)
    (id : ScheduledId) :
    KeyedMemory.findByKey? ScheduledOccurrence.id (fromScheduledMemory left) id =
      KeyedMemory.findByKey? ScheduledOccurrence.id (fromScheduledMemory right) id := by
  exact KeyedMemory.findByKey?_perm ScheduledOccurrence.id
    (fromScheduledMemory left) (fromScheduledMemory right) hPerm id

theorem capacity_keyed_lookup_perm
    (left right : CapacityMemory)
    (hPerm : left.movements.Perm right.movements)
    (id : CapacityMovementId) :
    KeyedMemory.findByKey? CapacityMovement.id (fromCapacityMemory left) id =
      KeyedMemory.findByKey? CapacityMovement.id (fromCapacityMemory right) id := by
  exact KeyedMemory.findByKey?_perm CapacityMovement.id
    (fromCapacityMemory left) (fromCapacityMemory right) hPerm id

theorem attention_keyed_lookup_perm {Time : Type}
    (left right : AttentionMemory Time)
    (hPerm : left.items.Perm right.items)
    (id : AttentionId) :
    KeyedMemory.findByKey? Attention.id (fromAttentionMemory left) id =
      KeyedMemory.findByKey? Attention.id (fromAttentionMemory right) id := by
  exact KeyedMemory.findByKey?_perm Attention.id
    (fromAttentionMemory left) (fromAttentionMemory right) hPerm id

end Observation232
