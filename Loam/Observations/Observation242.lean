import Loam.FreshNumberedToken
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation242

set_option autoImplicit false

/-!
# Observation 242 — bounded numbered identity search is total over finite use

The current production identity allocators share one deterministic mechanic:
`firstUnusedNumberedToken?` scans `stem ++ Nat` candidates and returns `none`
when its finite fuel is exhausted.

Several callers give that search one more candidate than the number of retained
items that can reserve the caller's identity namespace. This observation asks
the smaller mechanical question before changing any publisher:

> If every used token belongs to one finite list of length `n`, can a search
> through more than `n` distinct numbered candidates exhaust its fuel?

The answer is no. This observation does not yet claim that every production
`used?` predicate is represented by the corresponding retained-item list. That
caller-specific qualification remains a separate step.
-/

/-- Observation-local finite membership predicate matching production collision checks. -/
def usedByList (used : List String) (token : String) : Bool :=
  decide (token ∈ used)

/-- The exact candidate window inspected by one bounded numbered search. -/
def numberedWindow (stem : String) (index fuel : Nat) : List String :=
  (List.range' index fuel).map (fun n => stem ++ toString n)

/-- Decimal numbered suffixes make the candidate constructor injective. -/
private theorem numberedToken_injective (stem : String) :
    Function.Injective (fun n : Nat => stem ++ toString n) := by
  intro a b h
  have hLists :
      stem.toList ++ (toString a).toList =
        stem.toList ++ (toString b).toList := by
    simpa using congrArg String.toList h
  have hSuffix : (toString a).toList = (toString b).toList :=
    List.append_left_cancel hLists
  have hDigits : Nat.toDigits 10 a = Nat.toDigits 10 b := by
    simpa only [Nat.toString_eq_repr, Nat.toList_repr] using hSuffix
  have hParsed :=
    congrArg (fun digits => Nat.ofDigitChars 10 digits 0) hDigits
  simpa using hParsed

/-- The bounded candidate window contains no duplicate token. -/
theorem numberedWindow_nodup (stem : String) (index fuel : Nat) :
    (numberedWindow stem index fuel).Nodup := by
  unfold numberedWindow
  exact (List.nodup_range' (s := index) (n := fuel) (step := 1)).map
    (numberedToken_injective stem)

/-- If the search exhausts, every candidate in its numeric window was marked used. -/
private theorem none_implies_used_in_window
    (stem : String)
    (used : List String)
    (index fuel i : Nat)
    (hNone :
      Loam.firstUnusedNumberedToken? stem (usedByList used) index fuel = none)
    (hLow : index ≤ i)
    (hHigh : i < index + fuel) :
    stem ++ toString i ∈ used := by
  induction fuel generalizing index i with
  | zero =>
      omega
  | succ fuel ih =>
      have hHead : stem ++ toString index ∈ used := by
        by_contra hNot
        simp [Loam.firstUnusedNumberedToken?, usedByList, hNot] at hNone
      by_cases hEq : i = index
      · simpa [hEq] using hHead
      · have hTailNone :
          Loam.firstUnusedNumberedToken?
              stem (usedByList used) (index + 1) fuel = none := by
            simpa [Loam.firstUnusedNumberedToken?, usedByList, hHead] using hNone
        exact ih (index := index + 1) (i := i) hTailNone (by omega) (by omega)

/-- Exhaustion would force the entire candidate window into the used-token list. -/
private theorem none_implies_window_subset
    (stem : String)
    (used : List String)
    (index fuel : Nat)
    (hNone :
      Loam.firstUnusedNumberedToken? stem (usedByList used) index fuel = none) :
    numberedWindow stem index fuel ⊆ used := by
  intro token hToken
  rcases List.mem_map.mp hToken with ⟨i, hi, rfl⟩
  have hBounds := List.mem_range'_1.mp hi
  exact none_implies_used_in_window stem used index fuel i hNone hBounds.1 hBounds.2

/--
More distinct numbered candidates than used tokens makes exhaustion impossible.
This is the pigeonhole fact needed by the current `n + 1` allocation pattern.
-/
theorem search_succeeds_when_window_outnumbers_used
    (stem : String)
    (used : List String)
    (index fuel : Nat)
    (hBudget : used.length < fuel) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        stem (usedByList used) index fuel = some token := by
  cases hSearch :
      Loam.firstUnusedNumberedToken? stem (usedByList used) index fuel with
  | some token =>
      exact ⟨token, hSearch⟩
  | none =>
      have hSubset := none_implies_window_subset stem used index fuel hSearch
      have hLengthLe :=
        (numberedWindow_nodup stem index fuel).length_le_of_subset hSubset
      have hWindowLength : (numberedWindow stem index fuel).length = fuel := by
        simp [numberedWindow]
      rw [hWindowLength] at hLengthLe
      omega

/-- The production-shaped `used.length + 1` fuel budget is therefore total. -/
theorem length_plus_one_fuel_is_total
    (stem : String)
    (used : List String)
    (index : Nat) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        stem (usedByList used) index (used.length + 1) = some token := by
  apply search_succeeds_when_window_outnumbers_used
  omega

/-!
Observation 242 earns only the finite-search law:

```text
used identities represented by a finite list of length n
+ n + 1 distinct numbered candidates
-> numbered fresh-token search cannot return none
```

It does not yet remove `Option` from `firstUnusedNumberedToken?`, nor does it
remove any publisher failure branch. Each production caller must first prove
that its collision predicate is covered by a finite witness list no larger than
the fuel budget it supplies.
-/

end Loam.Observations.Observation242
