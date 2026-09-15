import Std

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

/-- Cancellation needed only to show numbered candidate enumeration is injective. -/
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

/-- Decimal numbered suffixes make `stem ++ Nat` candidate enumeration injective. -/
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

/-- The selected token always comes from the current or a later numbered candidate. -/
theorem firstUnusedNumberedToken_numbered
    (stem : String) (used : List String) (index : Nat) :
    ∃ selected, index ≤ selected ∧
      firstUnusedNumberedToken stem used index = stem ++ toString selected := by
  rw [firstUnusedNumberedToken]
  split
  next h =>
    rcases firstUnusedNumberedToken_numbered
        stem (used.erase (stem ++ toString index)) (index + 1) with
      ⟨selected, hSelected, hToken⟩
    exact ⟨selected, Nat.le_trans (Nat.le_succ index) hSelected, hToken⟩
  next _ =>
    exact ⟨index, Nat.le_refl index, rfl⟩
termination_by used.length
decreasing_by
  rw [List.length_erase_of_mem h]
  exact Nat.sub_lt (List.length_pos_of_mem h) (by decide)

/-- The total allocator's result is absent from the finite namespace it received. -/
theorem firstUnusedNumberedToken_not_mem
    (stem : String) (used : List String) (index : Nat) :
    firstUnusedNumberedToken stem used index ∉ used := by
  rw [firstUnusedNumberedToken]
  split
  next h =>
    have hTail := firstUnusedNumberedToken_not_mem
      stem (used.erase (stem ++ toString index)) (index + 1)
    rcases firstUnusedNumberedToken_numbered
        stem (used.erase (stem ++ toString index)) (index + 1) with
      ⟨selected, hSelected, hToken⟩
    have hNe :
        firstUnusedNumberedToken
            stem (used.erase (stem ++ toString index)) (index + 1) ≠
          stem ++ toString index := by
      rw [hToken]
      intro hEq
      have hIndexEq := numberedToken_injective stem hEq
      subst selected
      exact (Nat.not_succ_le_self index) (by simpa using hSelected)
    intro hMem
    exact hTail ((List.mem_erase_of_ne hNe).2 hMem)
  next h =>
    exact h
termination_by used.length
decreasing_by
  rw [List.length_erase_of_mem h]
  exact Nat.sub_lt (List.length_pos_of_mem h) (by decide)

end Loam
