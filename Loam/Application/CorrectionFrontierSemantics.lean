import Loam.Core.EventCorrectionMemory
import Loam.Core.FiniteKeyed
import Loam.Application.ReplacementFrontier
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas
import Std.Data.HashSet
import Std.Data.HashSet.Lemmas

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Correction frontier

This application boundary derives one current Event frontier only for correction
facts that justify a collection of disjoint finite paths.

It deliberately does not make correction-memory list order authoritative and it
does not reinterpret branching or merging correction shapes as if they had a
winner. Multi-parent settlement remains outside the current production Core.
-/

def targetsEvent : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.target = id then
        true
      else
        targetsEvent rest id

def replacesEvent : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then
        true
      else
        replacesEvent rest id

def replacementOf? : List EventCorrection → EventId → Option EventId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction.replacement
      else
        replacementOf? rest id

def terminalFrom
    (corrections : List EventCorrection) : Nat → EventId → EventId
  | 0, id => id
  | fuel + 1, id =>
      match replacementOf? corrections id with
      | none => id
      | some replacement => terminalFrom corrections fuel replacement

def correctionEdges
    (corrections : EventCorrectionMemory) :
    List (ReplacementFrontier.Edge EventId) :=
  corrections.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

def eventPresent
    (events : EventMemory)
    (id : EventId) : Bool :=
  (EventMemory.findById? events id).isSome

/--
Whether every retained correction endpoint is represented by an Event.

This is a diagnostic facet of frontier admission, not a second authority rule.
It lets application and presentation layers distinguish missing references from
other unsupported correction topology while using the same frontier engine for
all effective quantity calculation.
-/
def correctionReferencesClosed
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Bool :=
  ReplacementFrontier.referencesClosed
    (eventPresent events) (correctionEdges corrections)

/--
Whether the retained correction facts justify one order-free frontier using
Correction alone.

The admitted shape is intentionally narrower than an arbitrary directed graph:

- every referenced Event is present;
- one target has at most one replacement, so sibling corrections remain unresolved;
- one replacement has at most one target, so Correction cannot silently perform
  a multi-parent merge that current production semantics do not admit;
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

/-- A singleton self-correction is one cycle and therefore never a current frontier. -/
@[simp] theorem correctionFrontierAdmissible_singleton_self
    (events : EventMemory)
    (id : EventId) :
    correctionFrontierAdmissible
      events
      { corrections := [{ target := id, replacement := id }]
        idNodup := by simp } = false := by
  simp [correctionFrontierAdmissible, correctionEdges]

def frontierEvents
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : List Event :=
  events.events.filter fun event =>
    !(targetsEvent corrections.corrections event.id)

theorem targetsEvent_false_iff
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

theorem targetsEvent_eq_true_iff
    (corrections : List EventCorrection)
    (id : EventId) :
    targetsEvent corrections id = true ↔
      ∃ correction ∈ corrections, correction.target = id := by
  induction corrections with
  | nil =>
      simp [targetsEvent]
  | cons correction rest ih =>
      simp only [targetsEvent]
      split
      · rename_i hTarget
        simp [hTarget]
      · rename_i hTargetNe
        simp [hTargetNe, ih]

/--
Filtering an already-admitted EventMemory cannot introduce a repeated EventId.

The runtime collection therefore inherits its identity invariant directly from
the retained EventMemory instead of rechecking the filtered list with a second
hash-backed admission pass.
-/
theorem frontierEvents_idNodup
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    ((frontierEvents events corrections).map Event.id).Nodup := by
  unfold frontierEvents
  exact events.idNodup.sublist (List.filter_sublist.map Event.id)

/-- Reference specification for correction frontier memory admission. -/
def correctionFrontierMemoryLegacy?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option EventMemory :=
  if corrections.corrections.isEmpty then
    some events
  else if correctionFrontierAdmissible events corrections then
    some {
      events := frontierEvents events corrections
      idNodup := frontierEvents_idNodup events corrections
    }
  else
    none

/-- Reference specification for root terminal Event derivation. -/
def correctionRootTerminalEventsLegacy?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option (List (EventId × Event)) := do
  if !correctionFrontierAdmissible events corrections then
    none
  let roots := events.events.filter fun event =>
    !(replacesEvent corrections.corrections event.id)
  roots.mapM fun root => do
    let terminalId :=
      terminalFrom corrections.corrections (corrections.corrections.length + 1) root.id
    let terminal ← EventMemory.findById? events terminalId
    pure (root.id, terminal)


end Loam.Application
