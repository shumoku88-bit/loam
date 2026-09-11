import Loam.Core.EventCorrectionMemory
import Loam.Application.ReplacementFrontier
import Lean.Elab.Tactic.Omega

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

/-- If every represented Event differs from one target identity, filtering that target changes nothing. -/
private theorem filterTarget_eq_self
    (items : List Event)
    (target : EventId)
    (hAbsent : ∀ event ∈ items, target ≠ event.id) :
    items.filter (fun event => decide (target ≠ event.id)) = items := by
  induction items with
  | nil => rfl
  | cons event rest ih =>
      have hEvent : target ≠ event.id := hAbsent event (by simp)
      have hRest : ∀ item ∈ rest, target ≠ item.id := by
        intro item hItem
        exact hAbsent item (by simp [hItem])
      simp only [List.filter]
      rw [ih hRest]
      simp [hEvent]

/--
With unique Event identity, filtering one present target from the recorded fold
is exactly the original fold minus that Event's contribution once.
-/
private theorem filterTargetQuantityFold
    (items : List Event)
    (target : EventId)
    (original : Event)
    (locus : LocusId)
    (measure : MeasureId)
    (hNodup : (items.map Event.id).Nodup)
    (hFind : FiniteKeyed.findBy? Event.id items target = some original) :
    (items.filter (fun event => decide (target ≠ event.id))).foldr
        (fun event total => (Event.quantityAt event locus measure).quanta + total)
        0 =
      items.foldr
          (fun event total => (Event.quantityAt event locus measure).quanta + total)
          0 - (Event.quantityAt original locus measure).quanta := by
  induction items generalizing original with
  | nil =>
      simp [FiniteKeyed.findBy?] at hFind
  | cons event rest ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases hHead : event.id = target
      · have hOriginal : event = original := by
          simpa [FiniteKeyed.findBy?, hHead] using hFind
        subst original
        have hTailAbsent : ∀ item ∈ rest, target ≠ item.id := by
          intro item hItem hTarget
          apply hNodup.1
          exact List.mem_map.mpr ⟨item, hItem, hTarget.symm.trans hHead.symm⟩
        have hFiltered := filterTarget_eq_self rest target hTailAbsent
        have hFilterAll :
            (event :: rest).filter (fun item => decide (target ≠ item.id)) = rest := by
          simp only [List.filter]
          rw [hFiltered]
          simp [hHead]
        rw [hFilterAll]
        simp only [List.foldr_cons]
        omega
      · have hFindTail :
            FiniteKeyed.findBy? Event.id rest target = some original := by
          simpa [FiniteKeyed.findBy?, hHead] using hFind
        have hIH := ih original hNodup.2 hFindTail
        have hReverse : target ≠ event.id := Ne.symm hHead
        have hFilterAll :
            (event :: rest).filter (fun item => decide (target ≠ item.id)) =
              event :: rest.filter (fun item => decide (target ≠ item.id)) := by
          simp only [List.filter]
          simp [hReverse]
        rw [hFilterAll]
        simp only [List.foldr_cons]
        rw [hIH]
        omega

/-- Filtering an admitted Event list cannot introduce duplicate Event identity. -/
private theorem filteredEventIdsNodup
    (items : List Event)
    (predicate : Event → Bool)
    (hNodup : (items.map Event.id).Nodup) :
    ((items.filter predicate).map Event.id).Nodup := by
  induction items with
  | nil =>
      simp
  | cons event rest ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      simp only [List.filter]
      by_cases hKeep : predicate event = true
      · have hTailNodup := ih hNodup.2
        have hHeadFresh :
            event.id ∉ (rest.filter predicate).map Event.id := by
          intro hMem
          apply hNodup.1
          simp only [List.mem_map] at hMem ⊢
          obtain ⟨item, hItem, hId⟩ := hMem
          exact ⟨item, (List.mem_filter.mp hItem).1, hId⟩
        simp [hKeep, hHeadFresh, hTailNodup]
      · simp [hKeep, ih hNodup.2]

/-- A singleton correction frontier filters exactly the correction target identity. -/
private theorem frontierEvents_singleton_eq_filterTarget
    (events : EventMemory)
    (correction : EventCorrection) :
    frontierEvents
        events
        { corrections := [correction], idNodup := by simp } =
      events.events.filter
        (fun event => decide (correction.target ≠ event.id)) := by
  unfold frontierEvents
  induction events.events with
  | nil =>
      rfl
  | cons event rest ih =>
      simp only [List.filter]
      by_cases hTarget : correction.target = event.id
      · simp [targetsEvent, hTarget]
      · simp [targetsEvent, hTarget]

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

/--
For one distinct correction with both endpoints present, the generic frontier
quantity is exactly the historical singleton arithmetic: recorded quantity minus
the target Event contribution once.
-/
theorem quantityAtCorrectionFrontier?_singleton_distinct
    (events : EventMemory)
    (correction : EventCorrection)
    (original replacement : Event)
    (locus : LocusId)
    (measure : MeasureId)
    (hDistinct : correction.target ≠ correction.replacement)
    (hOriginal :
      EventMemory.findById? events correction.target = some original)
    (hReplacement :
      EventMemory.findById? events correction.replacement = some replacement) :
    quantityAtCorrectionFrontier?
        events
        { corrections := [correction], idNodup := by simp }
        locus measure =
      some
        (EventMemory.quantityAtRecorded events locus measure -
          Event.quantityAt original locus measure) := by
  let corrections : EventCorrectionMemory :=
    { corrections := [correction], idNodup := by simp }
  have hAdmissible : correctionFrontierAdmissible events corrections = true := by
    simp [correctionFrontierAdmissible, correctionEdges, corrections,
      eventPresent, hOriginal, hReplacement, hDistinct]
  have hFrontierEvents :
      frontierEvents events corrections =
        events.events.filter
          (fun event => decide (correction.target ≠ event.id)) := by
    simpa [corrections] using
      frontierEvents_singleton_eq_filterTarget events correction
  have hFrontierNodup :
      ((frontierEvents events corrections).map Event.id).Nodup := by
    unfold frontierEvents
    exact filteredEventIdsNodup
      events.events
      (fun event => !(targetsEvent corrections.corrections event.id))
      events.idNodup
  have hFrontier :
      correctionFrontierMemory? events corrections =
        some
          { events := frontierEvents events corrections,
            idNodup := hFrontierNodup } := by
    unfold correctionFrontierMemory?
    rw [if_pos (by simpa using hAdmissible)]
    unfold EventMemory.ofEvents?
    split
    · rfl
    · rename_i hRejected
      exact False.elim (hRejected hFrontierNodup)
  have hFind :
      FiniteKeyed.findBy? Event.id events.events correction.target = some original := by
    simpa [EventMemory.findById?] using hOriginal
  have hFold :=
    filterTargetQuantityFold
      events.events correction.target original locus measure events.idNodup hFind
  change quantityAtCorrectionFrontier? events corrections locus measure = _
  rw [quantityAtCorrectionFrontier?, hFrontier]
  simp only [EventMemory.quantityAtRecorded, Quantity.sub]
  rw [hFrontierEvents, hFold]

end Loam.Application
