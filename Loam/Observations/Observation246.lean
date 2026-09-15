import Loam.Observations.Observation242
import Loam.Core.ScheduledMemory

namespace Loam.Observations.Observation246

open Loam.Core

set_option autoImplicit false

/-!
# Observation 246 — Scheduled occurrence allocation is total

Observation 242 proved the finite numbered-search law. This observation connects
that law to the exact Scheduled occurrence allocator.

Scheduled reserves a candidate exactly when one retained occurrence already has
that `ScheduledId`, and the allocator supplies `memory.occurrences.length + 1`
candidates. Therefore the current bounded search cannot return `none`.
-/

/-- Retained Scheduled identity tokens, one per occurrence. -/
def scheduledTokens
    (occurrences : List (ScheduledOccurrence String)) : List String :=
  occurrences.map (fun occurrence => occurrence.id.token)

/-- The witness list has exactly one token per retained occurrence. -/
theorem scheduledTokens_length
    (occurrences : List (ScheduledOccurrence String)) :
    (scheduledTokens occurrences).length = occurrences.length := by
  simp [scheduledTokens]

/-- Scheduled keyed lookup is exactly membership in the finite token witness. -/
private theorem findScheduled_isSome_eq_usedByList
    (occurrences : List (ScheduledOccurrence String))
    (token : String) :
    (FiniteKeyed.findBy?
        ScheduledOccurrence.id
        occurrences
        (⟨token⟩ : ScheduledId)).isSome =
      Observation242.usedByList (scheduledTokens occurrences) token := by
  induction occurrences with
  | nil =>
      simp [FiniteKeyed.findBy?, scheduledTokens, Observation242.usedByList]
  | cons occurrence rest ih =>
      rcases occurrence with ⟨id, scheduledOn, movement⟩
      rcases id with ⟨idToken⟩
      by_cases hEq : idToken = token
      · subst token
        simp [FiniteKeyed.findBy?, scheduledTokens, Observation242.usedByList]
      · have hNe : token ≠ idToken := by
          intro h
          exact hEq h.symm
        simp [FiniteKeyed.findBy?, scheduledTokens, hEq, hNe, ih,
          Observation242.usedByList]

/-- The production Scheduled collision predicate has the finite witness above. -/
theorem scheduledUsed_eq_usedByList
    (memory : ScheduledMemory String) :
    (fun token =>
      (ScheduledMemory.findById? memory (⟨token⟩ : ScheduledId)).isSome) =
      Observation242.usedByList (scheduledTokens memory.occurrences) := by
  funext token
  simpa [ScheduledMemory.findById?] using
    findScheduled_isSome_eq_usedByList memory.occurrences token

/-- The exact Scheduled fresh-id search cannot exhaust its current fuel. -/
theorem scheduledSearch_is_total
    (memory : ScheduledMemory String) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "scheduled-"
        (fun token =>
          (ScheduledMemory.findById? memory (⟨token⟩ : ScheduledId)).isSome)
        1
        (memory.occurrences.length + 1) = some token := by
  rw [scheduledUsed_eq_usedByList memory]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  simpa [scheduledTokens]

/-!
Observation 246 therefore earns:

```text
Scheduled collision namespace = retained occurrence ids
used-token count = occurrences.length
fuel = occurrences.length + 1
-> fresh Scheduled identity search cannot return none
```

No production API change is made here.
-/

end Loam.Observations.Observation246
