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

theorem buildCorrectionFrontierIndex_targetsEvent_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (id : EventId) :
    (buildCorrectionFrontierIndex events corrections).targetsEvent id =
      targetsEvent corrections.corrections id := by
  cases hT : (buildCorrectionFrontierIndex events corrections).targetsEvent id with
  | true =>
      rw [buildCorrectionFrontierIndex_targetsEvent_iff] at hT
      have hLegacy : targetsEvent corrections.corrections id = true := by
        rw [targetsEvent_eq_true_iff]
        exact hT
      rw [hLegacy]
  | false =>
      rw [buildCorrectionFrontierIndex_targetsEvent_eq_false_iff] at hT
      have hLegacy : targetsEvent corrections.corrections id = false := by
        rw [targetsEvent_false_iff]
        exact hT
      rw [hLegacy]

/--
Indexed frontier filtering retains the exact same Events as legacy specification filtering.
-/
theorem buildCorrectionFrontierIndex_frontierEvents_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).frontierEvents events =
      frontierEvents events corrections := by
  unfold CorrectionFrontierIndex.frontierEvents frontierEvents
  have hPred :
      (fun (event : Event) => !(buildCorrectionFrontierIndex events corrections).targetsEvent event.id) =
      (fun (event : Event) => !targetsEvent corrections.corrections event.id) := by
    funext event
    rw [buildCorrectionFrontierIndex_targetsEvent_eq]
  rw [hPred]

private theorem scanCorrections_edgesRev_eq
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) :
    (scanCorrections eventMap corrections).edgesRev =
      (corrections.map fun c =>
        ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).reverse := by
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
            }) state).edgesRev =
          (corrections.map fun c =>
            ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).reverse ++ state.edgesRev := by
    intro corrections
    induction corrections with
    | nil =>
        intro state
        rfl
    | cons c rest ih =>
        intro state
        simp only [List.foldl_cons]
        rw [ih]
        simp
  unfold scanCorrections
  have h0 := hGeneral corrections {
    targetSet := {}
    replacementSet := {}
    replacementByTarget := {}
    edgesRev := []
    hasUnknownEndpoint := false
    hasDuplicateTarget := false
    hasDuplicateReplacement := false
  }
  rw [h0]
  simp

/--
Indexed edge reconstruction exactly recovers the canonical `correctionEdges`.
-/
theorem buildCorrectionFrontierIndex_edges_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).edges =
      correctionEdges corrections := by
  unfold buildCorrectionFrontierIndex correctionEdges
  dsimp only
  rw [scanCorrections_edgesRev_eq]
  rw [List.reverse_reverse]

/--
Transient cycle check on indexed edges is equivalent to legacy `acyclic` on `correctionEdges`.
-/
theorem buildCorrectionFrontierIndex_acyclic_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).acyclic =
      ReplacementFrontier.acyclic (correctionEdges corrections) := by
  unfold CorrectionFrontierIndex.acyclic
  rw [ReplacementFrontier.acyclicIndexedBy_eq_acyclic]
  rw [buildCorrectionFrontierIndex_edges_eq]

private def hashSetContainsDupStep (p : Std.HashSet String × Bool) (x : String) :
    Std.HashSet String × Bool :=
  (p.1.insert x, p.2 || p.1.contains x)

private theorem hashSetContainsDupStep_foldl_eq_false
    (xs : List String) (s : Std.HashSet String) (dup : Bool) :
    (xs.foldl hashSetContainsDupStep (s, dup)).2 = false ↔
      dup = false ∧ xs.Nodup ∧ ∀ x ∈ xs, s.contains x = false := by
  induction xs generalizing s dup with
  | nil =>
      simp
  | cons x rest ih =>
      simp only [List.foldl_cons, hashSetContainsDupStep]
      rw [ih]
      simp only [Bool.or_eq_false_iff, Std.HashSet.contains_insert]
      constructor
      · intro ⟨⟨hDup, hNotContains⟩, hRestNodup, hRestNotContains⟩
        refine ⟨hDup, ?_, ?_⟩
        · rw [List.nodup_cons]
          refine ⟨?_, hRestNodup⟩
          intro hMem
          have hNotEq := (hRestNotContains x hMem).1
          have hSelf : (x == x) = true := beq_self_eq_true' x
          rw [hSelf] at hNotEq
          contradiction
        · intro y hy
          cases hy with
          | head => exact hNotContains
          | tail _ hyRest => exact (hRestNotContains y hyRest).2
      · intro ⟨hDup, hConsNodup, hConsNotContains⟩
        rw [List.nodup_cons] at hConsNodup
        obtain ⟨hNotMem, hRestNodup⟩ := hConsNodup
        have hNotContains : s.contains x = false := hConsNotContains x List.mem_cons_self
        refine ⟨⟨hDup, hNotContains⟩, hRestNodup, ?_⟩
        intro y hyRest
        have hyNotContains := hConsNotContains y (List.mem_cons_of_mem x hyRest)
        have hBeqFalse : (x == y) = false := by
          cases hEq : (x == y) with
          | false => rfl
          | true =>
              have : x = y := eq_of_beq hEq
              subst this
              contradiction
        exact ⟨hBeqFalse, hyNotContains⟩

private theorem hashSetContainsDupStep_foldl_empty_eq_false (xs : List String) :
    (xs.foldl hashSetContainsDupStep ({}, false)).2 = false ↔ xs.Nodup := by
  rw [hashSetContainsDupStep_foldl_eq_false]
  simp [Std.HashSet.contains_empty]

private theorem nodup_map_token_iff {α : Type} (l : List α) (f : α → EventId) :
    (l.map (fun x => (f x).token)).Nodup ↔ (l.map f).Nodup := by
  induction l with
  | nil => simp
  | cons x rest ih =>
      simp only [List.map_cons, List.nodup_cons, ih]
      constructor
      · intro ⟨hNotMemToken, hRestNodup⟩
        refine ⟨?_, hRestNodup⟩
        intro hMem
        rcases List.mem_map.mp hMem with ⟨y, hyRest, hyEq⟩
        apply hNotMemToken
        apply List.mem_map.mpr
        refine ⟨y, hyRest, ?_⟩
        simp [hyEq]
      · intro ⟨hNotMem, hRestNodup⟩
        refine ⟨?_, hRestNodup⟩
        intro hMemToken
        rcases List.mem_map.mp hMemToken with ⟨y, hyRest, hyEq⟩
        have hIdEq : f y = f x := eventIdToken_injective hyEq
        apply hNotMem
        apply List.mem_map.mpr
        exact ⟨y, hyRest, hIdEq⟩

private theorem scanCorrections_targetDup_eq
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) :
    ((scanCorrections eventMap corrections).targetSet,
     (scanCorrections eventMap corrections).hasDuplicateTarget) =
      (corrections.map (fun c => c.target.token)).foldl hashSetContainsDupStep ({}, false) := by
  have hGeneral :
      ∀ (corrections : List EventCorrection) (state : CorrectionScanState),
        ((corrections.foldl
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
            }) state).targetSet,
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
            }) state).hasDuplicateTarget) =
          (corrections.map (fun c => c.target.token)).foldl
            hashSetContainsDupStep (state.targetSet, state.hasDuplicateTarget) := by
    intro corrections
    induction corrections with
    | nil =>
        intro state
        rfl
    | cons c rest ih =>
        intro state
        simp only [List.foldl_cons, List.map_cons]
        rw [ih]
        rfl
  unfold scanCorrections
  exact hGeneral corrections _

private theorem scanCorrections_replacementDup_eq
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) :
    ((scanCorrections eventMap corrections).replacementSet,
     (scanCorrections eventMap corrections).hasDuplicateReplacement) =
      (corrections.map (fun c => c.replacement.token)).foldl hashSetContainsDupStep ({}, false) := by
  have hGeneral :
      ∀ (corrections : List EventCorrection) (state : CorrectionScanState),
        ((corrections.foldl
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
            }) state).replacementSet,
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
            }) state).hasDuplicateReplacement) =
          (corrections.map (fun c => c.replacement.token)).foldl
            hashSetContainsDupStep (state.replacementSet, state.hasDuplicateReplacement) := by
    intro corrections
    induction corrections with
    | nil =>
        intro state
        rfl
    | cons c rest ih =>
        intro state
        simp only [List.foldl_cons, List.map_cons]
        rw [ih]
        rfl
  unfold scanCorrections
  exact hGeneral corrections _

/--
Indexed endpoint uniqueness check produces the exact same boolean result as legacy specification.
-/
theorem buildCorrectionFrontierIndex_endpointUnique_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).endpointUnique =
      ReplacementFrontier.endpointUnique (correctionEdges corrections) := by
  unfold CorrectionFrontierIndex.endpointUnique ReplacementFrontier.endpointUnique correctionEdges buildCorrectionFrontierIndex
  dsimp only
  have hTargetDup :
      (scanCorrections (events.events.foldl (fun map event => map.insert event.id.token event) ∅) corrections.corrections).hasDuplicateTarget =
        ((corrections.corrections.map (fun c => c.target.token)).foldl hashSetContainsDupStep ({}, false)).2 := by
    have h := scanCorrections_targetDup_eq (events.events.foldl (fun map event => map.insert event.id.token event) ∅) corrections.corrections
    exact congrArg Prod.snd h
  have hReplDup :
      (scanCorrections (events.events.foldl (fun map event => map.insert event.id.token event) ∅) corrections.corrections).hasDuplicateReplacement =
        ((corrections.corrections.map (fun c => c.replacement.token)).foldl hashSetContainsDupStep ({}, false)).2 := by
    have h := scanCorrections_replacementDup_eq (events.events.foldl (fun map event => map.insert event.id.token event) ∅) corrections.corrections
    exact congrArg Prod.snd h
  rw [hTargetDup, hReplDup]
  have hTargetNodup :
      ((corrections.corrections.map (fun c => c.target.token)).foldl hashSetContainsDupStep ({}, false)).2 = false ↔
        ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup := by
    rw [hashSetContainsDupStep_foldl_empty_eq_false]
    rw [nodup_map_token_iff]
    have : ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source) =
        (corrections.corrections.map fun c => c.target) := by
      simp [List.map_map]
    rw [this]
  have hReplNodup :
      ((corrections.corrections.map (fun c => c.replacement.token)).foldl hashSetContainsDupStep ({}, false)).2 = false ↔
        ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup := by
    rw [hashSetContainsDupStep_foldl_empty_eq_false]
    rw [nodup_map_token_iff]
    have : ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor) =
        (corrections.corrections.map fun c => c.replacement) := by
      simp [List.map_map]
    rw [this]
  cases hT : ((corrections.corrections.map (fun c => c.target.token)).foldl hashSetContainsDupStep ({}, false)).2 with
  | true =>
      simp only [Bool.not_true, Bool.false_and]
      have hNot : ¬((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup := by
        intro h
        rw [← hTargetNodup] at h
        rw [h] at hT
        contradiction
      have hAndNot : ¬(((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup ∧
                       ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup) :=
        fun ⟨h1, _⟩ => hNot h1
      have hDec : decide (((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup ∧
                          ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup) = false :=
        decide_eq_false hAndNot
      rw [hDec]
  | false =>
      simp only [Bool.not_false, Bool.true_and]
      have hTTrue : ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup :=
        hTargetNodup.mp hT
      cases hR : ((corrections.corrections.map (fun c => c.replacement.token)).foldl hashSetContainsDupStep ({}, false)).2 with
      | true =>
          simp only [Bool.not_true]
          have hNot : ¬((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup := by
            intro h
            rw [← hReplNodup] at h
            rw [h] at hR
            contradiction
          have hAndNot : ¬(((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup ∧
                           ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup) :=
            fun ⟨_, h2⟩ => hNot h2
          have hDec : decide (((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup ∧
                              ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup) = false :=
            decide_eq_false hAndNot
          rw [hDec]
      | false =>
          simp only [Bool.not_false]
          have hRTrue : ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup :=
            hReplNodup.mp hR
          have hDec : decide (((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.source).Nodup ∧
                              ((corrections.corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).map ReplacementFrontier.Edge.successor).Nodup) = true :=
            decide_eq_true ⟨hTTrue, hRTrue⟩
          rw [hDec]

private theorem findBy?_isSome_iff {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key) (items : List Item) (key : Key) :
    (FiniteKeyed.findBy? keyOf items key).isSome = true ↔ ∃ item ∈ items, keyOf item = key := by
  induction items with
  | nil => simp [FiniteKeyed.findBy?]
  | cons item rest ih =>
      simp only [FiniteKeyed.findBy?]
      split
      · rename_i hEq
        simp [hEq]
      · rename_i hNe
        simp only [ih]
        constructor
        · intro ⟨item', hMem, hKey⟩
          exact ⟨item', List.mem_cons_of_mem item hMem, hKey⟩
        · intro ⟨item', hMem, hKey⟩
          cases hMem with
          | head =>
              subst hKey
              contradiction
          | tail _ hTail =>
              exact ⟨item', hTail, hKey⟩

private theorem foldl_insert_eventMap_contains
    (events : List Event)
    (m : Std.HashMap String Event)
    (id : EventId) :
    (events.foldl (fun map event => map.insert event.id.token event) m).contains id.token = true ↔
      (m.contains id.token = true ∨ ∃ e ∈ events, e.id = id) := by
  induction events generalizing m with
  | nil => simp
  | cons e rest ih =>
      simp only [List.foldl_cons]
      rw [ih]
      rw [Std.HashMap.contains_insert]
      simp only [Bool.or_eq_true, beq_iff_eq]
      constructor
      · intro h
        rcases h with (hEq | hMap) | ⟨e', he'Rest, he'Eq⟩
        · right
          have hIdEq : e.id = id := eventIdToken_injective hEq
          exact ⟨e, List.mem_cons_self, hIdEq⟩
        · left; exact hMap
        · right
          exact ⟨e', List.mem_cons_of_mem e he'Rest, he'Eq⟩
      · intro h
        rcases h with hMap | ⟨e', he'Cons, he'Eq⟩
        · left; right; exact hMap
        · cases he'Cons with
          | head =>
              left; left
              subst he'Eq
              rfl
          | tail _ hTail =>
              right
              exact ⟨e', hTail, he'Eq⟩

private theorem eventMap_contains_eq_eventPresent
    (events : EventMemory) (id : EventId) :
    (events.events.foldl (fun (m : Std.HashMap String Event) event => m.insert event.id.token event) {}).contains id.token =
      eventPresent events id := by
  have hPresIff : eventPresent events id = true ↔ ∃ e ∈ events.events, e.id = id := by
    unfold eventPresent EventMemory.findById?
    exact findBy?_isSome_iff Event.id events.events id
  cases hPres : eventPresent events id with
  | true =>
      rw [hPresIff] at hPres
      have hCont : (events.events.foldl (fun (m : Std.HashMap String Event) event => m.insert event.id.token event) {}).contains id.token = true := by
        rw [foldl_insert_eventMap_contains]
        right
        exact hPres
      rw [hCont]
  | false =>
      have hNotPres : ¬(eventPresent events id = true) := by simp [hPres]
      rw [hPresIff] at hNotPres
      cases hCont : (events.events.foldl (fun (m : Std.HashMap String Event) event => m.insert event.id.token event) {}).contains id.token with
      | false => rfl
      | true =>
          rw [foldl_insert_eventMap_contains] at hCont
          rcases hCont with hEmpty | hExists
          · simp at hEmpty
          · exact False.elim (hNotPres hExists)

private def scanUnknownEndpointStep (eventMap : Std.HashMap String Event) (unk : Bool) (c : EventCorrection) : Bool :=
  unk || !eventMap.contains c.target.token || !eventMap.contains c.replacement.token

private theorem scanUnknownEndpointStep_foldl_eq_false
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) (unk : Bool) :
    (corrections.foldl (scanUnknownEndpointStep eventMap) unk) = false ↔
      unk = false ∧ ∀ c ∈ corrections, eventMap.contains c.target.token = true ∧ eventMap.contains c.replacement.token = true := by
  induction corrections generalizing unk with
  | nil =>
      simp
  | cons c rest ih =>
      simp only [List.foldl_cons, scanUnknownEndpointStep]
      rw [ih]
      simp only [Bool.or_eq_false_iff, Bool.not_eq_false']
      constructor
      · intro ⟨⟨⟨hUnk, hT⟩, hR⟩, hRest⟩
        refine ⟨hUnk, ?_⟩
        intro c' hc'
        cases hc' with
        | head => exact ⟨hT, hR⟩
        | tail _ hc'Rest => exact hRest c' hc'Rest
      · intro ⟨hUnk, hCons⟩
        have hHead := hCons c List.mem_cons_self
        refine ⟨⟨⟨hUnk, hHead.1⟩, hHead.2⟩, ?_⟩
        intro c' hc'Rest
        exact hCons c' (List.mem_cons_of_mem c hc'Rest)

private theorem scanCorrections_hasUnknownEndpoint_eq
    (eventMap : Std.HashMap String Event)
    (corrections : List EventCorrection) :
    (scanCorrections eventMap corrections).hasUnknownEndpoint =
      corrections.foldl (scanUnknownEndpointStep eventMap) false := by
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
            }) state).hasUnknownEndpoint =
          corrections.foldl (scanUnknownEndpointStep eventMap) state.hasUnknownEndpoint := by
    intro corrections
    induction corrections with
    | nil =>
        intro state
        rfl
    | cons c rest ih =>
        intro state
        simp only [List.foldl_cons]
        rw [ih]
        rfl
  unfold scanCorrections
  exact hGeneral corrections _

private theorem referencesClosed_eq_true_iff
    (present : EventId → Bool)
    (corrections : List EventCorrection) :
    (ReplacementFrontier.referencesClosed present
      (corrections.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId))) = true ↔
      ∀ c ∈ corrections, present c.target = true ∧ present c.replacement = true := by
  induction corrections with
  | nil => simp [ReplacementFrontier.referencesClosed]
  | cons c rest ih =>
      simp only [List.map_cons, ReplacementFrontier.referencesClosed, List.all_cons,
        Bool.and_eq_true]
      have ih' : ((rest.map fun c => ({ source := c.target, successor := c.replacement } : ReplacementFrontier.Edge EventId)).all
        fun edge => present edge.source && present edge.successor) = true ↔
        ∀ c ∈ rest, present c.target = true ∧ present c.replacement = true := ih
      rw [ih']
      constructor
      · intro ⟨⟨hT, hR⟩, hRest⟩
        intro c' hc'
        cases hc' with
        | head => exact ⟨hT, hR⟩
        | tail _ hc'Rest => exact hRest c' hc'Rest
      · intro hCons
        have hHead := hCons c List.mem_cons_self
        refine ⟨⟨hHead.1, hHead.2⟩, ?_⟩
        intro c' hc'Rest
        exact hCons c' (List.mem_cons_of_mem c hc'Rest)

/--
Indexed reference closure produces the exact same boolean result as legacy diagnostic facet.
-/
theorem buildCorrectionFrontierIndex_referencesClosed_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).referencesClosed =
      correctionReferencesClosed events corrections := by
  unfold CorrectionFrontierIndex.referencesClosed correctionReferencesClosed buildCorrectionFrontierIndex
  dsimp only
  rw [scanCorrections_hasUnknownEndpoint_eq]
  have hScanClosed :
      corrections.corrections.foldl
        (scanUnknownEndpointStep (events.events.foldl (fun map event => map.insert event.id.token event) ∅)) false = false ↔
        ∀ c ∈ corrections.corrections, eventPresent events c.target = true ∧ eventPresent events c.replacement = true := by
    rw [scanUnknownEndpointStep_foldl_eq_false]
    simp only [true_and]
    constructor
    · intro h c hc
      have hC := h c hc
      rw [eventMap_contains_eq_eventPresent, eventMap_contains_eq_eventPresent] at hC
      exact hC
    · intro h c hc
      have hC := h c hc
      rw [← eventMap_contains_eq_eventPresent, ← eventMap_contains_eq_eventPresent] at hC
      exact hC
  cases hUnk : corrections.corrections.foldl
    (scanUnknownEndpointStep (events.events.foldl (fun map event => map.insert event.id.token event) ∅)) false with
  | true =>
      simp only [Bool.not_true]
      have hNotClosed : ¬(ReplacementFrontier.referencesClosed (eventPresent events) (correctionEdges corrections) = true) := by
        intro hC
        unfold correctionEdges at hC
        rw [referencesClosed_eq_true_iff] at hC
        have hFalse := hScanClosed.mpr hC
        rw [hFalse] at hUnk
        contradiction
      cases hRes : ReplacementFrontier.referencesClosed (eventPresent events) (correctionEdges corrections) with
      | false => rfl
      | true => exact False.elim (hNotClosed hRes)
  | false =>
      simp only [Bool.not_false]
      have hClosed := hScanClosed.mp hUnk
      unfold correctionEdges
      have hClosedTrue := (referencesClosed_eq_true_iff (eventPresent events) corrections.corrections).mpr hClosed
      rw [hClosedTrue]

/--
Indexed admissibility matches `correctionFrontierAdmissible` across all topologies.
-/
theorem buildCorrectionFrontierIndex_admissible_eq
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    (buildCorrectionFrontierIndex events corrections).admissible =
      correctionFrontierAdmissible events corrections := by
  unfold CorrectionFrontierIndex.admissible correctionFrontierAdmissible
  rw [buildCorrectionFrontierIndex_endpointUnique_eq]
  rw [buildCorrectionFrontierIndex_referencesClosed_eq]
  rw [buildCorrectionFrontierIndex_acyclic_eq]
  unfold ReplacementFrontier.structurallyAdmissible ReplacementFrontier.acyclic correctionReferencesClosed
  cases hEp : ReplacementFrontier.endpointUnique (correctionEdges corrections) with
  | false =>
      simp
  | true =>
      simp

private theorem eventMemory_eq_of_events_eq
    (e1 e2 : EventMemory)
    (h : e1.events = e2.events) : e1 = e2 := by
  cases e1
  cases e2
  dsimp at h
  subst h
  rfl

/--
General semantic equivalence theorem: `correctionFrontierMemoryIndexed?` evaluated
with `buildCorrectionFrontierIndex` produces the exact same frontier memory as
the reference specification `correctionFrontierMemoryLegacy?`.
-/
theorem correctionFrontierMemoryIndexed?_eq_legacy
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    correctionFrontierMemoryIndexed?
        events corrections
        (buildCorrectionFrontierIndex events corrections)
      =
    correctionFrontierMemoryLegacy? events corrections := by
  unfold correctionFrontierMemoryIndexed? correctionFrontierMemoryLegacy?
  rw [buildCorrectionFrontierIndex_admissible_eq]
  split
  · rfl
  · split
    · congr 1
      apply eventMemory_eq_of_events_eq
      exact buildCorrectionFrontierIndex_frontierEvents_eq events corrections
    · rfl

/--
Universal general correspondence theorem: `correctionFrontierMemoryIndexed?` evaluated
with `buildCorrectionFrontierIndex` corresponds identically to `correctionFrontierMemory?`.
-/
theorem correctionFrontierMemoryIndexed?_eq_correctionFrontierMemory?
    (events : EventMemory) (corrections : EventCorrectionMemory) :
    correctionFrontierMemoryIndexed? events corrections (buildCorrectionFrontierIndex events corrections) =
      correctionFrontierMemory? events corrections := rfl

/--
Universal semantic correspondence between production `correctionFrontierMemory?`
and the reference specification `correctionFrontierMemoryLegacy?`.
-/
theorem correctionFrontierMemory?_eq_legacy
    (events : EventMemory)
    (corrections : EventCorrectionMemory) :
    correctionFrontierMemory? events corrections =
      correctionFrontierMemoryLegacy? events corrections := by
  rw [← correctionFrontierMemoryIndexed?_eq_correctionFrontierMemory?]
  exact correctionFrontierMemoryIndexed?_eq_legacy events corrections

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
