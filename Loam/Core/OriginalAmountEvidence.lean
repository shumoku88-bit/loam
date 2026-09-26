import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/-!
# Original amount evidence

One optional Event-scoped observation of the positive amount presented or
charged in another explicit Measure.

This evidence does not participate in Event balance, valuation, FX-rate
authority, acquisition basis, tax basis, or gain/loss semantics.

Production publication is expected to retain the EventId as a stable correction
root. Current-Event projection belongs to the Application layer.
-/

/-- One retained original presented/charged amount for an Event root. -/
structure OriginalAmountEvidence where
  event : EventId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
A complete retained collection of original-amount evidence.

Each Event root may have at most one row. Quantity positivity is part of this
memory admission because zero/negative presented amounts are outside the
selected evidence meaning.
-/
structure OriginalAmountEvidenceMemory where
  entries : List OriginalAmountEvidence
  eventNodup : (entries.map OriginalAmountEvidence.event).Nodup
deriving Repr

namespace OriginalAmountEvidenceMemory

/-- Admit raw rows only when Event identity is unique and every quantity is positive. -/
def ofEntries?
    (entries : List OriginalAmountEvidence) : Option OriginalAmountEvidenceMemory :=
  if hNodup : (entries.map OriginalAmountEvidence.event).Nodup then
    if entries.all (fun entry => entry.quantity.quanta > 0) then
      some { entries := entries, eventNodup := hNodup }
    else
      none
  else
    none

/-- Empty original-amount evidence is valid. -/
def empty : OriginalAmountEvidenceMemory :=
  { entries := [], eventNodup := by simp }

/-- Append one row while preserving uniqueness and positivity. -/
def add?
    (memory : OriginalAmountEvidenceMemory)
    (entry : OriginalAmountEvidence) : Option OriginalAmountEvidenceMemory :=
  ofEntries? (memory.entries ++ [entry])

/-- Find the retained original amount for one stable Event root. -/
def findByEvent?
    (memory : OriginalAmountEvidenceMemory)
    (event : EventId) : Option OriginalAmountEvidence :=
  memory.entries.find? fun entry => decide (entry.event = event)

/-- Whether every row refers to a retained Event identity. -/
def referencesOnlyKnownEvents
    (events : EventMemory)
    (memory : OriginalAmountEvidenceMemory) : Bool :=
  memory.entries.all fun entry =>
    (events.findById? entry.event).isSome

end OriginalAmountEvidenceMemory

end Loam.Core
