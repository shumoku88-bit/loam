import Loam.Core.RelationAdmission
import Loam.Application.ReplacementFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Correction frontier

This application boundary derives one current Event frontier only for correction
facts that justify a collection of disjoint finite paths.

It deliberately does not make correction-memory list order authoritative and it
does not reinterpret branching or merging correction shapes as if they had a
winner. Multi-parent settlement remains the separate `EventResolution` concept.
-/

private def targetsEvent : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.target = id then
        true
      else
        targetsEvent rest id

private def correctionEdges
    (corrections : EventCorrectionMemory) :
    List (ReplacementFrontier.Edge EventId) :=
  corrections.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

private def eventPresent
    (events : EventMemory)
    (id : EventId) : Bool :=
  (EventMemory.findById? events id).isSome

/--
Whether the retained correction facts justify one order-free frontier using
Correction alone.

The admitted shape is intentionally narrower than an arbitrary directed graph:

- every referenced Event is present;
- one target has at most one replacement, so sibling corrections remain unresolved;
- one replacement has at most one target, so Correction cannot silently perform
  a multi-parent merge that belongs to `EventResolution`;
- following replacements cannot cycle.

Together these conditions make the correction relation a collection of disjoint
finite paths. They say nothing about accounting role, chronology, or authority
beyond the explicit correction relation itself.
-/
def correctionFrontierAdmissible
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Bool :=
  ReplacementFrontier.structurallyAdmissible
    (eventPresent events) (correctionEdges corrections)

private def frontierEvents
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : List Event :=
  events.events.filter fun event =>
    !(targetsEvent corrections.corrections event.id)

private theorem targetsEvent_false_iff
    (corrections : List EventCorrection)
    (id : EventId) :
    targetsEvent corrections id = false ↔
      ∀ correction ∈ corrections, correction.target ≠ id := by
  induction corrections with
  | nil =>
      simp [targetsEvent]
  | cons correction rest ih =>
      by_cases hTarget : correction.target = id
      · simp [targetsEvent, hTarget]
      · simp [targetsEvent, hTarget, ih]

/--
Derive the retained Event frontier when correction facts justify disjoint finite
paths. Superseded targets are filtered out; terminal replacements and untouched
Events remain.

The result is re-admitted through `EventMemory.ofEvents?` rather than constructing
an unchecked collection. Filtering a valid EventMemory cannot invent duplicate
identity, but the runtime re-admission keeps this boundary fail-closed without
adding a second quantity implementation or a proof-only constructor path.
-/
def correctionFrontierMemory?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option EventMemory :=
  if correctionFrontierAdmissible events corrections then
    EventMemory.ofEvents? (frontierEvents events corrections)
  else
    none

/--
A successful correction frontier retains exactly the remembered Events that are
not targeted by any retained correction fact.

This theorem makes explicit a property already present in the implementation:
once the correction relation passes the fail-closed admission boundary, frontier
membership depends on target membership rather than path length or list order.
It adds no new runtime semantics.
-/
theorem correctionFrontierMemory?_mem_iff
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (frontier : EventMemory)
    (hFrontier : correctionFrontierMemory? events corrections = some frontier)
    (event : Event) :
    event ∈ frontier.events ↔
      event ∈ events.events ∧
        ∀ correction ∈ corrections.corrections,
          correction.target ≠ event.id := by
  unfold correctionFrontierMemory? at hFrontier
  split at hFrontier
  · unfold EventMemory.ofEvents? at hFrontier
    split at hFrontier
    · simp only [Option.some.injEq] at hFrontier
      subst frontier
      simp [frontierEvents, targetsEvent_false_iff]
    · simp at hFrontier
  · simp at hFrontier

/--
Project one locus/measure quantity from the admitted correction frontier.

Quantity arithmetic is delegated to the existing recorded EventMemory
projection after superseded Event identities have been removed. This keeps the
new application semantics focused on frontier selection rather than duplicating
Core quantity folding.
-/
def quantityAtCorrectionFrontier?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  return EventMemory.quantityAtRecorded frontier locus measure

end Loam.Application
