import Loam.Observations.Observation242
import Loam.Core.OpenRelation
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation248

open Loam.Core

set_option autoImplicit false

/-!
# Observation 248 — Movement RelationUnit allocation is recursively total

Movement admission's remaining numbered-identity path allocates one or more
`relation-` RelationUnitIds. Each step searches against an explicit finite `used`
list with `used.length + 1` candidates, then prepends the newly allocated id to
that list before allocating the next id.

Observation 242 already proves one such finite search cannot exhaust. This
observation asks the stronger production-shaped question: does repeatedly growing
`used` preserve that totality for an arbitrary requested count?
-/

/-- Opaque RelationUnitId tokens represented by the explicit used list. -/
def relationTokens (used : List RelationUnitId) : List String :=
  used.map (fun id => id.token)

@[simp] theorem relationTokens_length (used : List RelationUnitId) :
    (relationTokens used).length = used.length := by
  simp [relationTokens]

/-- Exact collision shape used by Movement's single RelationUnit search. -/
def relationUsedBy (used : List RelationUnitId) (token : String) : Bool :=
  used.any fun candidate => decide (candidate = (⟨token⟩ : RelationUnitId))

/-- The explicit RelationUnit collision predicate is finite token membership. -/
theorem relationUsed_eq_usedByList (used : List RelationUnitId) :
    relationUsedBy used = Observation242.usedByList (relationTokens used) := by
  funext token
  induction used with
  | nil =>
      simp [relationUsedBy, relationTokens, Observation242.usedByList]
  | cons id rest ih =>
      rcases id with ⟨idToken⟩
      by_cases hEq : idToken = token
      · subst token
        simp [relationUsedBy, relationTokens, Observation242.usedByList]
      · have hEqSymm : token ≠ idToken := by
          intro h
          exact hEq h.symm
        simp [relationUsedBy, relationTokens, Observation242.usedByList,
          hEq, hEqSymm, ih]

/-- Every single production-shaped RelationUnit search has a result. -/
theorem relationSearch_is_total
    (used : List RelationUnitId)
    (index : Nat) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "relation-"
        (relationUsedBy used)
        index
        (used.length + 1) = some token := by
  rw [relationUsed_eq_usedByList used]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  simp [relationTokens]

/--
Observation-local mirror of Movement's recursive RelationUnit allocation shape.
It differs only by keeping the raw token search visible instead of wrapping each
single search in the private publisher helper.
-/
def allocateRelationIds? :
    List RelationUnitId → Nat → Nat → Option (List RelationUnitId)
  | _, 0, _ => some []
  | used, remaining + 1, index => do
      let token ← Loam.firstUnusedNumberedToken?
        "relation-"
        (relationUsedBy used)
        index
        (used.length + 1)
      let id : RelationUnitId := ⟨token⟩
      let rest ← allocateRelationIds? (id :: used) remaining (index + 1)
      some (id :: rest)

/--
Growing the used list with each chosen id cannot create an exhaustion case:
each recursive step receives a fresh `used.length + 1` budget for its now-larger
finite collision set.
-/
theorem recursiveRelationAllocation_is_total
    (used : List RelationUnitId)
    (remaining index : Nat) :
    ∃ ids,
      allocateRelationIds? used remaining index = some ids ∧
        ids.length = remaining := by
  induction remaining generalizing used index with
  | zero =>
      exact ⟨[], rfl, rfl⟩
  | succ remaining ih =>
      obtain ⟨token, hToken⟩ := relationSearch_is_total used index
      let id : RelationUnitId := ⟨token⟩
      obtain ⟨rest, hRest, hLength⟩ :=
        ih (used := id :: used) (index := index + 1)
      refine ⟨id :: rest, ?_, ?_⟩
      · simp [allocateRelationIds?, hToken, id, hRest]
      · simp [hLength]

/-!
Observation 248 earns the final current Movement allocation result:

```text
one RelationUnit search:
  used-token count = used.length
  fuel = used.length + 1
  -> cannot return none

repeat for any requested count:
  choose id
  prepend id to used
  repeat with the new used.length + 1 budget
  -> recursive allocation cannot return none
```

Together with Observations 243–247, every current production use of the shared
numbered-token mechanic now has a finite totality argument under its existing
fuel policy. Production remains unchanged here so the later API-compression
choice can be evaluated separately.
-/

end Loam.Observations.Observation248
