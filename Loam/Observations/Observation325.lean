import Loam.TransactionsFlowReview
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

namespace Loam.Observation325

open Loam.Core

set_option autoImplicit false

/-!
# Observation 325 — General sparse incidence HashMap correspondence

Observation 321 proved the arithmetic meaning of one Event/coordinate cell.
This observation chooses a concrete transient representation and asks whether
its lookups preserve that meaning for arbitrary Events and Snapshots.

The chosen hash key is the exact pair of retained coordinate tokens:

    (LocusId.token, MeasureId.token)

No string concatenation or display label is used.

The representation is research-only and carries no authority.
-/

abbrev CoordinateKey := String × String
abbrev CellIndex := Std.HashMap CoordinateKey Int
private abbrev ColumnIndex := Std.HashMap String CellIndex

def coordinateKey (coordinate : EffectCoordinate) : CoordinateKey :=
  (coordinate.locus.token, coordinate.measure.token)

private theorem coordinateKey_injective :
    Function.Injective coordinateKey := by
  intro left right h
  cases left with
  | mk leftLocus leftMeasure =>
      cases right with
      | mk rightLocus rightMeasure =>
          cases leftLocus with
          | mk leftLocusToken =>
              cases rightLocus with
              | mk rightLocusToken =>
                  cases leftMeasure with
                  | mk leftMeasureToken =>
                      cases rightMeasure with
                      | mk rightMeasureToken =>
                          simp [coordinateKey] at h
                          rcases h with ⟨hLocus, hMeasure⟩
                          subst rightLocusToken
                          subst rightMeasureToken
                          rfl

private theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

/--
Build one Event-local sparse coordinate index.

Tail-first construction makes the lookup proof align directly with the
right-fold semantics of Event.quantityAt. Every encountered coordinate is
inserted even when repeated quantities later sum to zero.
-/
def buildCellIndex : List Effect → CellIndex
  | [] => {}
  | effect :: rest =>
      let index := buildCellIndex rest
      let key := coordinateKey effect.coordinate
      let prior := (index.get? key).getD 0
      index.insert key (effect.quantity.quanta + prior)

/--
For every Effect list and coordinate, HashMap lookup is exactly the direct
coordinate fold used by Event.quantityAt.
-/
private theorem buildCellIndex_getD_eq_fold
    (effects : List Effect)
    (coordinate : EffectCoordinate) :
    ((buildCellIndex effects).get? (coordinateKey coordinate)).getD 0 =
      effects.foldr
        (fun effect total =>
          if effect.coordinate = coordinate then
            effect.quantity.quanta + total
          else
            total)
        0 := by
  induction effects with
  | nil =>
      simp [buildCellIndex]
  | cons effect rest ih =>
      simp only [buildCellIndex, List.foldr_cons]
      rw [Std.HashMap.get?_insert]
      by_cases hCoordinate : effect.coordinate = coordinate
      · subst coordinate
        simp
        exact ih
      · have hKey :
            coordinateKey effect.coordinate ≠ coordinateKey coordinate := by
          intro h
          exact hCoordinate (coordinateKey_injective h)
        simp [hKey, hCoordinate]
        exact ih

/--
A coordinate key is present exactly when that coordinate appeared in at least
one raw Effect, regardless of the final summed value.
-/
theorem buildCellIndex_contains_eq_any
    (effects : List Effect)
    (coordinate : EffectCoordinate) :
    (buildCellIndex effects).contains (coordinateKey coordinate) =
      effects.any (fun effect => decide (effect.coordinate = coordinate)) := by
  induction effects with
  | nil =>
      simp [buildCellIndex]
  | cons effect rest ih =>
      simp only [buildCellIndex, List.any_cons]
      rw [Std.HashMap.contains_insert]
      by_cases hCoordinate : effect.coordinate = coordinate
      · subst coordinate
        simp
      · have hKey :
            coordinateKey effect.coordinate ≠ coordinateKey coordinate := by
          intro h
          exact hCoordinate (coordinateKey_injective h)
        have hBeq :
            (coordinateKey effect.coordinate == coordinateKey coordinate) = false := by
          cases hEq :
              (coordinateKey effect.coordinate == coordinateKey coordinate) with
          | false => rfl
          | true =>
              have :
                  coordinateKey effect.coordinate = coordinateKey coordinate :=
                eq_of_beq hEq
              exact False.elim (hKey this)
        rw [hBeq]
        simp [hCoordinate, ih]

/--
Concrete sparse-cell lookup equals Event.quantityAt for every Event and exact
coordinate.
-/
theorem buildCellIndex_getD_eq_quantityAt
    (event : Event)
    (coordinate : EffectCoordinate) :
    ((buildCellIndex event.effects).get?
      (coordinateKey coordinate)).getD 0 =
      (Event.quantityAt
        event coordinate.locus coordinate.measure).quanta := by
  cases coordinate with
  | mk locus measure =>
      simpa [Event.quantityAt] using
        buildCellIndex_getD_eq_fold event.effects ⟨locus, measure⟩

/--
If a coordinate appears in raw Event evidence, the sparse index retains the key
even when the exact summed cell quantity is zero.
-/
theorem represented_coordinate_key_survives_zero_sum
    (event : Event)
    (coordinate : EffectCoordinate)
    (hAppears :
      event.effects.any
        (fun effect => decide (effect.coordinate = coordinate)) = true) :
    (buildCellIndex event.effects).contains
      (coordinateKey coordinate) = true := by
  rw [buildCellIndex_contains_eq_any]
  exact hAppears

/-! ## Column-level sparse incidence index -/

/--
Build a transient EventId-keyed index of Event-local cell maps.

Tail-first insertion preserves the first matching Column semantics of
TransactionsFlowReview.cellAt even if an arbitrary research Snapshot contains
duplicate EventIds.
-/
private def buildColumnIndex :
    List Loam.TransactionsFlowReview.Column → ColumnIndex
  | [] => {}
  | column :: rest =>
      (buildColumnIndex rest).insert
        column.event.id.token
        (buildCellIndex column.event.effects)

private def directCellIndex?
    (columns : List Loam.TransactionsFlowReview.Column)
    (eventId : EventId) : Option CellIndex :=
  (columns.find? fun column => decide (column.event.id = eventId)).map
    (fun column => buildCellIndex column.event.effects)

/--
The EventId-keyed transient index preserves current first-match column lookup.
-/
theorem buildColumnIndex_get?_eq_direct
    (columns : List Loam.TransactionsFlowReview.Column)
    (eventId : EventId) :
    (buildColumnIndex columns).get? eventId.token =
      directCellIndex? columns eventId := by
  induction columns with
  | nil =>
      simp [buildColumnIndex, directCellIndex?]
  | cons column rest ih =>
      simp only [buildColumnIndex, directCellIndex?, List.find?_cons]
      rw [Std.HashMap.get?_insert]
      by_cases hId : column.event.id = eventId
      · subst eventId
        simp
      · have hToken : column.event.id.token ≠ eventId.token := by
          intro h
          exact hId (eventIdToken_injective h)
        simp [hToken, hId]
        exact ih

private def sparseCellAt
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (eventId : EventId) : Option Quantity := do
  let cells ← (buildColumnIndex snapshot.columns).get? eventId.token
  some <| Quantity.ofQuanta <|
    (cells.get? (coordinateKey coordinate)).getD 0

/--
For every Snapshot, coordinate, and EventId, concrete two-level HashMap lookup is
extensionally equal to production TransactionsFlowReview.cellAt.
-/
theorem sparseCellAt_eq_cellAt
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (eventId : EventId) :
    sparseCellAt snapshot coordinate eventId =
      Loam.TransactionsFlowReview.cellAt snapshot coordinate eventId := by
  unfold sparseCellAt Loam.TransactionsFlowReview.cellAt
  rw [buildColumnIndex_get?_eq_direct]
  unfold directCellIndex?
  cases hColumn :
      snapshot.columns.find?
        (fun candidate => decide (candidate.event.id = eventId)) with
  | none =>
      simp [hColumn]
  | some column =>
      simp [hColumn]
      have hCell :=
        buildCellIndex_getD_eq_quantityAt column.event coordinate
      calc
        Quantity.ofQuanta
            (((buildCellIndex column.event.effects).get?
              (coordinateKey coordinate)).getD 0) =
          Quantity.ofQuanta
            (Event.quantityAt
              column.event coordinate.locus coordinate.measure).quanta :=
            congrArg Quantity.ofQuanta hCell
        _ =
          Event.quantityAt
            column.event coordinate.locus coordinate.measure :=
            Quantity.ofQuanta_quanta _

/-!
## Finding

The Event x EffectCoordinate sparse incidence representation is now concrete and
general:

    EventId token
      -> HashMap (Locus token, Measure token) Int

and its lookup is extensionally equal to current cellAt semantics for arbitrary
Snapshots.

Two separate facts are preserved:

1. value correspondence:
       cell index value = Event.quantityAt
2. representation correspondence:
       raw coordinate occurrence = HashMap key presence

The second law is why exact same-Event cancellation does not erase the
represented coordinate merely because its numeric cell becomes zero.

This observation still does not build the global coordinate -> RowActivity
HashMap. That is the remaining second-stage representation question.

No production code or authority is changed.
-/

end Loam.Observation325
