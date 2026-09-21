import Loam.Core.EventCorrectionMemory
import Loam.Application.ReplacementFrontier
import Std.Data.HashMap
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

/-!
# Phase 3H: Transient Correction Frontier Index

Transient acceleration index for Correction frontier admission and projection.
Constructed once per admission / review pass from canonical `EventMemory` and
`EventCorrectionMemory`. It is never serialized or treated as an independent authority.
-/

/-- EventId token projection is injective, enabling hash-indexed replacement cycle checks. -/
theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

/--
Transient scan state accumulated during the single pass over
`EventCorrectionMemory.corrections`.
-/
private structure CorrectionScanState where
  targetSet : Std.HashSet String
  replacementSet : Std.HashSet String
  replacementByTarget : Std.HashMap String EventId
  edgesRev : List (ReplacementFrontier.Edge EventId)
  hasUnknownEndpoint : Bool
  hasDuplicateTarget : Bool
  hasDuplicateReplacement : Bool

/--
Traverse raw corrections in one pass, collecting derived lookup structures and
evaluating endpoint presence and uniqueness without repeated scanning.
-/
private def scanCorrections
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) : CorrectionScanState :=
  corrections.foldl
    (fun state c =>
      let targetToken := c.target.token
      let replacementToken := c.replacement.token
      let targetKnown := eventMap.contains targetToken
      let replacementKnown := eventMap.contains replacementToken
      let isDupTarget := state.targetSet.contains targetToken
      let isDupReplacement := state.replacementSet.contains replacementToken
      let targetByRepl :=
        if isDupTarget then state.replacementByTarget
        else state.replacementByTarget.insert targetToken c.replacement
      let edge : ReplacementFrontier.Edge EventId :=
        { source := c.target, successor := c.replacement }
      {
        targetSet := state.targetSet.insert targetToken
        replacementSet := state.replacementSet.insert replacementToken
        replacementByTarget := targetByRepl
        edgesRev := edge :: state.edgesRev
        hasUnknownEndpoint := state.hasUnknownEndpoint || !targetKnown || !replacementKnown
        hasDuplicateTarget := state.hasDuplicateTarget || isDupTarget
        hasDuplicateReplacement := state.hasDuplicateReplacement || isDupReplacement
      })
    {
      targetSet := {}
      replacementSet := {}
      replacementByTarget := {}
      edgesRev := []
      hasUnknownEndpoint := false
      hasDuplicateTarget := false
      hasDuplicateReplacement := false
    }

/--
Transient lookup and acceleration index constructed for one `(EventMemory, EventCorrectionMemory)` pair.

The canonical `EventMemory` and `EventCorrectionMemory` remain the sole proof-carrying authorities.
This structure is constructed transiently and carries no authority or arrival-order semantics.
-/
structure CorrectionFrontierIndex where
  events : Std.HashMap String Event
  targetSet : Std.HashSet String
  replacementSet : Std.HashSet String
  replacementByTarget : Std.HashMap String EventId
  edges : List (ReplacementFrontier.Edge EventId)
  hasUnknownEndpoint : Bool
  hasDuplicateTarget : Bool
  hasDuplicateReplacement : Bool

/--
Construct the transient `CorrectionFrontierIndex` from canonical memories in linear time.
-/
def buildCorrectionFrontierIndex
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : CorrectionFrontierIndex :=
  let eventMap : Std.HashMap String Event :=
    events.events.foldl
      (fun map event => map.insert event.id.token event)
      {}
  let scan := scanCorrections eventMap corrections.corrections
  {
    events := eventMap
    targetSet := scan.targetSet
    replacementSet := scan.replacementSet
    replacementByTarget := scan.replacementByTarget
    edges := scan.edgesRev.reverse
    hasUnknownEndpoint := scan.hasUnknownEndpoint
    hasDuplicateTarget := scan.hasDuplicateTarget
    hasDuplicateReplacement := scan.hasDuplicateReplacement
  }

namespace CorrectionFrontierIndex

/-- Find one Event by its identity using the transient hash index. -/
def findEventById? (index : CorrectionFrontierIndex) (id : EventId) : Option Event :=
  index.events[id.token]?

/-- Whether one Event is present in the indexed memory snapshot. -/
def eventPresent (index : CorrectionFrontierIndex) (id : EventId) : Bool :=
  index.events.contains id.token

/-- Whether any retained correction targets this Event identity. -/
def targetsEvent (index : CorrectionFrontierIndex) (id : EventId) : Bool :=
  index.targetSet.contains id.token

/-- Whether any retained correction replaces this Event identity. -/
def replacesEvent (index : CorrectionFrontierIndex) (id : EventId) : Bool :=
  index.replacementSet.contains id.token

/-- Return the immediate replacement Event identity if this Event is targeted. -/
def replacementOf? (index : CorrectionFrontierIndex) (id : EventId) : Option EventId :=
  index.replacementByTarget[id.token]?

/-- Follow replacements to the terminal Event identity using transient lookup. -/
def terminalFrom
    (index : CorrectionFrontierIndex) : Nat → EventId → EventId
  | 0, id => id
  | fuel + 1, id =>
      match index.replacementOf? id with
      | none => id
      | some replacement => index.terminalFrom fuel replacement

/-- Whether both sources and successors are pairwise distinct (no branching, no merging). -/
def endpointUnique (index : CorrectionFrontierIndex) : Bool :=
  !index.hasDuplicateTarget && !index.hasDuplicateReplacement

/-- Whether every referenced correction endpoint is present in the Event snapshot. -/
def referencesClosed (index : CorrectionFrontierIndex) : Bool :=
  !index.hasUnknownEndpoint

/--
Universal cycle check using Phase 3F indexed cycle admission on `index.edges`.
-/
def acyclic (index : CorrectionFrontierIndex) : Bool :=
  ReplacementFrontier.acyclicIndexedBy
    (fun (id : EventId) => id.token)
    eventIdToken_injective
    index.edges

/--
Whether retained correction facts justify one order-free frontier, evaluated using
transient indexed checks.
-/
def admissible (index : CorrectionFrontierIndex) : Bool :=
  index.endpointUnique && index.referencesClosed && index.acyclic

/--
Filter retained Events to retain only terminal replacements and untouched Events.
-/
def frontierEvents (index : CorrectionFrontierIndex) (events : EventMemory) : List Event :=
  events.events.filter fun event => !(index.targetsEvent event.id)

/-- Preserved identity uniqueness proof for indexed frontier filtering. -/
theorem frontierEvents_idNodup
    (index : CorrectionFrontierIndex)
    (events : EventMemory) :
    ((index.frontierEvents events).map Event.id).Nodup := by
  unfold frontierEvents
  exact events.idNodup.sublist (List.filter_sublist.map Event.id)

end CorrectionFrontierIndex

/--
Derive the retained Event frontier using an already-constructed `CorrectionFrontierIndex`.
-/
def correctionFrontierMemoryIndexed?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (index : CorrectionFrontierIndex) : Option EventMemory :=
  if corrections.corrections.isEmpty then
    some events
  else if index.admissible then
    some {
      events := index.frontierEvents events
      idNodup := index.frontierEvents_idNodup events
    }
  else
    none

/--
Return stable correction roots with their terminal Events using transient indexed traversal.
-/
def correctionRootTerminalEventsIndexed?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (index : CorrectionFrontierIndex) : Option (List (EventId × Event)) := do
  if !index.admissible then
    none
  let roots := events.events.filter fun event =>
    !(index.replacesEvent event.id)
  roots.mapM fun root => do
    let terminalId :=
      index.terminalFrom (corrections.corrections.length + 1) root.id
    let terminal ← index.findEventById? terminalId
    pure (root.id, terminal)

/--
Derive the retained Event frontier when correction facts justify disjoint finite
paths. Superseded targets are filtered out; terminal replacements and untouched
Events remain.

Implemented using transient linear-time indexing via `CorrectionFrontierIndex`.
-/
def correctionFrontierMemory?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option EventMemory :=
  let index := buildCorrectionFrontierIndex events corrections
  correctionFrontierMemoryIndexed? events corrections index

/--
Return the stable correction root together with its current terminal Event for
all admitted correction paths and untouched Events.
-/
def correctionRootTerminalEvents?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option (List (EventId × Event)) := do
  let index := buildCorrectionFrontierIndex events corrections
  correctionRootTerminalEventsIndexed? events corrections index

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

private theorem scanCorrections_targetSet_eq
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) :
    (scanCorrections eventMap corrections).targetSet =
      corrections.foldl (fun s c => s.insert c.target.token) {} := by
  have hGeneral :
      ∀ (corrections : List EventCorrection) (state : CorrectionScanState),
        (corrections.foldl
          (fun s c =>
            let targetToken := c.target.token
            let replacementToken := c.replacement.token
            let targetKnown := eventMap.contains targetToken
            let replacementKnown := eventMap.contains replacementToken
            let isDupTarget := s.targetSet.contains targetToken
            let isDupReplacement := s.replacementSet.contains replacementToken
            let targetByRepl :=
              if isDupTarget then s.replacementByTarget
              else s.replacementByTarget.insert targetToken c.replacement
            let edge : ReplacementFrontier.Edge EventId :=
              { source := c.target, successor := c.replacement }
            {
              targetSet := s.targetSet.insert targetToken
              replacementSet := s.replacementSet.insert replacementToken
              replacementByTarget := targetByRepl
              edgesRev := edge :: s.edgesRev
              hasUnknownEndpoint := s.hasUnknownEndpoint || !targetKnown || !replacementKnown
              hasDuplicateTarget := s.hasDuplicateTarget || isDupTarget
              hasDuplicateReplacement := s.hasDuplicateReplacement || isDupReplacement
            }) state).targetSet =
          corrections.foldl (fun s c => s.insert c.target.token) state.targetSet := by
    intro corrections
    induction corrections with
    | nil =>
        intro state
        rfl
    | cons c rest ih =>
        intro state
        simp only [List.foldl_cons]
        rw [ih]
  unfold scanCorrections
  exact hGeneral corrections _

private theorem foldl_insert_contains
    (corrections : List EventCorrection)
    (set : Std.HashSet String)
    (id : EventId) :
    (corrections.foldl (fun s c => s.insert c.target.token) set).contains id.token = true ↔
      (set.contains id.token = true ∨ ∃ c ∈ corrections, c.target = id) := by
  induction corrections generalizing set with
  | nil =>
      simp
  | cons c rest ih =>
      simp only [List.foldl_cons]
      rw [ih]
      rw [Std.HashSet.contains_insert]
      simp only [Bool.or_eq_true, beq_iff_eq]
      constructor
      · intro h
        rcases h with (hEq | hSet) | ⟨c', hc'Rest, hc'Eq⟩
        · right
          have hTargetEq : c.target = id := eventIdToken_injective hEq
          exact ⟨c, List.mem_cons_self, hTargetEq⟩
        · left; exact hSet
        · right
          exact ⟨c', List.mem_cons_of_mem c hc'Rest, hc'Eq⟩
      · intro h
        rcases h with hSet | ⟨c', hc'Cons, hc'Eq⟩
        · left; right; exact hSet
        · cases hc'Cons with
          | head =>
              left; left
              subst hc'Eq
              rfl
          | tail _ hTail =>
              right
              exact ⟨c', hTail, hc'Eq⟩

theorem buildCorrectionFrontierIndex_targetsEvent_iff
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (id : EventId) :
    (buildCorrectionFrontierIndex events corrections).targetsEvent id = true ↔
      ∃ c ∈ corrections.corrections, c.target = id := by
  unfold buildCorrectionFrontierIndex CorrectionFrontierIndex.targetsEvent
  dsimp only
  rw [scanCorrections_targetSet_eq]
  rw [foldl_insert_contains]
  simp [Std.HashSet.contains_empty]

theorem buildCorrectionFrontierIndex_targetsEvent_eq_false_iff
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (id : EventId) :
    (buildCorrectionFrontierIndex events corrections).targetsEvent id = false ↔
      ∀ c ∈ corrections.corrections, c.target ≠ id := by
  constructor
  · intro h
    have hNotSome : ¬((buildCorrectionFrontierIndex events corrections).targetsEvent id = true) := by
      simp [h]
    rw [buildCorrectionFrontierIndex_targetsEvent_iff] at hNotSome
    intro c hc hcEq
    exact hNotSome ⟨c, hc, hcEq⟩
  · intro h
    cases hBool : (buildCorrectionFrontierIndex events corrections).targetsEvent id with
    | false => rfl
    | true =>
        rw [buildCorrectionFrontierIndex_targetsEvent_iff] at hBool
        obtain ⟨c, hc, hcEq⟩ := hBool
        exact False.elim (h c hc hcEq)

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
  unfold correctionFrontierMemory? correctionFrontierMemoryIndexed? at hFrontier
  dsimp only at hFrontier
  split at hFrontier
  · rename_i hEmpty
    simp only [Option.some.injEq] at hFrontier
    subst frontier
    have hNoCorrections : corrections.corrections = [] := by
      cases hList : corrections.corrections with
      | nil => rfl
      | cons head tail => simp [hList] at hEmpty
    simp [hNoCorrections]
  · split at hFrontier
    · simp only [Option.some.injEq] at hFrontier
      subst frontier
      simp only [CorrectionFrontierIndex.frontierEvents, List.mem_filter]
      have hTargetBool :
          (!(buildCorrectionFrontierIndex events corrections).targetsEvent event.id) = true ↔
            (buildCorrectionFrontierIndex events corrections).targetsEvent event.id = false := by
        cases (buildCorrectionFrontierIndex events corrections).targetsEvent event.id <;> decide
      rw [hTargetBool]
      rw [buildCorrectionFrontierIndex_targetsEvent_eq_false_iff]
    · simp at hFrontier

/--
Universal general correspondence theorem: `correctionFrontierMemoryIndexed?` evaluated
with `buildCorrectionFrontierIndex` corresponds identically to `correctionFrontierMemory?`.
-/
theorem correctionFrontierMemoryIndexed?_eq_correctionFrontierMemory?
    (events : EventMemory) (corrections : EventCorrectionMemory) :
    correctionFrontierMemoryIndexed? events corrections (buildCorrectionFrontierIndex events corrections) =
      correctionFrontierMemory? events corrections := rfl

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
