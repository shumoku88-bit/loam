import Loam.Core.EventCorrectionMemory
import Loam.Application.ReplacementFrontier
import Loam.Core.HashNodup
import Std.Data.HashSet

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

private def replacesEvent : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then
        true
      else
        replacesEvent rest id

private def replacementOf? : List EventCorrection → EventId → Option EventId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction.replacement
      else
        replacementOf? rest id

private def terminalFrom
    (corrections : List EventCorrection) : Nat → EventId → EventId
  | 0, id => id
  | fuel + 1, id =>
      match replacementOf? corrections id with
      | none => id
      | some replacement => terminalFrom corrections fuel replacement

private def correctionEdges
    (corrections : EventCorrectionMemory) :
    List (ReplacementFrontier.Edge EventId) :=
  corrections.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

private def eventIdentityIndex
    (events : EventMemory) : Std.HashSet String :=
  events.events.foldl
    (fun index event => index.insert event.id.token)
    {}

private def eventPresentIn
    (index : Std.HashSet String)
    (id : EventId) : Bool :=
  index.contains id.token

private theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

private def correctionFrontierAdmissibleWithIndex
    (index : Std.HashSet String)
    (corrections : EventCorrectionMemory) : Bool :=
  let edges := correctionEdges corrections
  let sources := edges.map ReplacementFrontier.Edge.source
  let successors := edges.map ReplacementFrontier.Edge.successor
  match
      hashNodupBy?
        (fun id : EventId => id.token)
        eventIdToken_injective
        sources,
      hashNodupBy?
        (fun id : EventId => id.token)
        eventIdToken_injective
        successors with
  | some sourceWitness, some successorWitness =>
      ReplacementFrontier.structurallyAdmissibleOfEndpointUnique
        (eventPresentIn index)
        edges
        sourceWitness.proof
        successorWitness.proof
  | _, _ => false

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
  let index := eventIdentityIndex events
  ReplacementFrontier.referencesClosed
    (eventPresentIn index) (correctionEdges corrections)

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
  let index := eventIdentityIndex events
  ReplacementFrontier.structurallyAdmissible
    (eventPresentIn index) (correctionEdges corrections)

/-- A singleton self-correction is one cycle and therefore never a current frontier. -/
@[simp] theorem correctionFrontierAdmissible_singleton_self
    (events : EventMemory)
    (id : EventId) :
    correctionFrontierAdmissible
      events
      { corrections := [{ target := id, replacement := id }]
        idNodup := by simp } = false := by
  simp [correctionFrontierAdmissible, correctionEdges]

private def targetIdentityIndex :
    List EventCorrection → Std.HashSet String
  | [] => {}
  | correction :: rest =>
      (targetIdentityIndex rest).insert correction.target.token

private theorem targetIdentityIndex_mem_iff
    (corrections : List EventCorrection)
    (token : String) :
    token ∈ targetIdentityIndex corrections ↔
      ∃ correction ∈ corrections, correction.target.token = token := by
  induction corrections with
  | nil =>
      simp [targetIdentityIndex]
  | cons correction rest ih =>
      rw [targetIdentityIndex, Std.HashSet.mem_insert, ih]
      constructor
      · intro h
        cases h with
        | inl hEq =>
            exact ⟨correction, by simp, hEq.symm⟩
        | inr hRest =>
            rcases hRest with ⟨found, hFound, hToken⟩
            exact ⟨found, by simp [hFound], hToken⟩
      · rintro ⟨found, hFound, hToken⟩
        simp only [List.mem_cons] at hFound
        cases hFound with
        | inl hEq =>
            subst found
            exact Or.inl hToken.symm
        | inr hRest =>
            exact Or.inr ⟨found, hRest, hToken⟩

private theorem targetIdentityIndex_not_mem_iff
    (corrections : List EventCorrection)
    (id : EventId) :
    id.token ∉ targetIdentityIndex corrections ↔
      ∀ correction ∈ corrections, correction.target ≠ id := by
  constructor
  · intro hNot correction hCorrection hEq
    apply hNot
    exact (targetIdentityIndex_mem_iff corrections id.token).2
      ⟨correction, hCorrection, congrArg (fun eventId : EventId => eventId.token) hEq⟩
  · intro hNo hMem
    rcases (targetIdentityIndex_mem_iff corrections id.token).1 hMem with
      ⟨correction, hCorrection, hToken⟩
    exact hNo correction hCorrection (eventIdToken_injective hToken)

private def frontierEvents
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : List Event :=
  let targets := targetIdentityIndex corrections.corrections
  events.events.filter fun event =>
    !(targets.contains event.id.token)

/--
Filtering an already-admitted EventMemory cannot introduce a repeated EventId.

The runtime collection therefore inherits its identity invariant directly from
the retained EventMemory instead of rechecking the filtered list with a second
hash-backed admission pass.
-/
private theorem frontierEvents_idNodup
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    ((frontierEvents events corrections).map Event.id).Nodup := by
  unfold frontierEvents
  exact events.idNodup.sublist (List.filter_sublist.map Event.id)

/--
Derive the retained Event frontier when correction facts justify disjoint finite
paths. Superseded targets are filtered out; terminal replacements and untouched
Events remain.

Filtering preserves the already-proved EventId uniqueness invariant, so the
frontier is constructed from that proof directly. No second runtime hash-backed
duplicate admission is required after the correction topology has been admitted.
-/
def correctionFrontierMemory?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option EventMemory :=
  if corrections.corrections.isEmpty then
    some events
  else
    let index := eventIdentityIndex events
    if correctionFrontierAdmissibleWithIndex index corrections then
      some {
        events := frontierEvents events corrections
        idNodup := frontierEvents_idNodup events corrections
      }
    else
      none

/--
Return the stable correction root together with its current terminal Event for
all admitted correction paths and untouched Events.

The root relation is derived only after the same correction-frontier admission
used by ordinary quantity inspection. Event representation order, occurrence
date, EventId spelling, and Git history remain irrelevant. Untouched Events are
their own roots.
-/
def correctionRootTerminalEvents?
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

/--
Derive the explicit stable roots represented by the admitted current Event world.
This is the smallest root vocabulary needed by current-anchor evidence; it does
not assign chronology or introduce another Event identity family.
-/
def correctionRootIds?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option (List EventId) := do
  let rooted ← correctionRootTerminalEvents? events corrections
  pure (rooted.map Prod.fst)

/--
Derive the current correction frontier after excluding complete correction roots
that an external current-quantity observation already reflects.

Filtering occurs by stable root, so later correction or reclassification of a
covered occurrence remains covered. Quantity arithmetic is intentionally not
performed here; callers continue to use `EventMemory.quantityAtRecorded` on the
returned admitted frontier.
-/
def correctionFrontierExcludingRoots?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (reflectedRoots : List EventId) : Option EventMemory := do
  let rooted ← correctionRootTerminalEvents? events corrections
  let unreflected := rooted.filterMap fun rootedEvent =>
    if reflectedRoots.contains rootedEvent.1 then none else some rootedEvent.2
  EventMemory.ofEvents? unreflected

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
  · rename_i hEmpty
    simp only [Option.some.injEq] at hFrontier
    subst frontier
    have hNoCorrections : corrections.corrections = [] := by
      cases hList : corrections.corrections with
      | nil => rfl
      | cons head tail => simp [hList] at hEmpty
    simp [hNoCorrections]
  · dsimp only at hFrontier
    split at hFrontier
    · simp only [Option.some.injEq] at hFrontier
      subst frontier
      simp [frontierEvents, targetIdentityIndex_not_mem_iff]
    · simp at hFrontier

/--
Project one locus/measure quantity from the admitted correction frontier.

Quantity arithmetic is delegated to the recorded EventMemory projection after
superseded Event identities have been removed. The same path is used for one or
many corrections; correction count carries no authority.
-/
def quantityAtCorrectionFrontier?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let frontier ← correctionFrontierMemory? events corrections
  return EventMemory.quantityAtRecorded frontier locus measure

end Loam.Application
