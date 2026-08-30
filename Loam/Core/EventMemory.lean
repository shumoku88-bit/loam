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

end EventMemory

end Loam.Core
