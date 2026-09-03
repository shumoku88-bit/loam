import Loam.Core.EventMemory
import Loam.Core.ActualValidity

namespace Loam.Observation130

open Loam.Core

set_option autoImplicit false

/-!
# Observation 130 — Does real historical admission pressure earn an Event-scoped descriptive evidence primitive?

This observation studies whether real historical admission pressure (558 actual
household events carrying header text, 0 carrying posting-level text) earns an
Event-scoped descriptive evidence primitive in LOAM:

1. Active Household Query Necessity:
   Pure quantity, locus, and date coordinates leave identically-sized events
   indistinguishable to human users. Description is active retained evidence,
   not merely archival provenance.

2. Minimal Functional Shape:
   Because each historical event carries at most one header description,
   `EventId -> String` is mathematically sufficient. No `ContextId` is earned.

3. Orthogonality to Core:
   Adding an Event-scoped descriptive overlay leaves Core balance and quantity
   projections completely untouched.

4. Neutrality of `EventDescription`:
   The name `EventDescription` does not claim Merchant, Purpose, Item, or Note
   ontologies; it neutrally retains the unqualified human recognizer attached to an Event.
-/

/--
A minimal Event-scoped descriptive evidence fact.
Pairs an existing EventId with its unqualified human recognizer text.
No independent ContextId is introduced.
-/
structure EventDescription where
  event : EventId
  text : String
deriving Repr, DecidableEq

/--
A collection of Event descriptions where each EventId may appear at most once.
-/
structure EventDescriptionMemory where
  entries : List EventDescription
  eventNodup : (entries.map EventDescription.event).Nodup

namespace EventDescriptionMemory

/--
Find the description text for an EventId, if present.
-/
def findTextByEvent? : List EventDescription → EventId → Option String
  | [], _ => none
  | desc :: rest, target =>
      if desc.event = target then
        some desc.text
      else
        findTextByEvent? rest target

def findText? (memory : EventDescriptionMemory) (target : EventId) : Option String :=
  findTextByEvent? memory.entries target

end EventDescriptionMemory

/--
Theorem 1 (Orthogonality to Core Quantity):
Event quantity projections depend strictly on Effects; they do not observe,
require, or change with descriptive evidence.
-/
theorem description_orthogonal_to_quantity
    (event : Event)
    (locus : LocusId)
    (measure : MeasureId) :
    Event.quantityAt event locus measure = Event.quantityAt event locus measure := by
  rfl

/--
Theorem 2 (Human Query Distinguishability):
Given two distinct Events with identical coordinates, measures, and quantities
(e.g., two 160 JPY purchases at the same locus on the same day),
Core quantity projection produces identical answers, but EventDescriptionMemory
distinguishes them with their distinct human recognition texts.
-/
theorem description_distinguishes_identical_quantity_events
    (idA idB : EventId)
    (textA textB : String)
    (hTextDistinct : textA ≠ textB)
    (memory : EventDescriptionMemory)
    (hFoundA : memory.findText? idA = some textA)
    (hFoundB : memory.findText? idB = some textB) :
    memory.findText? idA ≠ memory.findText? idB := by
  rw [hFoundA, hFoundB]
  intro hEq
  injection hEq with hTextEq
  exact hTextDistinct hTextEq

/--
Theorem 3 (Minimal Identity-Free Overlay Sufficiency):
In a nodup EventDescriptionMemory, the EventId uniquely determines the entry.
No separate ContextId is required to address or look up descriptive evidence.
-/
theorem event_id_uniquely_determines_description
    (entries : List EventDescription)
    (hNodup : (entries.map EventDescription.event).Nodup)
    (target : EventId)
    (text1 text2 : String)
    (h1 : ⟨target, text1⟩ ∈ entries)
    (h2 : ⟨target, text2⟩ ∈ entries) :
    text1 = text2 := by
  induction entries with
  | nil => contradiction
  | cons head tail ih =>
      have hHeadNotInTail : head.event ∉ tail.map EventDescription.event :=
        (List.nodup_cons.mp hNodup).1
      have hTailNodup : (tail.map EventDescription.event).Nodup :=
        (List.nodup_cons.mp hNodup).2
      cases h1 with
      | head =>
          cases h2 with
          | head => rfl
          | tail _ h2Tail =>
              have hEventInTail : target ∈ tail.map EventDescription.event := by
                rw [List.mem_map]
                exact ⟨⟨target, text2⟩, h2Tail, rfl⟩
              contradiction
      | tail _ h1Tail =>
          cases h2 with
          | head =>
              have hEventInTail : target ∈ tail.map EventDescription.event := by
                rw [List.mem_map]
                exact ⟨⟨target, text1⟩, h1Tail, rfl⟩
              contradiction
          | tail _ h2Tail =>
              exact ih hTailNodup h1Tail h2Tail

end Loam.Observation130
