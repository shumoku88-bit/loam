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

/--
Find one remembered Event by its stable identity.

This lookup observes `EventId` only. It does not expose or assign meaning to the
Event's list position and therefore introduces no `first`, `latest`, temporal,
causal, priority, authority, or posting-order semantics.
-/
def findById? (memory : EventMemory) (id : EventId) : Option Event :=
  findEventById? memory.events id

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
