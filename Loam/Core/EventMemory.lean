import Init.Data.List.Perm
import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/--
A practical memory of several Events.

`events` is a deterministic representation for persistence and round-trip
stability. Its list position carries no built-in temporal, causal, priority,
authority, or posting-order meaning. Event identity remains explicit, so one
`EventId` may occur at most once in the memory.

No separate memory/collection identity is introduced here.
-/
structure EventMemory where
  events : List Event
  idNodup : (events.map Event.id).Nodup

namespace EventMemory

/--
Admit a runtime Event collection only when Event identity is not repeated.
Representation order is retained but does not become semantic history.
-/
def ofEvents? (events : List Event) : Option EventMemory :=
  if h : (events.map Event.id).Nodup then
    some { events := events, idNodup := h }
  else
    none

/-- Empty Event memory is valid. -/
@[simp] theorem ofEvents?_nil :
    ofEvents? [] = some { events := [], idNodup := by simp } := by
  simp [ofEvents?]

/-- One Event always has unique identity within a memory. -/
@[simp] theorem ofEvents?_singleton (event : Event) :
    ofEvents? [event] = some { events := [event], idNodup := by simp } := by
  simp [ofEvents?]

private def findEventById? : List Event → EventId → Option Event
  | [], _ => none
  | event :: rest, id =>
      if event.id = id then
        some event
      else
        findEventById? rest id

private theorem findEventById?_perm
    {left right : List Event}
    (hPerm : left.Perm right)
    (hNodup : (left.map Event.id).Nodup)
    (id : EventId) :
    findEventById? left id = findEventById? right id := by
  induction hPerm with
  | nil =>
      rfl
  | cons event hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : event.id = id
      · simp [findEventById?, h]
      · simp [findEventById?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : y.id ≠ x.id := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : y.id = id
      · have hx : x.id ≠ id := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findEventById?, hy, hx]
      · by_cases hx : x.id = id
        · simp [findEventById?, hy, hx]
        · simp [findEventById?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map Event.id).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/--
Find one remembered Event by its stable identity.

This lookup observes `EventId` only. It does not expose or assign meaning to the
Event's list position and therefore introduces no `first`, `latest`, temporal,
causal, priority, authority, or posting-order semantics.
-/
def findById? (memory : EventMemory) (id : EventId) : Option Event :=
  findEventById? memory.events id

/--
Identity lookup is invariant under permutation of the represented Events.
The memory admission law that rejects repeated `EventId` values is the condition
that makes a representation-order-independent lookup possible.
-/
theorem findById?_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (id : EventId) :
    findById? left id = findById? right id := by
  simpa [findById?] using
    findEventById?_perm hPerm left.idNodup id

@[simp] theorem findById?_empty (id : EventId) :
    findById? { events := [], idNodup := by simp } id = none := by
  simp [findById?, findEventById?]

@[simp] theorem findById?_singleton_self (event : Event) :
    findById? { events := [event], idNodup := by simp } event.id = some event := by
  simp [findById?, findEventById?]

theorem findById?_singleton_other
    (event : Event) (id : EventId) (h : event.id ≠ id) :
    findById? { events := [event], idNodup := by simp } id = none := by
  simp [findById?, findEventById?, h]

/--
Project every remembered Event onto one locus/measure coordinate and sum the
resulting exact quantities.

This is deliberately the aggregate of all recorded facts in the memory. It does
not apply correction, reversal, current-state, effective-state, temporal, or
accounting semantics. Later effective projections must therefore remain named
separately rather than silently changing the meaning of this function.
-/
def quantityAtRecorded
    (memory : EventMemory) (locus : LocusId) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    memory.events.foldr
      (fun event total => (Event.quantityAt event locus measure).quanta + total)
      0

private theorem quantityAtRecordedFold_perm
    {left right : List Event}
    (hPerm : left.Perm right)
    (locus : LocusId) (measure : MeasureId) :
    left.foldr
        (fun event total => (Event.quantityAt event locus measure).quanta + total)
        0 =
      right.foldr
        (fun event total => (Event.quantityAt event locus measure).quanta + total)
        0 := by
  induction hPerm with
  | nil => rfl
  | cons event hPerm ih =>
      simp only [List.foldr_cons]
      rw [ih]
  | swap x y rest =>
      simp only [List.foldr_cons]
      simp [Int.add_assoc, Int.add_comm, Int.add_left_comm]
  | trans hLeft hRight ihLeft ihRight =>
      exact ihLeft.trans ihRight

/--
The recorded aggregate is invariant under permutation of EventMemory's list
representation. Storage order therefore cannot change the quantity observed at
a locus/measure coordinate.
-/
theorem quantityAtRecorded_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (locus : LocusId) (measure : MeasureId) :
    quantityAtRecorded left locus measure = quantityAtRecorded right locus measure := by
  simpa [quantityAtRecorded] using
    congrArg Quantity.ofQuanta (quantityAtRecordedFold_perm hPerm locus measure)

/-- Empty recorded memory contributes exact zero at every coordinate. -/
@[simp] theorem quantityAtRecorded_empty
    (locus : LocusId) (measure : MeasureId) :
    quantityAtRecorded { events := [], idNodup := by simp } locus measure = 0 := by
  rfl

/-- A single remembered Event contributes exactly its own coordinate projection. -/
@[simp] theorem quantityAtRecorded_singleton
    (event : Event) (locus : LocusId) (measure : MeasureId) :
    quantityAtRecorded { events := [event], idNodup := by simp } locus measure =
      Event.quantityAt event locus measure := by
  simp [quantityAtRecorded]

/--
Add one complete Event to a memory, rejecting repeated Event identity.

The resulting list is a deterministic persistence representation only. The
fact that the added Event is represented at the end of that list does not make
it latest, later, more authoritative, or causally subsequent.
-/
def add? (memory : EventMemory) (event : Event) : Option EventMemory :=
  ofEvents? (memory.events ++ [event])

@[simp] theorem add?_empty (event : Event) :
    add? { events := [], idNodup := by simp } event =
      some { events := [event], idNodup := by simp } := by
  simp [add?, ofEvents?]

@[simp] theorem add?_singleton_duplicate (event : Event) :
    add? { events := [event], idNodup := by simp } event = none := by
  simp [add?, ofEvents?]

theorem add?_singleton_distinct
    (existing added : Event) (h : existing.id ≠ added.id) :
    add? { events := [existing], idNodup := by simp } added =
      some { events := [existing, added], idNodup := by simp [h] } := by
  simp [add?, ofEvents?, h]

end EventMemory

end Loam.Core
