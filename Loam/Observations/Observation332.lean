import Loam.Observations.Observation325
import Loam.StockFlowReview
import Std.Data.HashMap.Lemmas

namespace Loam.Observation332

open Loam.Core

set_option autoImplicit false

/-!
# Observation 332 — Stock-Flow selected-coordinate support is set-like

StockFlowReview currently carries selected coordinates as a List and asks, for
every Effect in every inspected Event:

    effect.coordinate ∈ coordinates

The numeric meaning does not observe coordinate order or multiplicity at this
boundary. This observation asks whether that membership predicate factors
through a transient finite key set without changing tracked Event quantity.

The concrete support image is a HashMap from the exact coordinate token pair to
Unit. It is research-only and carries no authority.
-/

private abbrev CoordinateKey := Loam.Observation325.CoordinateKey
abbrev SupportIndex := Std.HashMap CoordinateKey Unit

def buildSupport : List EffectCoordinate → SupportIndex
  | [] => {}
  | coordinate :: rest =>
      (buildSupport rest).insert
        (Loam.Observation325.coordinateKey coordinate) ()

/--
The transient support index contains exactly the coordinates represented by the
source List. Order and duplicate multiplicity are deliberately absent.
-/
theorem buildSupport_contains_eq_mem
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) :
    (buildSupport coordinates).contains
        (Loam.Observation325.coordinateKey coordinate) =
      decide (coordinate ∈ coordinates) := by
  induction coordinates with
  | nil =>
      simp [buildSupport]
  | cons head rest ih =>
      simp only [buildSupport, List.mem_cons]
      rw [Std.HashMap.contains_insert]
      by_cases hCoordinate : head = coordinate
      · subst coordinate
        simp
      · have hKey :
            Loam.Observation325.coordinateKey head ≠
              Loam.Observation325.coordinateKey coordinate := by
          intro h
          exact hCoordinate
            (Loam.Observation325.coordinateKey_injective h)
        have hBeq :
            (Loam.Observation325.coordinateKey head ==
              Loam.Observation325.coordinateKey coordinate) = false := by
          cases h :
              (Loam.Observation325.coordinateKey head ==
                Loam.Observation325.coordinateKey coordinate) with
          | false => rfl
          | true =>
              have hEq :
                  Loam.Observation325.coordinateKey head =
                    Loam.Observation325.coordinateKey coordinate :=
                eq_of_beq h
              exact False.elim (hKey hEq)
        rw [hBeq]
        have hCoordinateRev : coordinate ≠ head := by
          intro h
          exact hCoordinate h.symm
        simp [hCoordinate, hCoordinateRev, ih]

def trackedQuantaList
    (coordinates : List EffectCoordinate)
    (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ coordinates then
        total + effect.quantity.quanta
      else
        total)
    0

def trackedQuantaSupport
    (support : SupportIndex)
    (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if support.contains
          (Loam.Observation325.coordinateKey effect.coordinate) = true then
        total + effect.quantity.quanta
      else
        total)
    0

private theorem fold_support_eq_list
    (coordinates : List EffectCoordinate)
    (effects : List Effect)
    (initial : Int) :
    effects.foldl
        (fun total effect =>
          if (buildSupport coordinates).contains
              (Loam.Observation325.coordinateKey effect.coordinate) = true then
            total + effect.quantity.quanta
          else
            total)
        initial =
      effects.foldl
        (fun total effect =>
          if effect.coordinate ∈ coordinates then
            total + effect.quantity.quanta
          else
            total)
        initial := by
  induction effects generalizing initial with
  | nil =>
      rfl
  | cons effect rest ih =>
      simp only [List.foldl_cons]
      have hSupport :=
        buildSupport_contains_eq_mem coordinates effect.coordinate
      by_cases hMem : effect.coordinate ∈ coordinates
      · have hContains :
            (buildSupport coordinates).contains
                (Loam.Observation325.coordinateKey effect.coordinate) = true := by
          rw [hSupport]
          simp [hMem]
        simp [hContains, hMem]
        exact ih (initial + effect.quantity.quanta)
      · have hContains :
            (buildSupport coordinates).contains
                (Loam.Observation325.coordinateKey effect.coordinate) = false := by
          rw [hSupport]
          simp [hMem]
        simp [hContains, hMem]
        exact ih initial

/--
For every coordinate List and Event, finite-set membership produces exactly the
same selected Event quantity as the current List-membership fold.
-/
theorem trackedQuanta_support_eq_list
    (coordinates : List EffectCoordinate)
    (event : Event) :
    trackedQuantaSupport (buildSupport coordinates) event =
      trackedQuantaList coordinates event := by
  unfold trackedQuantaSupport trackedQuantaList
  exact fold_support_eq_list coordinates event.effects 0

/--
Duplicate selected coordinates carry no additional numeric meaning at the
Stock-Flow Event-selection boundary.
-/
theorem trackedQuantaList_eraseDups
    (coordinates : List EffectCoordinate)
    (event : Event) :
    trackedQuantaList coordinates.eraseDups event =
      trackedQuantaList coordinates event := by
  unfold trackedQuantaList
  induction event.effects generalizing coordinates with
  | nil =>
      rfl
  | cons effect rest ih =>
      simp only [List.foldl_cons]
      have hMem :
          (effect.coordinate ∈ coordinates.eraseDups) ↔
            effect.coordinate ∈ coordinates := by
        simp
      by_cases h : effect.coordinate ∈ coordinates
      · have hDup : effect.coordinate ∈ coordinates.eraseDups := hMem.mpr h
        simp [h, hDup, ih]
      · have hDup : effect.coordinate ∉ coordinates.eraseDups := by
          intro hIn
          exact h (hMem.mp hIn)
        simp [h, hDup, ih]

/-!
## Finding

The selected-coordinate input to Stock-Flow's Event-local quantity calculation
is observationally a finite set.

For the quantity fold:

    List EffectCoordinate
        -> repeated membership tests
        -> tracked Event quantity

can factor through:

    List EffectCoordinate
        -> transient CoordinateKey support index
        -> tracked Event quantity

without changing the result for any Event.

Therefore coordinate order and duplicate multiplicity are not independent
semantic information at this inner Stock-Flow boundary.

This is separate from Observations 322–323:

- 322/323 compress repeated Record traversals into one fail-closed scan;
- 332 compresses the selected-coordinate membership representation used inside
  that scan.

The next empirical question should measure three shapes separately:

1. current production: validation + three numeric passes + List membership;
2. fused Record scan + List membership;
3. fused Record scan + transient support-index membership.

That separation will show whether the practical gain comes from scan fusion,
membership compression, or both.

No production optimization is authorized by this observation.
-/

end Loam.Observation332
