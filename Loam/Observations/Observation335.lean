import Loam.ActualJournalProjection
import Init.Data.List.Sort.Lemmas

namespace Loam.Observation335

set_option autoImplicit false

/-!
# Observation 335 — insertion/merge sort refinement boundary

ActualJournalProjection currently sorts its already-admitted dated current
entries with a left fold of ordered insertion.

R4 asks whether that quadratic-shaped mechanics can be replaced by
List.mergeSort without changing the observable journal order.

This observation isolates the algorithmic theorem from Actual authority:

* both algorithms retain exactly the same input multiset;
* both produce a list ordered by the same total transitive relation;
* therefore they are exactly equal whenever ties inside the selected input are
  observationally antisymmetric, i.e. two selected elements that compare both
  ways are the same element.

That last condition is deliberate. A stable merge sort and the current
"insert-before-on-tie" mechanics need not return the same arbitrary payload list
when distinct elements share one comparison key. Production Actual evidence has
a stronger EventId uniqueness boundary; promotion must bridge that invariant to
this theorem rather than silently assuming arbitrary tie equivalence.
-/

variable {α : Type} (r : α → α → Prop) [DecidableRel r]

private def orderedInsert (a : α) : List α → List α
  | [] => [a]
  | b :: rest =>
      if r a b then
        a :: b :: rest
      else
        b :: orderedInsert r a rest

/-- Exact mechanics shape used by the current journal sorter. -/
def insertionSorted (xs : List α) : List α :=
  xs.foldl (fun acc a => orderedInsert r a acc) []

/-- Merge-sort candidate using exactly the same decidable relation. -/
def mergeSorted (xs : List α) : List α :=
  xs.mergeSort (fun a b => decide (r a b))

private theorem orderedInsert_perm
    (a : α) (xs : List α) :
    orderedInsert r a xs ~ a :: xs := by
  induction xs with
  | nil =>
      simp [orderedInsert]
  | cons b rest ih =>
      simp only [orderedInsert]
      split
      · exact .refl _
      · exact (List.Perm.cons b ih).trans (List.Perm.swap b a rest)

private theorem foldlInsert_perm
    (acc xs : List α) :
    xs.foldl (fun state a => orderedInsert r a state) acc ~ acc ++ xs := by
  induction xs generalizing acc with
  | nil =>
      simp
  | cons a rest ih =>
      simp only [List.foldl_cons]
      calc
        rest.foldl (fun state a => orderedInsert r a state) (orderedInsert r a acc)
            ~ orderedInsert r a acc ++ rest := ih _
        _ ~ (a :: acc) ++ rest :=
          (orderedInsert_perm r a acc).append_right rest
        _ = a :: (acc ++ rest) := by simp
        _ ~ acc ++ a :: rest := List.perm_middle.symm

theorem insertionSorted_perm (xs : List α) :
    insertionSorted r xs ~ xs := by
  simpa [insertionSorted] using foldlInsert_perm r [] xs

private theorem orderedInsert_pairwise
    (htrans : Transitive r)
    (htotal : ∀ a b, r a b ∨ r b a)
    (a : α) (xs : List α)
    (hSorted : xs.Pairwise r) :
    (orderedInsert r a xs).Pairwise r := by
  induction xs with
  | nil =>
      simp [orderedInsert]
  | cons b rest ih =>
      have hParts := List.pairwise_cons.mp hSorted
      simp only [orderedInsert]
      split <;> rename_i hab
      · apply List.pairwise_cons.mpr
        constructor
        · intro c hc
          simp only [List.mem_cons] at hc
          rcases hc with rfl | hc
          · exact hab
          · exact htrans hab (hParts.1 c hc)
        · exact hSorted
      · apply List.pairwise_cons.mpr
        constructor
        · intro c hc
          have hcSource :
              c ∈ a :: rest :=
            (orderedInsert_perm r a rest).mem_iff.mp hc
          simp only [List.mem_cons] at hcSource
          rcases hcSource with rfl | hcRest
          · exact (htotal a b).resolve_left hab
          · exact hParts.1 c hcRest
        · exact ih hParts.2

private theorem foldlInsert_pairwise
    (htrans : Transitive r)
    (htotal : ∀ a b, r a b ∨ r b a)
    (xs acc : List α)
    (hAcc : acc.Pairwise r) :
    (xs.foldl (fun state a => orderedInsert r a state) acc).Pairwise r := by
  induction xs generalizing acc with
  | nil =>
      simpa
  | cons a rest ih =>
      simp only [List.foldl_cons]
      exact ih _ (orderedInsert_pairwise r htrans htotal a acc hAcc)

theorem insertionSorted_pairwise
    (htrans : Transitive r)
    (htotal : ∀ a b, r a b ∨ r b a)
    (xs : List α) :
    (insertionSorted r xs).Pairwise r := by
  exact foldlInsert_pairwise r htrans htotal xs [] (by simp)

theorem mergeSorted_perm (xs : List α) :
    mergeSorted r xs ~ xs := by
  exact List.mergeSort_perm xs (fun a b => decide (r a b))

theorem mergeSorted_pairwise
    (htrans : Transitive r)
    (htotal : ∀ a b, r a b ∨ r b a)
    (xs : List α) :
    (mergeSorted r xs).Pairwise r := by
  have hBool :=
    List.pairwise_mergeSort
      (le := fun a b => decide (r a b))
      (fun a b c hab hbc => by
        simp only [Bool.decide_eq_true] at hab hbc ⊢
        exact htrans hab hbc)
      (fun a b => by
        simp only [Bool.or_eq_true, Bool.decide_eq_true]
        exact htotal a b)
      xs
  simpa [mergeSorted] using hBool

/--
The current insertion-sort mechanics and merge sort are extensionally identical
for every input on which the comparison relation is transitive, total, and has
no distinct two-way-comparing elements inside that input.
-/
theorem insertionSorted_eq_mergeSorted
    (htrans : Transitive r)
    (htotal : ∀ a b, r a b ∨ r b a)
    (xs : List α)
    (hTie :
      ∀ a b,
        a ∈ xs →
        b ∈ xs →
        r a b →
        r b a →
        a = b) :
    insertionSorted r xs = mergeSorted r xs := by
  let pInsertion := insertionSorted_perm r xs
  let pMerge := mergeSorted_perm r xs
  apply List.Perm.eq_of_pairwise (le := r)
  · intro a b ha hb hab hba
    apply hTie a b
    · exact pInsertion.mem_iff.mp ha
    · exact pMerge.mem_iff.mp hb
    · exact hab
    · exact hba
  · exact insertionSorted_pairwise r htrans htotal xs
  · exact mergeSorted_pairwise r htrans htotal xs
  · exact pInsertion.trans pMerge.symm

end Loam.Observation335
