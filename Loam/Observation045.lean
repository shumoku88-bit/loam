import Loam.Observation044

namespace Loam.Observation045

open Loam.Observation043
open Loam.Observation044

set_option autoImplicit false

universe u

/-- Move from a prior known node toward one of its known children. -/
def KnownChild {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node) : Node → Node → Prop :=
  fun child prior => known child ∧ parent child prior

/-- Append one direct parent step to the old end of an ancestry path. -/
theorem ancestor_appendDirect
    {Node : Type u}
    (parent : Parent Node)
    {tip middle prior : Node}
    (hAncestor : Ancestor parent tip middle)
    (hParent : parent middle prior) :
    Ancestor parent tip prior := by
  induction hAncestor with
  | direct hFirst =>
      exact Ancestor.trans hFirst (Ancestor.direct hParent)
  | trans hFirst _ ih =>
      exact Ancestor.trans hFirst ih

/-- If following known children is well-founded, every known node eventually
reaches at least one frontier node.

No finiteness, parent closure, freshness, settlement node, or acyclicity
assumption is needed. -/
theorem wellFoundedKnownChild_implies_frontierCovered
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (hWF : WellFounded (KnownChild parent known)) :
    FrontierCovered parent known := by
  classical
  intro node hKnown
  have hCover :
      known node →
        ∃ tip, Frontier parent known tip ∧
          (tip = node ∨ Ancestor parent tip node) := by
    apply hWF.induction node
    intro current ih hCurrentKnown
    by_cases hHasChild :
        ∃ child, KnownChild parent known child current
    · rcases hHasChild with ⟨child, hChildKnown, hParent⟩
      rcases ih child ⟨hChildKnown, hParent⟩ hChildKnown with
        ⟨tip, hTipFrontier, hTipPath⟩
      refine ⟨tip, hTipFrontier, ?_⟩
      rcases hTipPath with hEq | hAncestor
      · subst tip
        exact Or.inr (Ancestor.direct hParent)
      · exact Or.inr (ancestor_appendDirect parent hAncestor hParent)
    · have hFrontier : Frontier parent known current := by
        constructor
        · exact hCurrentKnown
        · intro child hKnownChild hParent
          exact hHasChild ⟨child, hKnownChild, hParent⟩
      exact ⟨current, hFrontier, Or.inl rfl⟩
  exact hCover hKnown

/-- A graph with an infinite spine, while every spine node also has its own
frontier tip. -/
inductive EscapingNode where
  | spine (n : Nat)
  | tip (n : Nat)
  deriving DecidableEq

/-- Every node in the counterexample is known. -/
def escapingKnown : NodeSet EscapingNode :=
  fun _ => True

/-- The spine extends forever, but `tip n` also directly parents `spine n`.
No node parents a tip. -/
def escapingParent : Parent EscapingNode
  | .spine child, .spine prior => prior < child
  | .tip n, .spine prior => prior = n
  | _, _ => False

theorem escapingTipFrontier (n : Nat) :
    Frontier escapingParent escapingKnown (.tip n) := by
  constructor
  · trivial
  · intro child _ hParent
    cases child <;> simp [escapingParent] at hParent

/-- Every node is frontier-covered despite the infinite spine. -/
theorem escapingFrontierCovered :
    FrontierCovered escapingParent escapingKnown := by
  intro node _
  cases node with
  | tip n =>
      exact ⟨.tip n, escapingTipFrontier n, Or.inl rfl⟩
  | spine n =>
      refine ⟨.tip n, escapingTipFrontier n, Or.inr ?_⟩
      exact Ancestor.direct (by simp [escapingParent])

/-- A proposition chosen so well-founded induction on `spine 0` would have to
prove `False` if the endless known-child chain were well-founded. -/
def SpineImpossible : EscapingNode → Prop
  | .spine _ => False
  | .tip _ => True

theorem escapingKnownChild_spine (n : Nat) :
    KnownChild escapingParent escapingKnown
      (.spine (n + 1)) (.spine n) := by
  constructor
  · trivial
  · simp [escapingParent]

/-- Frontier coverage does not imply well-founded known-child traversal.
The spine provides an infinite path even though every node has a separate
frontier route. -/
theorem escapingNotWellFounded :
    ¬ WellFounded (KnownChild escapingParent escapingKnown) := by
  intro hWF
  have hImpossible : SpineImpossible (.spine 0) := by
    apply hWF.induction (.spine 0)
    intro current ih
    cases current with
    | tip n =>
        simp [SpineImpossible]
    | spine n =>
        exact ih (.spine (n + 1)) (escapingKnownChild_spine n)
  simpa [SpineImpossible] using hImpossible

/-- The implication is strict: well-foundedness is sufficient for frontier
coverage, but frontier coverage intentionally permits irrelevant infinite
branches when every known node still has some route to a frontier. -/
theorem frontierCoverageDoesNotImplyWellFounded :
    FrontierCovered escapingParent escapingKnown ∧
      ¬ WellFounded (KnownChild escapingParent escapingKnown) := by
  exact ⟨escapingFrontierCovered, escapingNotWellFounded⟩

end Loam.Observation045
