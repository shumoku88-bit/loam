import Loam.Core.RelationAdmission

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

private def replacesWith : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then
        true
      else
        replacesWith rest id

private def uniqueTargets : List EventCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(targetsEvent rest correction.target) && uniqueTargets rest

private def uniqueReplacements : List EventCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(replacesWith rest correction.replacement) && uniqueReplacements rest

private def closedReferences
    (events : EventMemory) : List EventCorrection → Bool
  | [] => true
  | correction :: rest =>
      EventCorrection.referencesPresent events correction &&
        closedReferences events rest

private def findByTarget? : List EventCorrection → EventId → Option EventCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction
      else
        findByTarget? rest id

private def pathAcyclic
    (corrections : List EventCorrection)
    (current : EventId)
    (seen : List EventId) : Nat → Bool
  | 0 => false
  | fuel + 1 =>
      if current ∈ seen then
        false
      else
        match findByTarget? corrections current with
        | none => true
        | some correction =>
            pathAcyclic corrections correction.replacement (current :: seen) fuel

private def allPathsAcyclic
    (corrections : List EventCorrection) : List EventCorrection → Bool
  | [] => true
  | correction :: rest =>
      pathAcyclic corrections correction.target [] (corrections.length + 1) &&
        allPathsAcyclic corrections rest

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
  let items := corrections.corrections
  uniqueTargets items &&
    uniqueReplacements items &&
    closedReferences events items &&
    allPathsAcyclic items items

private def frontierEvents
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : List Event :=
  events.events.filter fun event =>
    !(targetsEvent corrections.corrections event.id)

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
