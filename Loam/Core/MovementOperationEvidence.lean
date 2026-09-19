import Loam.Core.EventMemory
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/-!
# Movement operation evidence

This family retains one narrow fact:

    one stable Movement write-operation identity produced one retained Event

It exists for idempotent retry at machine/AI/proposal boundaries. It does not
identify payment rails, merchants, external source rows, settlement state, or
Event payload equality.

The relation is intentionally orthogonal to Event. Manual/TUI-created Events may
therefore exist without any Movement operation evidence.
-/

/-- Stable identity for one logical Movement publication request. -/
structure MovementOperationId where
  token : String
deriving Repr, DecidableEq

/-- One retained mapping from a logical Movement operation to its produced Event. -/
structure MovementOperationEvidence where
  operation : MovementOperationId
  event : EventId
deriving Repr, DecidableEq

/--
Retained Movement operation mappings.

Each operation occurs at most once, and one Event is owned by at most one
Movement operation identity. Representation order has no semantic meaning.
-/
structure MovementOperationEvidenceMemory where
  entries : List MovementOperationEvidence
  operationNodup : (entries.map MovementOperationEvidence.operation).Nodup
  eventNodup : (entries.map MovementOperationEvidence.event).Nodup
deriving Repr

namespace MovementOperationEvidenceMemory

/-- Admit raw mappings only when both sides remain unique. -/
def ofEntries?
    (entries : List MovementOperationEvidence) :
    Option MovementOperationEvidenceMemory :=
  if hOperation : (entries.map MovementOperationEvidence.operation).Nodup then
    if hEvent : (entries.map MovementOperationEvidence.event).Nodup then
      some {
        entries := entries
        operationNodup := hOperation
        eventNodup := hEvent
      }
    else
      none
  else
    none

/-- Empty operation evidence is valid. -/
def empty : MovementOperationEvidenceMemory := {
  entries := []
  operationNodup := by simp
  eventNodup := by simp
}

/-- Append one mapping while preserving the one-to-one retained relation. -/
def add?
    (memory : MovementOperationEvidenceMemory)
    (entry : MovementOperationEvidence) :
    Option MovementOperationEvidenceMemory :=
  ofEntries? (memory.entries ++ [entry])

/-- Find the Event produced by one logical Movement operation. -/
def findEvent?
    (memory : MovementOperationEvidenceMemory)
    (operation : MovementOperationId) : Option EventId :=
  (FiniteKeyed.findBy?
      MovementOperationEvidence.operation memory.entries operation).map
    MovementOperationEvidence.event

/-- Find the logical Movement operation associated with one Event, if any. -/
def findOperation?
    (memory : MovementOperationEvidenceMemory)
    (event : EventId) : Option MovementOperationId :=
  (FiniteKeyed.findBy?
      MovementOperationEvidence.event memory.entries event).map
    MovementOperationEvidence.operation

/-- Every retained mapping must point at a retained Event. -/
def referencesOnlyKnownEvents
    (events : EventMemory)
    (memory : MovementOperationEvidenceMemory) : Bool :=
  memory.entries.all fun entry =>
    (EventMemory.findById? events entry.event).isSome

/--
Admit a complete candidate relation against current Event identity authority.
Missing operation rows remain valid and mean the Event has no retained
idempotency key.
-/
def ofEntriesAgainst?
    (events : EventMemory)
    (entries : List MovementOperationEvidence) :
    Option MovementOperationEvidenceMemory := do
  let memory ← ofEntries? entries
  if referencesOnlyKnownEvents events memory then
    some memory
  else
    none

@[simp] theorem findEvent?_empty (operation : MovementOperationId) :
    findEvent? empty operation = none := by
  simp [findEvent?, empty, FiniteKeyed.findBy?]

@[simp] theorem findOperation?_empty (event : EventId) :
    findOperation? empty event = none := by
  simp [findOperation?, empty, FiniteKeyed.findBy?]

end MovementOperationEvidenceMemory

end Loam.Core
