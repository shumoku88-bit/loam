import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Minimal Event-scoped descriptive evidence

An `EventDescription` pairs an existing `EventId` with its unqualified human
recognizer text (e.g. merchant, item, channel, transfer memo, or opening assertion).
It is retained evidence for human recognition and presentation, kept separate
from Core quantity-placement facts.

Invariants:
- One `Event` may have zero or one `EventDescription`.
- Core balance and quantity projections do not observe or require description evidence.
- No independent `ContextId` is introduced; `EventId` is the unique key.
-/

/--
A single Event-scoped descriptive evidence fact.
Pairs an Event identifier with its unqualified human recognition text.
-/
structure EventDescription where
  event : EventId
  text : String
deriving Repr, DecidableEq

/--
A collection of Event descriptions where each EventId may appear at most once.
Row order retains practical representation only; it carries no chronological,
causal, priority, or authority meaning.
-/
structure EventDescriptionMemory where
  entries : List EventDescription
  eventNodup : (entries.map EventDescription.event).Nodup
deriving Repr

namespace EventDescriptionMemory

/--
Admit a collection of Event descriptions only if no EventId is repeated.
Duplicate descriptions for the same EventId are rejected (fail closed).
-/
def ofEntries? (entries : List EventDescription) : Option EventDescriptionMemory :=
  if h : (entries.map EventDescription.event).Nodup then
    some { entries := entries, eventNodup := h }
  else
    none

/-- Empty Event-description memory is always valid. -/
@[simp] theorem ofEntries?_nil :
    ofEntries? [] = some { entries := [], eventNodup := by simp } := by
  simp [ofEntries?]

/-- Single entry memory is always valid. -/
@[simp] theorem ofEntries?_singleton (entry : EventDescription) :
    ofEntries? [entry] = some { entries := [entry], eventNodup := by simp } := by
  simp [ofEntries?]

/-- Empty Event-description memory constructor. -/
def empty : EventDescriptionMemory :=
  { entries := [], eventNodup := by simp }

private def findTextByEvent? : List EventDescription → EventId → Option String
  | [], _ => none
  | desc :: rest, target =>
      if desc.event = target then
        some desc.text
      else
        findTextByEvent? rest target

/--
Lookup the description text associated with one EventId, if present.
-/
def findText? (memory : EventDescriptionMemory) (target : EventId) : Option String :=
  findTextByEvent? memory.entries target

end EventDescriptionMemory

end Loam.Core
