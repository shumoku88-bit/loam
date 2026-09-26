import Loam.Core.EventMemory

namespace Loam.Core

set_option autoImplicit false

/-!
# Exchange evidence

One retained claim that two explicitly keyed Effects in the same Event are the
selected source and destination sides of a cross-Measure exchange.

The evidence carries no FX rate, valuation, acquisition basis, tax basis, gain,
fee semantics, home currency, foreign currency, or travel direction.
-/

/-- One effect-selected exchange claim for an Event. -/
structure ExchangeEvidence where
  event : EventId
  source : EffectKey
  destination : EffectKey
deriving Repr, DecidableEq

/--
Retained exchange evidence.

The currently qualified production shape permits at most one selected exchange
pair per Event.
-/
structure ExchangeEvidenceMemory where
  entries : List ExchangeEvidence
  eventNodup : (entries.map ExchangeEvidence.event).Nodup
deriving Repr

namespace ExchangeEvidenceMemory

/-- Admit raw rows only when one Event does not receive two exchange claims. -/
def ofEntries?
    (entries : List ExchangeEvidence) : Option ExchangeEvidenceMemory :=
  if h : (entries.map ExchangeEvidence.event).Nodup then
    some { entries := entries, eventNodup := h }
  else
    none

/-- Empty exchange evidence is valid. -/
def empty : ExchangeEvidenceMemory :=
  { entries := [], eventNodup := by simp }

/-- Append one raw exchange claim while preserving Event uniqueness. -/
def add?
    (memory : ExchangeEvidenceMemory)
    (entry : ExchangeEvidence) : Option ExchangeEvidenceMemory :=
  ofEntries? (memory.entries ++ [entry])

/-- Find the retained exchange claim for one Event. -/
def findByEvent?
    (memory : ExchangeEvidenceMemory)
    (event : EventId) : Option ExchangeEvidence :=
  memory.entries.find? fun entry => decide (entry.event = event)

end ExchangeEvidenceMemory

end Loam.Core
