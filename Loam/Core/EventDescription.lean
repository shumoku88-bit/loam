import Loam.Core.Event
import Loam.Core.FiniteKeyed
import Loam.Core.HashNodup

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

private theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

/--
Admit a collection of Event descriptions only if no EventId is repeated.
Duplicate descriptions for the same EventId are rejected (fail closed).

The HashSet is a transient duplicate-detection accelerator only. The retained
Core authority is still the same `List.Nodup` proof over Event identities.
-/
def ofEntries? (entries : List EventDescription) : Option EventDescriptionMemory := do
  let h ← hashNodupBy?
    (fun id : EventId => id.token)
    eventIdToken_injective
    (entries.map EventDescription.event)
  some { entries := entries, eventNodup := h.proof }

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

/--
Append one Event-scoped description while preserving the one-description-per-Event
invariant. Representation order remains persistence shape only.
-/
def add?
    (memory : EventDescriptionMemory)
    (entry : EventDescription) : Option EventDescriptionMemory :=
  ofEntries? (memory.entries ++ [entry])

/-- Append description evidence whose Event identity is already proved fresh. -/
def addFresh
    (memory : EventDescriptionMemory)
    (entry : EventDescription)
    (hFresh : entry.event ∉ memory.entries.map EventDescription.event) :
    EventDescriptionMemory :=
  { entries := memory.entries ++ [entry]
    eventNodup :=
      FiniteKeyed.appendFresh_nodup
        EventDescription.event memory.entries entry memory.eventNodup hFresh }

/-- Lookup the description text associated with one EventId, if present. -/
def findText? (memory : EventDescriptionMemory) (target : EventId) : Option String :=
  (FiniteKeyed.findBy? EventDescription.event memory.entries target).map EventDescription.text

end EventDescriptionMemory

end Loam.Core
