import Loam.Application.ReplacementFrontier
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.CSLibSemanticCorrespondence001

set_option autoImplicit false

open Loam.Application.ReplacementFrontier

/--
The ordinary binary relation represented by a finite ReplacementFrontier edge list.

CSLib 0.1.0 defines `Relation.Acyclic r` as irreflexivity of the transitive
closure `Relation.TransGen r`. Lean itself already provides `Relation.TransGen`
and `Std.Irrefl`, so this shadow probe can use exactly that semantic right-hand
side without adding CSLib or Mathlib as a LOAM dependency.
-/
def edgeRel {Id : Type} (edges : List (Edge Id)) : Id → Id → Prop :=
  fun source successor =>
    ∃ edge, edge ∈ edges ∧ edge.source = source ∧ edge.successor = successor

/-- Dependency-free shadow of CSLib's relation-level acyclicity meaning. -/
abbrev StandardAcyclic {Id : Type} (edges : List (Edge Id)) : Prop :=
  Std.Irrefl (Relation.TransGen (edgeRel edges))

/-- A normal admitted-shape example: one finite path. -/
def simplePath : List (Edge Nat) :=
  [ { source := 0, successor := 1 }
  , { source := 1, successor := 2 }
  ]

example : endpointUnique simplePath = true := by
  native_decide

example : acyclic simplePath = true := by
  native_decide

private theorem simplePath_rel_iff (source successor : Nat) :
    edgeRel simplePath source successor ↔
      (source = 0 ∧ successor = 1) ∨
      (source = 1 ∧ successor = 2) := by
  simp [edgeRel, simplePath, eq_comm]

private theorem simplePath_rel_lt {source successor : Nat}
    (h : edgeRel simplePath source successor) :
    source < successor := by
  rw [simplePath_rel_iff] at h
  omega

/-- The standard transitive-closure meaning agrees with the executable checker here. -/
theorem simplePath_standardAcyclic : StandardAcyclic simplePath := by
  refine ⟨?_⟩
  intro start hCycle
  have transLt : ∀ {source successor : Nat},
      Relation.TransGen (edgeRel simplePath) source successor →
        source < successor := by
    intro source successor h
    induction h with
    | single hStep =>
        exact simplePath_rel_lt hStep
    | tail _ hStep ih =>
        exact Nat.lt_trans ih (simplePath_rel_lt hStep)
  exact Nat.lt_irrefl start (transLt hCycle)

/-- A genuine admitted-shape cycle: both views reject it. -/
def singletonCycle : List (Edge Nat) :=
  [{ source := 0, successor := 0 }]

example : endpointUnique singletonCycle = true := by
  native_decide

example : acyclic singletonCycle = false := by
  native_decide

theorem singletonCycle_not_standardAcyclic :
    ¬ StandardAcyclic singletonCycle := by
  intro hAcyclic
  have hLoop : edgeRel singletonCycle 0 0 := by
    simp [edgeRel, singletonCycle]
  exact hAcyclic.irrefl 0 (Relation.TransGen.single hLoop)

/--
Counterexample to an unconditional correspondence theorem.

`ReplacementFrontier.acyclic` follows the first matching successor for a source.
With duplicate sources it can therefore miss a represented relation edge. This
shape is outside production admission because `endpointUnique` rejects it.
-/
def duplicateSourceBlindSpot : List (Edge Nat) :=
  [ { source := 0, successor := 1 }
  , { source := 0, successor := 0 }
  ]

example : endpointUnique duplicateSourceBlindSpot = false := by
  native_decide

example : acyclic duplicateSourceBlindSpot = true := by
  native_decide

theorem duplicateSourceBlindSpot_not_standardAcyclic :
    ¬ StandardAcyclic duplicateSourceBlindSpot := by
  intro hAcyclic
  have hLoop : edgeRel duplicateSourceBlindSpot 0 0 := by
    simp [edgeRel, duplicateSourceBlindSpot]
  exact hAcyclic.irrefl 0 (Relation.TransGen.single hLoop)

/--
The first correspondence boundary is therefore not

  `acyclic edges = true ↔ StandardAcyclic edges`

for arbitrary edge lists. The production-aligned candidate must retain the
finite partial-map premise, for example:

  `endpointUnique edges = true →
    (acyclic edges = true ↔ StandardAcyclic edges)`

A later proof may weaken `endpointUnique` to source uniqueness if successor
injectivity turns out not to be needed for this specific law.
-/
theorem unconditional_correspondence_is_false :
    ∃ edges : List (Edge Nat),
      acyclic edges = true ∧ ¬ StandardAcyclic edges := by
  exact ⟨duplicateSourceBlindSpot, by native_decide,
    duplicateSourceBlindSpot_not_standardAcyclic⟩

end Loam.Experiments.CSLibSemanticCorrespondence001
