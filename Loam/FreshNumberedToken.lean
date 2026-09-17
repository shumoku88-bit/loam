import Std
import Lean.Elab.Tactic.Omega

namespace Loam

set_option autoImplicit false

/-!
Shares only deterministic `stem ++ Nat` candidate enumeration. Identity
namespace, collision policy, starting index, and typed wrapper stay local.
-/

/--
Return the first numbered token absent from one finite represented namespace.

On collision the selected token is erased before trying the next number, so the
represented namespace strictly shrinks on every recursive call. The operation is
therefore total without a caller-supplied fuel budget or an unreachable `none`.
-/
def firstUnusedNumberedToken
    (stem : String) (used : List String) (index : Nat) : String :=
  let candidate := stem ++ toString index
  if h : candidate ∈ used then
    firstUnusedNumberedToken stem (used.erase candidate) (index + 1)
  else
    candidate
termination_by used.length
decreasing_by
  rw [List.length_erase_of_mem h]
  exact Nat.sub_lt (List.length_pos_of_mem h) (by decide)

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

private theorem result_numbered_at_or_after_of_length
    (stem : String) (n : Nat) :
    ∀ (used : List String), used.length = n → ∀ index : Nat,
      ∃ selectedIndex,
        index ≤ selectedIndex ∧
          firstUnusedNumberedToken stem used index =
            stem ++ toString selectedIndex := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro used hLength index
      rw [firstUnusedNumberedToken]
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
        firstUnusedNumberedToken stem used index =
          stem ++ toString selectedIndex :=
  result_numbered_at_or_after_of_length stem used.length used rfl index

private theorem firstUnusedNumberedToken_not_mem_of_length
    (stem : String) (n : Nat) :
    ∀ (used : List String), used.length = n → ∀ index : Nat,
      firstUnusedNumberedToken stem used index ∉ used := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro used hLength index
      rw [firstUnusedNumberedToken]
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
            firstUnusedNumberedToken
                stem (used.erase (stem ++ toString index)) (index + 1) ≠
              stem ++ toString index := by
          intro hEqual
          rw [hResult] at hEqual
          have hIndexEqual := numberedToken_injective stem hEqual
          omega
        intro hInUsed
        have hInErased :
            firstUnusedNumberedToken
                stem (used.erase (stem ++ toString index)) (index + 1) ∈
              used.erase (stem ++ toString index) :=
          (List.mem_erase_of_ne hNotCurrent).2 hInUsed
        exact hFreshErased hInErased
      next hUnused =>
        exact hUnused

/--
The total numbered allocator always returns a token outside the represented
finite namespace supplied by its caller.
-/
theorem firstUnusedNumberedToken_fresh
    (stem : String) (used : List String) (index : Nat) :
    firstUnusedNumberedToken stem used index ∉ used :=
  firstUnusedNumberedToken_not_mem_of_length stem used.length used rfl index

end Loam
