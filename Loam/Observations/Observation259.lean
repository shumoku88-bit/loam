import Loam.Observations.Observation258

namespace Loam.Observation259

open Loam.Core

set_option autoImplicit false

/-!
# Observation 259 — human-readable correction explanation from retained evidence

Observation 258 qualified an exact finite support of all nonzero
`LocusId × MeasureId` correction quantity changes. This observation asks whether
that complete diff can be lifted into the familiar read-side labels
`added / removed / changed` without retaining new correction truth.

The key semantic guard is important: a zero aggregate quantity does **not** mean
that a coordinate was absent from an Event. Multiple Effects at one coordinate
may cancel exactly. Therefore change labels are derived from physical coordinate
presence in the original/replacement Effect lists, while nonzero quantity delta
comes from Observation 258.
-/

/-- Human-facing shape of one already-qualified changed coordinate. Research-only. -/
inductive CorrectionChangeKind where
  | added
  | removed
  | changed
deriving Repr, DecidableEq

/--
Classify one coordinate by whether it is physically represented by the original
and replacement Events.

This function is intended only for coordinates already known to be in
`Observation258.changedCoordinates`. On that support, Observation 258 excludes
the impossible `absent in both` case.
-/
def changeKindAt
    (original replacement : Event) (coordinate : EffectCoordinate) :
    CorrectionChangeKind :=
  if coordinate ∈ Loam.Observation258.eventCoordinates original then
    if coordinate ∈ Loam.Observation258.eventCoordinates replacement then
      .changed
    else
      .removed
  else
    .added

/-- One display row: the exact O257 quantity delta plus a derived human label. -/
structure CorrectionExplanation where
  delta : Loam.Observation257.CoordinateDelta
  kind : CorrectionChangeKind
deriving Repr, DecidableEq

/-- Explain one coordinate already selected by the O258 changed support. -/
def explainChangedAt
    (original replacement : Event) (coordinate : EffectCoordinate) :
    CorrectionExplanation :=
  { delta := Loam.Observation257.deltaAt
      original replacement coordinate.locus coordinate.measure
    kind := changeKindAt original replacement coordinate }

/-- Complete finite human-readable explanation. No new authority is stored. -/
def completeExplanation
    (original replacement : Event) : List CorrectionExplanation :=
  (Loam.Observation258.changedCoordinates original replacement).map
    (explainChangedAt original replacement)

private theorem changed_coordinate_has_presence
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hChanged : coordinate ∈
      Loam.Observation258.changedCoordinates original replacement) :
    coordinate ∈ Loam.Observation258.eventCoordinates original ∨
      coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
  have hNonzero :=
    (Loam.Observation258.mem_changedCoordinates_iff_nonzero
      original replacement coordinate).1 hChanged
  have hCandidate :=
    Loam.Observation258.nonzeroDelta_mem_candidateCoordinates
      original replacement coordinate hNonzero
  exact
    (Loam.Observation258.mem_candidateCoordinates_iff
      original replacement coordinate).1 hCandidate

/--
On the exact changed support, `added` means coordinate absence in the original
and physical presence in the replacement. It is not inferred from `before = 0`.
-/
theorem changeKindAt_eq_added_iff
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hChanged : coordinate ∈
      Loam.Observation258.changedCoordinates original replacement) :
    changeKindAt original replacement coordinate = .added ↔
      coordinate ∉ Loam.Observation258.eventCoordinates original ∧
      coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
  have hPresence := changed_coordinate_has_presence
    original replacement coordinate hChanged
  by_cases hOriginal :
      coordinate ∈ Loam.Observation258.eventCoordinates original
  · by_cases hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement
    · simp [changeKindAt, hOriginal, hReplacement]
    · simp [changeKindAt, hOriginal, hReplacement]
  · have hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
      cases hPresence with
      | inl h => exact False.elim (hOriginal h)
      | inr h => exact h
    simp [changeKindAt, hOriginal, hReplacement]

/--
On the exact changed support, `removed` means physical presence in the original
and absence from the replacement.
-/
theorem changeKindAt_eq_removed_iff
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hChanged : coordinate ∈
      Loam.Observation258.changedCoordinates original replacement) :
    changeKindAt original replacement coordinate = .removed ↔
      coordinate ∈ Loam.Observation258.eventCoordinates original ∧
      coordinate ∉ Loam.Observation258.eventCoordinates replacement := by
  have hPresence := changed_coordinate_has_presence
    original replacement coordinate hChanged
  by_cases hOriginal :
      coordinate ∈ Loam.Observation258.eventCoordinates original
  · by_cases hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement
    · simp [changeKindAt, hOriginal, hReplacement]
    · simp [changeKindAt, hOriginal, hReplacement]
  · have hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
      cases hPresence with
      | inl h => exact False.elim (hOriginal h)
      | inr h => exact h
    simp [changeKindAt, hOriginal, hReplacement]

/--
On the exact changed support, `changed` means the coordinate is physically
represented in both Events and its aggregate quantity differs (the latter is
already guaranteed by membership in `changedCoordinates`).
-/
theorem changeKindAt_eq_changed_iff
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hChanged : coordinate ∈
      Loam.Observation258.changedCoordinates original replacement) :
    changeKindAt original replacement coordinate = .changed ↔
      coordinate ∈ Loam.Observation258.eventCoordinates original ∧
      coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
  have hPresence := changed_coordinate_has_presence
    original replacement coordinate hChanged
  by_cases hOriginal :
      coordinate ∈ Loam.Observation258.eventCoordinates original
  · by_cases hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement
    · simp [changeKindAt, hOriginal, hReplacement]
    · simp [changeKindAt, hOriginal, hReplacement]
  · have hReplacement :
        coordinate ∈ Loam.Observation258.eventCoordinates replacement := by
      cases hPresence with
      | inl h => exact False.elim (hOriginal h)
      | inr h => exact h
    simp [changeKindAt, hOriginal, hReplacement]

/-! ## Concrete fixture: changed, removed, added -/

private def originalEventId : EventId := ⟨"o259-original"⟩
private def replacementEventId : EventId := ⟨"o259-replacement"⟩
private def cash : LocusId := ⟨"o259-cash"⟩
private def paypay : LocusId := ⟨"o259-paypay"⟩
private def books : LocusId := ⟨"o259-books"⟩
private def yen : MeasureId := ⟨"o259-yen"⟩

private def originalEvent : Event :=
  { id := originalEventId
    effects :=
      [ Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-1000))
      , Effect.ofAnonymousQuantity paypay yen (Quantity.ofQuanta (-50)) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def replacementEvent : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-800))
      , Effect.ofAnonymousQuantity books yen (Quantity.ofQuanta 200) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

/-- Persistent coordinate with nonzero delta is labeled `changed`. -/
theorem cash_explains_changed :
    changeKindAt originalEvent replacementEvent ⟨cash, yen⟩ = .changed := by
  simp [changeKindAt, Loam.Observation258.eventCoordinates,
    originalEvent, replacementEvent, cash, paypay, books, yen, Effect.coordinate]

/-- Original-only changed coordinate is labeled `removed`. -/
theorem paypay_explains_removed :
    changeKindAt originalEvent replacementEvent ⟨paypay, yen⟩ = .removed := by
  simp [changeKindAt, Loam.Observation258.eventCoordinates,
    originalEvent, replacementEvent, cash, paypay, books, yen, Effect.coordinate]

/-- Replacement-only changed coordinate is labeled `added`. -/
theorem books_explains_added :
    changeKindAt originalEvent replacementEvent ⟨books, yen⟩ = .added := by
  simp [changeKindAt, Loam.Observation258.eventCoordinates,
    originalEvent, replacementEvent, cash, paypay, books, yen, Effect.coordinate]

/-! ## Counterexample to quantity-zero classification -/

private def cancellingLocus : LocusId := ⟨"o259-cancelling"⟩

private def cancellingOriginal : Event :=
  { id := ⟨"o259-cancel-original"⟩
    effects :=
      [ Effect.ofAnonymousQuantity cancellingLocus yen (Quantity.ofQuanta 100)
      , Effect.ofAnonymousQuantity cancellingLocus yen (Quantity.ofQuanta (-100)) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def cancellingReplacement : Event :=
  { id := ⟨"o259-cancel-replacement"⟩
    effects :=
      [ Effect.ofAnonymousQuantity cancellingLocus yen (Quantity.ofQuanta 50) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

/--
A coordinate can have exact aggregate quantity zero while still being physically
present. When its replacement quantity changes, the safe explanation is
`changed`, not `added`.
-/
theorem zero_before_does_not_imply_added :
    (Event.quantityAt cancellingOriginal cancellingLocus yen).quanta = 0 ∧
    Loam.Observation258.quantityDeltaQuantaAt
      cancellingOriginal cancellingReplacement ⟨cancellingLocus, yen⟩ = 50 ∧
    changeKindAt cancellingOriginal cancellingReplacement
      ⟨cancellingLocus, yen⟩ = .changed := by
  constructor
  · simp [cancellingOriginal, cancellingLocus, yen, Event.quantityAt, Effect.coordinate]
  constructor
  · simp [Loam.Observation258.quantityDeltaQuantaAt,
      Loam.Observation257.quantityDeltaQuanta,
      cancellingOriginal, cancellingReplacement, cancellingLocus, yen,
      Event.quantityAt, Effect.coordinate]
  · simp [changeKindAt, Loam.Observation258.eventCoordinates,
      cancellingOriginal, cancellingReplacement, cancellingLocus, yen,
      Effect.coordinate]

/-!
Observation boundary:

* `added / removed / changed` are derived read-side labels, not retained truth;
* labels depend on physical coordinate presence, not aggregate quantity being
  zero or nonzero;
* Observation 258 supplies exact finite changed support and nonzero delta;
* a persistent coordinate with cancelling Effects may have `before = 0` and is
  still correctly labeled `changed` when its quantity changes;
* the explanation layer does not imply Effect lineage, cause, chronology,
  accounting role, or user intent.

A human-readable correction explanation can therefore remain a pure projection
of retained Event evidence rather than a new authority family.
-/

end Loam.Observation259
