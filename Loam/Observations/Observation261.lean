import Loam.Observations.Observation260

namespace Loam.Observation261

open Loam.Core

set_option autoImplicit false

/-!
# Observation 261 — arbitrary finite correction-diff composition

Observation 260 qualified exact composition across one intermediate Event.
This observation asks whether that local law closes under arbitrary finite
repetition.

A research chain is represented minimally as one first Event plus a List of
successive Events. This file proves only the read-side algebra of that selected
sequence. It does not claim that the List is itself authoritative correction
topology; connecting a sequence to retained `EventCorrection` edges is a
separate question.
-/

/-- Endpoint of a finite selected Event sequence. -/
def chainLast : Event → List Event → Event
  | first, [] => first
  | _, next :: rest => chainLast next rest

/-- Sum of every adjacent coordinate delta along a finite selected sequence. -/
def chainDeltaSum
    (first : Event) : List Event → EffectCoordinate → Int
  | [], _ => 0
  | next :: rest, coordinate =>
      Loam.Observation258.quantityDeltaQuantaAt first next coordinate +
        chainDeltaSum next rest coordinate

/--
Arbitrary finite telescoping law.

The sum of all adjacent coordinate deltas is exactly the direct delta from the
first Event to the selected endpoint. The zero-step case is included.
-/
theorem chainDeltaSum_eq_endpoint
    (first : Event) (rest : List Event) (coordinate : EffectCoordinate) :
    chainDeltaSum first rest coordinate =
      Loam.Observation258.quantityDeltaQuantaAt
        first (chainLast first rest) coordinate := by
  induction rest generalizing first with
  | nil =>
      simp [chainDeltaSum, chainLast,
        Loam.Observation258.quantityDeltaQuantaAt,
        Loam.Observation257.quantityDeltaQuanta]
  | cons next tail ih =>
      simp only [chainDeltaSum, chainLast]
      rw [ih next]
      have hCompose := Loam.Observation260.quantityDeltaQuantaAt_compose
        first next (chainLast next tail) coordinate
      simpa [Loam.Observation260.composedDeltaQuantaAt] using hCompose.symm

/--
Finite union of all one-step changed-coordinate supports. Duplicates are erased
only on this read projection.
-/
def chainStepChangedCoordinates : Event → List Event → List EffectCoordinate
  | _, [] => []
  | first, next :: rest =>
      (Loam.Observation258.changedCoordinates first next ++
        chainStepChangedCoordinates next rest).eraseDups

/-- Membership at a nonempty chain step is membership in the head step or tail support. -/
theorem mem_chainStepChangedCoordinates_cons_iff
    (first next : Event) (rest : List Event) (coordinate : EffectCoordinate) :
    coordinate ∈ chainStepChangedCoordinates first (next :: rest) ↔
      coordinate ∈ Loam.Observation258.changedCoordinates first next ∨
      coordinate ∈ chainStepChangedCoordinates next rest := by
  simp [chainStepChangedCoordinates]

/--
Every nonzero endpoint delta must have appeared in at least one adjacent step.
There are no endpoint changes that arise outside the finite union of step diffs.
-/
theorem endpoint_nonzero_mem_chainStepChangedCoordinates
    (first : Event) (rest : List Event) (coordinate : EffectCoordinate)
    (hEndpoint : Loam.Observation258.quantityDeltaQuantaAt
      first (chainLast first rest) coordinate ≠ 0) :
    coordinate ∈ chainStepChangedCoordinates first rest := by
  induction rest generalizing first with
  | nil =>
      have hZero : Loam.Observation258.quantityDeltaQuantaAt
          first (chainLast first []) coordinate = 0 := by
        simp [chainLast,
          Loam.Observation258.quantityDeltaQuantaAt,
          Loam.Observation257.quantityDeltaQuanta]
      exact False.elim (hEndpoint hZero)
  | cons next tail ih =>
      simp only [chainLast] at hEndpoint
      by_cases hHead :
          Loam.Observation258.quantityDeltaQuantaAt first next coordinate = 0
      · have hTail : Loam.Observation258.quantityDeltaQuantaAt
            next (chainLast next tail) coordinate ≠ 0 := by
          intro hTailZero
          apply hEndpoint
          rw [Loam.Observation260.quantityDeltaQuantaAt_compose
            first next (chainLast next tail) coordinate]
          simp [Loam.Observation260.composedDeltaQuantaAt, hHead, hTailZero]
        have hTailMem := ih next hTail
        exact (mem_chainStepChangedCoordinates_cons_iff
          first next tail coordinate).2 (Or.inr hTailMem)
      · have hHeadMem : coordinate ∈
            Loam.Observation258.changedCoordinates first next :=
          (Loam.Observation258.mem_changedCoordinates_iff_nonzero
            first next coordinate).2 hHead
        exact (mem_chainStepChangedCoordinates_cons_iff
          first next tail coordinate).2 (Or.inl hHeadMem)

/--
Exact endpoint support reconstructed from all step supports.

The union is filtered by the summed chain delta because intermediate changes can
cancel over any number of steps.
-/
def chainComposedChangedCoordinates
    (first : Event) (rest : List Event) : List EffectCoordinate :=
  (chainStepChangedCoordinates first rest).filter
    (fun coordinate => decide (chainDeltaSum first rest coordinate ≠ 0))

/-- Membership in the composed finite-chain support is exactly nonzero endpoint delta. -/
theorem mem_chainComposedChangedCoordinates_iff_nonzero_endpoint
    (first : Event) (rest : List Event) (coordinate : EffectCoordinate) :
    coordinate ∈ chainComposedChangedCoordinates first rest ↔
      Loam.Observation258.quantityDeltaQuantaAt
        first (chainLast first rest) coordinate ≠ 0 := by
  constructor
  · intro hMem
    simp only [chainComposedChangedCoordinates, List.mem_filter] at hMem
    have hSum : chainDeltaSum first rest coordinate ≠ 0 :=
      of_decide_eq_true hMem.2
    intro hEndpointZero
    apply hSum
    rw [chainDeltaSum_eq_endpoint]
    exact hEndpointZero
  · intro hEndpoint
    have hStep := endpoint_nonzero_mem_chainStepChangedCoordinates
      first rest coordinate hEndpoint
    have hSum : chainDeltaSum first rest coordinate ≠ 0 := by
      intro hZero
      apply hEndpoint
      rw [← chainDeltaSum_eq_endpoint]
      exact hZero
    simp [chainComposedChangedCoordinates, hStep, hSum]

/--
Exact arbitrary finite-chain support law. List order is intentionally outside
the claim; semantic membership equals the direct endpoint O258 support.
-/
theorem mem_chainComposedChangedCoordinates_iff_direct
    (first : Event) (rest : List Event) (coordinate : EffectCoordinate) :
    coordinate ∈ chainComposedChangedCoordinates first rest ↔
      coordinate ∈ Loam.Observation258.changedCoordinates
        first (chainLast first rest) := by
  rw [mem_chainComposedChangedCoordinates_iff_nonzero_endpoint]
  exact (Loam.Observation258.mem_changedCoordinates_iff_nonzero
    first (chainLast first rest) coordinate).symm

/-- Complete endpoint quantity diff reconstructed from the finite chain projection. -/
def chainCompleteDiff
    (first : Event) (rest : List Event) :
    List Loam.Observation257.CoordinateDelta :=
  (chainComposedChangedCoordinates first rest).map
    (fun coordinate =>
      Loam.Observation257.deltaAt
        first (chainLast first rest) coordinate.locus coordinate.measure)

/-! ## Three-step witness: intermediate motion may cancel across a longer chain -/

private def pulse : LocusId := ⟨"o261-pulse"⟩
private def net : LocusId := ⟨"o261-net"⟩
private def yen : MeasureId := ⟨"o261-yen"⟩
private def pulseCoordinate : EffectCoordinate := ⟨pulse, yen⟩
private def netCoordinate : EffectCoordinate := ⟨net, yen⟩

private def e0 : Event :=
  { id := ⟨"o261-e0"⟩
    effects :=
      [Effect.ofAnonymousQuantity net yen (Quantity.ofQuanta 10)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def e1 : Event :=
  { id := ⟨"o261-e1"⟩
    effects :=
      [ Effect.ofAnonymousQuantity pulse yen (Quantity.ofQuanta 100)
      , Effect.ofAnonymousQuantity net yen (Quantity.ofQuanta 20) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def e2 : Event :=
  { id := ⟨"o261-e2"⟩
    effects :=
      [ Effect.ofAnonymousQuantity pulse yen (Quantity.ofQuanta 40)
      , Effect.ofAnonymousQuantity net yen (Quantity.ofQuanta 15) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def e3 : Event :=
  { id := ⟨"o261-e3"⟩
    effects :=
      [Effect.ofAnonymousQuantity net yen (Quantity.ofQuanta 30)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def chain : List Event := [e1, e2, e3]

/-- The selected chain has three adjacent steps and ends at `e3`. -/
theorem selected_chain_endpoint : chainLast e0 chain = e3 := by
  rfl

/-- Pulse moves +100, then -60, then -40, so the arbitrary-chain sum cancels. -/
theorem pulse_chain_sum_cancels :
    chainDeltaSum e0 chain pulseCoordinate = 0 := by
  simp [chainDeltaSum, chain, pulseCoordinate, pulse, net, yen,
    e0, e1, e2, e3,
    Loam.Observation258.quantityDeltaQuantaAt,
    Loam.Observation257.quantityDeltaQuanta,
    Event.quantityAt, Effect.coordinate]

/-- The pulse coordinate appears in step history but disappears from endpoint support. -/
theorem pulse_seen_in_steps_but_not_endpoint :
    pulseCoordinate ∈ chainStepChangedCoordinates e0 chain ∧
      pulseCoordinate ∉ chainComposedChangedCoordinates e0 chain := by
  constructor
  · simp [chainStepChangedCoordinates, chain,
      Loam.Observation258.mem_changedCoordinates_iff_nonzero,
      Loam.Observation258.quantityDeltaQuantaAt,
      Loam.Observation257.quantityDeltaQuanta,
      pulseCoordinate, pulse, net, yen, e0, e1, e2, e3,
      Event.quantityAt, Effect.coordinate]
  · intro hMem
    have hNonzero :=
      (mem_chainComposedChangedCoordinates_iff_nonzero_endpoint
        e0 chain pulseCoordinate).1 hMem
    apply hNonzero
    simpa [selected_chain_endpoint] using
      (show Loam.Observation258.quantityDeltaQuantaAt e0 e3 pulseCoordinate = 0 by
        simp [Loam.Observation258.quantityDeltaQuantaAt,
          Loam.Observation257.quantityDeltaQuanta,
          e0, e3, pulseCoordinate, pulse, net, yen,
          Event.quantityAt, Effect.coordinate])

/-- Net moves +10, -5, +15, giving the exact endpoint +20 change. -/
theorem net_chain_sum :
    chainDeltaSum e0 chain netCoordinate = 20 := by
  simp [chainDeltaSum, chain, netCoordinate, pulse, net, yen,
    e0, e1, e2, e3,
    Loam.Observation258.quantityDeltaQuantaAt,
    Loam.Observation257.quantityDeltaQuanta,
    Event.quantityAt, Effect.coordinate]

/-- The net coordinate survives the composed chain support and direct endpoint support. -/
theorem net_survives_endpoint_support :
    netCoordinate ∈ chainComposedChangedCoordinates e0 chain ∧
      netCoordinate ∈ Loam.Observation258.changedCoordinates e0 e3 := by
  have hDirect : Loam.Observation258.quantityDeltaQuantaAt
      e0 e3 netCoordinate ≠ 0 := by
    simp [Loam.Observation258.quantityDeltaQuantaAt,
      Loam.Observation257.quantityDeltaQuanta,
      e0, e3, netCoordinate, pulse, net, yen,
      Event.quantityAt, Effect.coordinate]
  constructor
  · exact (mem_chainComposedChangedCoordinates_iff_nonzero_endpoint
      e0 chain netCoordinate).2 <| by simpa [selected_chain_endpoint] using hDirect
  · exact (Loam.Observation258.mem_changedCoordinates_iff_nonzero
      e0 e3 netCoordinate).2 hDirect

/-!
Observation boundary:

* O260's two-step quantity composition closes under every finite selected Event sequence;
* the sum of all adjacent coordinate deltas equals the direct first-to-endpoint delta;
* every endpoint change appears in the finite union of adjacent step supports;
* filtering that union by nonzero total chain delta gives exactly the direct O258 endpoint support;
* intermediate motion can cancel across arbitrarily many steps and vanish end-to-end;
* no persistent chain-diff state, Effect lineage, or label-composition ontology is required.

This observation does **not** prove that an arbitrary List of Events is a valid
retained correction chain. It proves the algebra of a selected finite sequence.
A future observation may separately ask whether retained `EventCorrection`
evidence can derive such a sequence uniquely and safely.
-/

end Loam.Observation261
