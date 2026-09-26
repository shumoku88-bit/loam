import Loam.Application.CorrectionFrontier
import Loam.Core.OriginalAmountEvidence

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Original amount current projection

OriginalAmountEvidence is retained against stable correction roots. This module
reuses the existing correction frontier to project those rows onto current
terminal Events without rewriting retained evidence.
-/

/-- One current read-side original amount attached to a terminal Event. -/
structure CurrentOriginalAmount where
  event : EventId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
Admit retained original-amount rows only when every subject is a stable
correction root in the supplied Event/correction world.
-/
def admittedOriginalAmounts?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (memory : OriginalAmountEvidenceMemory) :
    Option OriginalAmountEvidenceMemory := do
  let readmitted ← OriginalAmountEvidenceMemory.ofEntries? memory.entries
  let roots ← correctionRootIds? events corrections
  if readmitted.entries.all (fun entry => roots.contains entry.event) then
    some readmitted
  else
    none

/--
Project stable-root OriginalAmountEvidence onto current terminal Events.

The retained EventId remains unchanged in storage. This is a read projection
only.
-/
def currentOriginalAmounts?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (memory : OriginalAmountEvidenceMemory) :
    Option (List CurrentOriginalAmount) := do
  let _ ← admittedOriginalAmounts? events corrections memory
  let rooted ← correctionRootTerminalEvents? events corrections
  memory.entries.mapM fun entry => do
    let pair ← rooted.find? fun candidate =>
      decide (candidate.1 = entry.event)
    pure {
      event := pair.2.id
      measure := entry.measure
      quantity := entry.quantity
    }

end Loam.Application
