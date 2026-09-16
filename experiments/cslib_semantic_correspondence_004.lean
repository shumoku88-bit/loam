import Loam.FreshNumberedToken
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.CSLibSemanticCorrespondence004

set_option autoImplicit false

/-!
CSA-004 asks whether LOAM's deterministic numbered-token allocator satisfies the
semantic contract exposed by CSLib `HasFresh`: given a finite represented
namespace, return an element outside that namespace.

No CSLib or Mathlib dependency is added. The experiment proves the contract
directly for production `firstUnusedNumberedToken`, while preserving LOAM's
stronger deterministic policy: choose the first available `stem ++ Nat`
candidate at or after the requested index.
-/

/-- Observation 242's small cancellation lemma, retained here only as proof glue. -/
private theorem listAppendLeftCancel
    {α : Type}
    (xs ys zs : List α)
    (h : xs ++ ys = xs ++ zs) :
    ys = zs := by
  induction xs with
  | nil =>
      simpa using h
  | cons head tail ih =>
      apply ih
      simpa using h

/-- Decimal numbered suffixes make the candidate constructor injective. -/
private theorem numberedToken_injective (stem : String) :
    Function.Injective (fun n : Nat => stem ++ toString n) := by
  intro a b h
  have hLists :
      stem.toList ++ (toString a).toList =
        stem.toList ++ (toString b).toList := by
    simpa using congrArg String.toList h
  have hSuffix : (toString a).toList = (toString b).toList :=
    listAppendLeftCancel stem.toList (toString a).toList (toString b).toList hLists
  have hDigits : Nat.toDigits 10 a = Nat.toDigits 10 b := by
    simpa only [Nat.toString_eq_repr, Nat.toList_repr] using hSuffix
  have hParsed :=
    congrArg (fun digits => Nat.ofDigitChars 10 digits 0) hDigits
  simpa using hParsed

/--
The production allocator always returns a numbered token at or after its input
index. This is the ordering fact needed to show that recursive allocation cannot
return a candidate erased at an earlier step.
-/
private theorem result_numbered_at_or_after_of_length
    (stem : String) (n : Nat) :
    ∀ (used : List String), used.length = n → ∀ index : Nat,
      ∃ selectedIndex,
        index ≤ selectedIndex ∧
          Loam.firstUnusedNumberedToken stem used index =
            stem ++ toString selectedIndex := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro used hLength index
      rw [Loam.firstUnusedNumberedToken]
      split
      next hUsed =>
        have hPositive : 0 < n := by
          rw [← hLength]
          exact List.length_pos_of_mem hUsed
        have hEraseLt :
            (used.erase (stem ++ toString index)).length < n := by
          rw [List.length_erase_of_mem hUsed, hLength]
          omega
        rcases
            ih (used.erase (stem ++ toString index)).length hEraseLt
              (used.erase (stem ++ toString index)) rfl (index + 1) with
          ⟨selectedIndex, hSelected, hResult⟩
        exact ⟨selectedIndex, by omega, hResult⟩
      next hUnused =>
        exact ⟨index, Nat.le_refl index, rfl⟩

private theorem result_numbered_at_or_after
    (stem : String) (used : List String) (index : Nat) :
    ∃ selectedIndex,
      index ≤ selectedIndex ∧
        Loam.firstUnusedNumberedToken stem used index =
          stem ++ toString selectedIndex :=
  result_numbered_at_or_after_of_length stem used.length used rfl index

/--
Core HasFresh-style contract: the total production allocator returns a token not
present in the original finite namespace.
-/
private theorem firstUnusedNumberedToken_not_mem_of_length
    (stem : String) (n : Nat) :
    ∀ (used : List String), used.length = n → ∀ index : Nat,
      Loam.firstUnusedNumberedToken stem used index ∉ used := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro used hLength index
      rw [Loam.firstUnusedNumberedToken]
      split
      next hUsed =>
        have hPositive : 0 < n := by
          rw [← hLength]
          exact List.length_pos_of_mem hUsed
        have hEraseLt :
            (used.erase (stem ++ toString index)).length < n := by
          rw [List.length_erase_of_mem hUsed, hLength]
          omega
        have hFreshErased :=
          ih (used.erase (stem ++ toString index)).length hEraseLt
            (used.erase (stem ++ toString index)) rfl (index + 1)
        rcases
            result_numbered_at_or_after
              stem (used.erase (stem ++ toString index)) (index + 1) with
          ⟨selectedIndex, hSelected, hResult⟩
        have hNotCurrent :
            Loam.firstUnusedNumberedToken
                stem (used.erase (stem ++ toString index)) (index + 1) ≠
              stem ++ toString index := by
          intro hEqual
          rw [hResult] at hEqual
          have hIndexEqual := numberedToken_injective stem hEqual
          omega
        intro hInUsed
        have hInErased :
            Loam.firstUnusedNumberedToken
                stem (used.erase (stem ++ toString index)) (index + 1) ∈
              used.erase (stem ++ toString index) :=
          (List.mem_erase_of_ne hNotCurrent).2 hInUsed
        exact hFreshErased hInErased
      next hUnused =>
        exact hUnused

/--
LOAM's deterministic numbered allocator satisfies CSLib `HasFresh`'s essential
freshness law for every finite represented namespace.
-/
theorem firstUnusedNumberedToken_fresh
    (stem : String) (used : List String) (index : Nat) :
    Loam.firstUnusedNumberedToken stem used index ∉ used :=
  firstUnusedNumberedToken_not_mem_of_length stem used.length used rfl index

/-- A concrete sanity witness for the standard contract. -/
example :
    Loam.firstUnusedNumberedToken
        "record-" ["record-1", "record-2", "record-4"] 1 = "record-3" := by
  native_decide

end Loam.Experiments.CSLibSemanticCorrespondence004
