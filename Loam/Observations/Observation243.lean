import Loam.Observations.Observation242
import Loam.Core.ActualValidityHistory
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation243

open Loam.Core

set_option autoImplicit false

/-!
# Observation 243 — Actual-validity revision allocation is total

Observation 242 proved the shared finite-search law: if a bounded numbered-token
search inspects more distinct candidates than a finite used-token witness can
contain, the search cannot return `none`.

This observation connects that mechanical result to the first production caller:
Actual-validity date revision identity.

The current Date Revision allocator regards a token as used exactly when a
retained validity fact carries the corresponding revision reference, and gives
the search `history.facts.length + 1` candidates. Base facts reserve no revision
token. Therefore the concrete used namespace is represented by a list no longer
than `history.facts`, and the bounded search is total even for raw history.

No Application frontier or admitted-history premise is required.
-/

/-- Revision tokens retained by the raw validity facts; base facts reserve none. -/
def revisionTokens : List (ActualValidityFact String) → List String
  | [] => []
  | .base _ _ :: rest => revisionTokens rest
  | .revision id _ _ :: rest => id.token :: revisionTokens rest

/-- Extracting only revision tokens never creates more identities than facts. -/
theorem revisionTokens_length_le (facts : List (ActualValidityFact String)) :
    (revisionTokens facts).length ≤ facts.length := by
  induction facts with
  | nil =>
      simp [revisionTokens]
  | cons fact rest ih =>
      cases fact with
      | base event validOn =>
          simp [revisionTokens]
          omega
      | revision id event validOn =>
          simp [revisionTokens]
          omega

/--
The concrete raw-history lookup used by Date Revision is exactly membership in
the finite revision-token witness.
-/
private theorem findRevision_isSome_eq_usedByList
    (facts : List (ActualValidityFact String))
    (token : String) :
    (FiniteKeyed.findBy?
        ActualValidityFact.ref
        facts
        (.revision (⟨token⟩ : ActualValidityRevisionId))).isSome =
      Observation242.usedByList (revisionTokens facts) token := by
  induction facts with
  | nil =>
      simp [FiniteKeyed.findBy?, revisionTokens, Observation242.usedByList]
  | cons fact rest ih =>
      cases fact with
      | base event validOn =>
          simp [FiniteKeyed.findBy?, ActualValidityFact.ref, revisionTokens, ih,
            Observation242.usedByList]
          rfl
      | revision id event validOn =>
          rcases id with ⟨idToken⟩
          by_cases hEq : idToken = token
          · subst token
            simp [FiniteKeyed.findBy?, ActualValidityFact.ref, revisionTokens,
              Observation242.usedByList]
          · have hEqSymm : token ≠ idToken := by
              intro h
              exact hEq h.symm
            simp [FiniteKeyed.findBy?, ActualValidityFact.ref, revisionTokens, hEq,
              hEqSymm, ih, Observation242.usedByList]

/-- The publisher's collision predicate has the finite witness above. -/
theorem revisionUsed_eq_usedByList
    (history : ActualValidityHistory String) :
    (fun token =>
      (history.findFactByRef?
        (.revision (⟨token⟩ : ActualValidityRevisionId))).isSome) =
      Observation242.usedByList (revisionTokens history.facts) := by
  funext token
  exact findRevision_isSome_eq_usedByList history.facts token

/--
The exact Date Revision search shape cannot exhaust its current fuel budget.
This is stronger than an admitted-production claim: it holds for every raw
`ActualValidityHistory` satisfying only its Core constructor fields.
-/
theorem dateRevisionSearch_is_total
    (history : ActualValidityHistory String) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "validity-"
        (fun token =>
          (history.findFactByRef?
            (.revision (⟨token⟩ : ActualValidityRevisionId))).isSome)
        1
        (history.facts.length + 1) = some token := by
  rw [revisionUsed_eq_usedByList history]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  have hLength := revisionTokens_length_le history.facts
  omega

/-!
Observation 243 therefore earns the caller-specific result:

```text
Date Revision collision namespace = retained revision facts
revision-token count ≤ facts.length
fuel = facts.length + 1
-> fresh revision identity search cannot return none
```

The current publisher's `could not generate a fresh occurrence-date revision
identity` branch is therefore unreachable by this allocation law. This
observation still makes no production API change; how the proof should graduate
without making production source heavier remains a separate compression choice.
-/

end Loam.Observations.Observation243
