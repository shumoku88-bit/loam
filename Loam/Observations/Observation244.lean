import Loam.Observations.Observation242
import Loam.Core.EventMemory
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation244

open Loam.Core

set_option autoImplicit false

/-!
# Observation 244 — Correction replacement EventId allocation is total

Observation 242 proved the shared finite-search law for numbered identities.
Observation 243 connected it to Actual-validity revision IDs. This observation
checks a second independent production caller: Correction replacement EventId.

The current Correction allocator marks a token used exactly when `EventMemory`
contains an Event with that `EventId`, and supplies `events.length + 1` search
candidates. Every retained Event contributes exactly one EventId token, so the
finite witness has exactly the same length as the represented Event list.
-/

/-- Event identity tokens represented by one raw Event list. -/
def eventTokens (events : List Event) : List String :=
  events.map (fun event => event.id.token)

@[simp] theorem eventTokens_length (events : List Event) :
    (eventTokens events).length = events.length := by
  simp [eventTokens]

/--
The EventMemory identity lookup used by Correction is exactly membership in the
finite Event-token witness.
-/
private theorem findEvent_isSome_eq_usedByList
    (events : List Event)
    (token : String) :
    (FiniteKeyed.findBy? Event.id events (⟨token⟩ : EventId)).isSome =
      Observation242.usedByList (eventTokens events) token := by
  induction events with
  | nil =>
      simp [FiniteKeyed.findBy?, eventTokens, Observation242.usedByList]
  | cons event rest ih =>
      cases event with
      | mk id effects keyNodup =>
          by_cases hEq : id.token = token
          · have hId : id = (⟨token⟩ : EventId) := by
              cases id with
              | mk idToken =>
                  cases hEq
                  rfl
            simp [FiniteKeyed.findBy?, eventTokens, Observation242.usedByList, hId]
          · have hEqSymm : token ≠ id.token := by
              intro h
              exact hEq h.symm
            have hId : id ≠ (⟨token⟩ : EventId) := by
              intro h
              apply hEq
              exact congrArg EventId.token h
            simp [FiniteKeyed.findBy?, eventTokens, Observation242.usedByList,
              hEqSymm, hId, ih]

/-- Correction's concrete Event collision predicate has the finite witness above. -/
theorem eventUsed_eq_usedByList
    (memory : EventMemory) :
    (fun token =>
      (EventMemory.findById? memory (⟨token⟩ : EventId)).isSome) =
      Observation242.usedByList (eventTokens memory.events) := by
  funext token
  exact findEvent_isSome_eq_usedByList memory.events token

/--
The exact Correction replacement search shape cannot exhaust its current fuel
budget for any admitted `EventMemory`.
-/
theorem correctionReplacementSearch_is_total
    (memory : EventMemory) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "replacement-"
        (fun token =>
          (EventMemory.findById? memory (⟨token⟩ : EventId)).isSome)
        1
        (memory.events.length + 1) = some token := by
  rw [eventUsed_eq_usedByList memory]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  simp [eventTokens]

/-!
Observation 244 earns a second independent caller-specific result:

```text
Correction replacement collision namespace = retained EventIds
used-token count = events.length
fuel = events.length + 1
-> fresh replacement EventId search cannot return none
```

Together with Observation 243, this is independent pressure that the shared
numbered-token mechanic is total under the current `n + 1` production pattern.
No production API is changed here.
-/

end Loam.Observations.Observation244
