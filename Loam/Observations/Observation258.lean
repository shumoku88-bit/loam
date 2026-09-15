import Loam.Observations.Observation257

namespace Loam.Observation258

open Loam.Core

set_option autoImplicit false

/-!
# Observation 258 — complete finite support for correction quantity change

Observation 257 proved that one queried correction delta can be explained from
`original.quantityAt` and `replacement.quantityAt` without cross-Event Effect
lineage. This observation asks whether every nonzero coordinate delta can be
found from a finite set already present in those two Events.

No retained diff, lineage relation, or Register family is introduced. The lists
below are research-only projections from retained Event evidence.
-/

/-- Coordinates physically represented by one Event. Representation order has no semantic meaning. -/
def eventCoordinates (event : Event) : List EffectCoordinate :=
  event.effects.map Effect.coordinate

/--
Finite candidate support for one Event correction.

Duplicates are removed only for the projected read surface. This does not merge
or identify the underlying Effects.
-/
def candidateCoordinates (original replacement : Event) : List EffectCoordinate :=
  (eventCoordinates original ++ eventCoordinates replacement).eraseDups

/-- Exact correction delta at one already-selected coordinate. -/
def quantityDeltaQuantaAt
    (original replacement : Event) (coordinate : EffectCoordinate) : Int :=
  Loam.Observation257.quantityDeltaQuanta
    original replacement coordinate.locus coordinate.measure

private theorem quantityFold_zero_of_coordinate_not_mem
    {effects : List Effect}
    (locus : LocusId) (measure : MeasureId)
    (hNot : (⟨locus, measure⟩ : EffectCoordinate) ∉
      effects.map Effect.coordinate) :
    effects.foldr
        (fun effect total =>
          if effect.coordinate = ⟨locus, measure⟩ then
            effect.quantity.quanta + total
          else
            total)
        0 = 0 := by
  induction effects with
  | nil => rfl
  | cons effect rest ih =>
      simp only [List.map_cons, List.mem_cons, not_or] at hNot
      have hHead : effect.coordinate ≠ (⟨locus, measure⟩ : EffectCoordinate) := by
        intro hEq
        exact hNot.1 hEq.symm
      simp [hHead, ih hNot.2]

/--
If an Event does not physically contain a queried coordinate, its quantity
projection there is exact zero.
-/
theorem quantityAt_zero_of_coordinate_not_mem
    (event : Event) (coordinate : EffectCoordinate)
    (hNot : coordinate ∉ eventCoordinates event) :
    Event.quantityAt event coordinate.locus coordinate.measure = 0 := by
  unfold Event.quantityAt
  apply congrArg Quantity.ofQuanta
  simpa [eventCoordinates] using
    quantityFold_zero_of_coordinate_not_mem
      coordinate.locus coordinate.measure hNot

/-- Membership in the deduplicated candidate support is exactly membership in either Event. -/
theorem mem_candidateCoordinates_iff
    (original replacement : Event) (coordinate : EffectCoordinate) :
    coordinate ∈ candidateCoordinates original replacement ↔
      coordinate ∈ eventCoordinates original ∨
      coordinate ∈ eventCoordinates replacement := by
  simp [candidateCoordinates]

/--
Outside the finite union of coordinates represented by original and replacement,
both quantity projections are zero, so the correction delta is zero.
-/
theorem quantityDeltaQuantaAt_zero_of_not_mem_candidateCoordinates
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hNot : coordinate ∉ candidateCoordinates original replacement) :
    quantityDeltaQuantaAt original replacement coordinate = 0 := by
  have hOriginal : coordinate ∉ eventCoordinates original := by
    intro hMem
    apply hNot
    exact (mem_candidateCoordinates_iff original replacement coordinate).2 (Or.inl hMem)
  have hReplacement : coordinate ∉ eventCoordinates replacement := by
    intro hMem
    apply hNot
    exact (mem_candidateCoordinates_iff original replacement coordinate).2 (Or.inr hMem)
  have hBefore := quantityAt_zero_of_coordinate_not_mem original coordinate hOriginal
  have hAfter := quantityAt_zero_of_coordinate_not_mem replacement coordinate hReplacement
  simp [quantityDeltaQuantaAt, Loam.Observation257.quantityDeltaQuanta, hBefore, hAfter]

/--
Completeness law: every nonzero correction quantity change must occur at a
coordinate physically represented by the original Event or the replacement Event.
There are no hidden changed coordinates outside this finite support.
-/
theorem nonzeroDelta_mem_candidateCoordinates
    (original replacement : Event) (coordinate : EffectCoordinate)
    (hNonzero : quantityDeltaQuantaAt original replacement coordinate ≠ 0) :
    coordinate ∈ candidateCoordinates original replacement := by
  by_cases hMem : coordinate ∈ candidateCoordinates original replacement
  · exact hMem
  · exact False.elim <| hNonzero
      (quantityDeltaQuantaAt_zero_of_not_mem_candidateCoordinates
        original replacement coordinate hMem)

/--
Exact finite support of observable quantity change. Filtering is projection-only:
it stores no new truth and does not imply Effect correspondence.
-/
def changedCoordinates (original replacement : Event) : List EffectCoordinate :=
  (candidateCoordinates original replacement).filter
    (fun coordinate => decide (quantityDeltaQuantaAt original replacement coordinate ≠ 0))

/--
A coordinate appears in the finite changed-coordinate list exactly when its
observable correction delta is nonzero.
-/
theorem mem_changedCoordinates_iff_nonzero
    (original replacement : Event) (coordinate : EffectCoordinate) :
    coordinate ∈ changedCoordinates original replacement ↔
      quantityDeltaQuantaAt original replacement coordinate ≠ 0 := by
  constructor
  · intro hMem
    simp only [changedCoordinates, List.mem_filter] at hMem
    exact of_decide_eq_true hMem.2
  · intro hNonzero
    have hCandidate := nonzeroDelta_mem_candidateCoordinates
      original replacement coordinate hNonzero
    simp [changedCoordinates, hCandidate, hNonzero]

/-- A complete diff row is just the O257 before/after/delta projection at one changed coordinate. -/
def completeDiff (original replacement : Event) : List Loam.Observation257.CoordinateDelta :=
  (changedCoordinates original replacement).map
    (fun coordinate =>
      Loam.Observation257.deltaAt
        original replacement coordinate.locus coordinate.measure)

/-! ## Concrete witness: changed, removed, and added coordinates -/

private def originalEventId : EventId := ⟨"o258-original"⟩
private def replacementEventId : EventId := ⟨"o258-replacement"⟩
private def cash : LocusId := ⟨"o258-cash"⟩
private def food : LocusId := ⟨"o258-food"⟩
private def paypay : LocusId := ⟨"o258-paypay"⟩
private def books : LocusId := ⟨"o258-books"⟩
private def unseen : LocusId := ⟨"o258-unseen"⟩
private def yen : MeasureId := ⟨"o258-yen"⟩

private def originalEvent : Event :=
  { id := originalEventId
    effects :=
      [ Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-1000))
      , Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 1000)
      , Effect.ofAnonymousQuantity paypay yen (Quantity.ofQuanta (-50)) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def replacementEvent : Event :=
  { id := replacementEventId
    effects :=
      [ Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-800))
      , Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 800)
      , Effect.ofAnonymousQuantity books yen (Quantity.ofQuanta 200) ]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

/-- Existing coordinates whose quantities change are found. -/
theorem cash_is_changed :
    (⟨cash, yen⟩ : EffectCoordinate) ∈ changedCoordinates originalEvent replacementEvent := by
  rw [mem_changedCoordinates_iff_nonzero]
  simp [quantityDeltaQuantaAt, Loam.Observation257.quantityDeltaQuanta,
    originalEvent, replacementEvent, cash, food, paypay, books, yen,
    Event.quantityAt, Effect.coordinate]

/-- A coordinate removed by the replacement is found because it occurs in the original support. -/
theorem removed_paypay_is_changed :
    (⟨paypay, yen⟩ : EffectCoordinate) ∈ changedCoordinates originalEvent replacementEvent := by
  rw [mem_changedCoordinates_iff_nonzero]
  simp [quantityDeltaQuantaAt, Loam.Observation257.quantityDeltaQuanta,
    originalEvent, replacementEvent, cash, food, paypay, books, yen,
    Event.quantityAt, Effect.coordinate]

/-- A coordinate added by the replacement is found because it occurs in the replacement support. -/
theorem added_books_is_changed :
    (⟨books, yen⟩ : EffectCoordinate) ∈ changedCoordinates originalEvent replacementEvent := by
  rw [mem_changedCoordinates_iff_nonzero]
  simp [quantityDeltaQuantaAt, Loam.Observation257.quantityDeltaQuanta,
    originalEvent, replacementEvent, cash, food, paypay, books, yen,
    Event.quantityAt, Effect.coordinate]

/-- A coordinate present in neither Event cannot appear as a hidden change. -/
theorem unseen_is_not_changed :
    (⟨unseen, yen⟩ : EffectCoordinate) ∉ changedCoordinates originalEvent replacementEvent := by
  intro hMem
  have hNonzero := (mem_changedCoordinates_iff_nonzero
    originalEvent replacementEvent (⟨unseen, yen⟩ : EffectCoordinate)).1 hMem
  apply hNonzero
  simp [quantityDeltaQuantaAt, Loam.Observation257.quantityDeltaQuanta,
    originalEvent, replacementEvent, cash, food, paypay, books, unseen, yen,
    Event.quantityAt, Effect.coordinate]

/-!
Observation boundary:

* every nonzero coordinate-level correction change lies in a finite support
  derived from original and replacement Effects;
* filtering that support yields an exact finite changed-coordinate list;
* added and removed coordinates are covered without cross-Event Effect pairing;
* coordinates represented by neither Event have provably zero delta;
* the result remains a quantity projection and cannot reconstruct Effect lineage,
  causal meaning, chronology, or finer within-coordinate rearrangements.

Therefore a complete observable quantity diff can be derived without retaining a
separate diff authority or cross-Event Effect correspondence.
-/

end Loam.Observation258
