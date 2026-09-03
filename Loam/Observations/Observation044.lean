import Loam.Observations.Observation043

namespace Loam.Observation044

open Loam.Observation043

set_option autoImplicit false

universe u

/-- Transitive ancestry induced by the direct `parent` relation. -/
inductive Ancestor {Node : Type u} (parent : Parent Node) : Node → Node → Prop
  | direct {child prior : Node} :
      parent child prior → Ancestor parent child prior
  | trans {child middle prior : Node} :
      parent child middle →
      Ancestor parent middle prior →
      Ancestor parent child prior

/-- Every known node lies at or below at least one prior frontier node. -/
def FrontierCovered {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node) : Prop :=
  ∀ node, known node →
    ∃ tip, Frontier parent known tip ∧
      (tip = node ∨ Ancestor parent tip node)

/-- Every prior-known node remains in the ancestry of the new settlement tip. -/
def AllPriorKnownInAncestry {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node) : Prop :=
  ∀ node, known node → Ancestor parent newNode node

/-- If every prior-known node is covered by some prior frontier node, consuming
that whole frontier preserves every prior-known node in the new tip's ancestry.

No finiteness, acyclicity, freshness, or parent-closure assumption is needed
for this direction. -/
theorem frontierCovered_implies_allPriorKnownInAncestry
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node)
    (hConsumes : ConsumesWholeFrontier parent known newNode)
    (hCovered : FrontierCovered parent known) :
    AllPriorKnownInAncestry parent known newNode := by
  intro node hKnown
  rcases hCovered node hKnown with ⟨tip, hTipFrontier, hTip⟩
  have hParent : parent newNode tip :=
    (hConsumes tip).2 hTipFrontier
  rcases hTip with hEq | hAncestor
  · subst tip
    exact Ancestor.direct hParent
  · exact Ancestor.trans hParent hAncestor

/-- Conversely, if every prior-known node is already in the new tip's ancestry
and every direct parent of the new tip comes from the prior frontier, then the
prior view was frontier-covered. -/
theorem allPriorKnownInAncestry_implies_frontierCovered
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node)
    (hParents : ParentsFromFrontier parent known newNode)
    (hAll : AllPriorKnownInAncestry parent known newNode) :
    FrontierCovered parent known := by
  intro node hKnown
  have hAncestor : Ancestor parent newNode node := hAll node hKnown
  cases hAncestor with
  | direct hParent =>
      exact ⟨node, hParents node hParent, Or.inl rfl⟩
  | trans hParent hTail =>
      exact ⟨_, hParents _ hParent, Or.inr hTail⟩

/-- Under exact whole-frontier settlement, preserving every prior-known node in
ancestry is equivalent to the prior view being frontier-covered.

This is the unbounded condition hidden by Observation 042's finite Alloy
scope: acyclicity by itself does not guarantee frontier coverage. -/
theorem allPriorKnownInAncestry_iff_frontierCovered
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node)
    (hParents : ParentsFromFrontier parent known newNode)
    (hConsumes : ConsumesWholeFrontier parent known newNode) :
    AllPriorKnownInAncestry parent known newNode ↔
      FrontierCovered parent known := by
  constructor
  · intro hAll
    exact allPriorKnownInAncestry_implies_frontierCovered
      parent known newNode hParents hAll
  · intro hCovered
    exact frontierCovered_implies_allPriorKnownInAncestry
      parent known newNode hConsumes hCovered

/-- A graph is acyclic when no node is its own transitive ancestor. -/
def Acyclic {Node : Type u} (parent : Parent Node) : Prop :=
  ∀ node, ¬ Ancestor parent node node

/-- An infinite old chain plus one fresh settlement node. -/
inductive EndlessNode where
  | newTip
  | old (n : Nat)
  deriving DecidableEq

/-- Every `old n` is known; the new settlement node is not. -/
def endlessKnown : NodeSet EndlessNode
  | .newTip => False
  | .old _ => True

/-- Later-numbered old nodes parent every earlier-numbered old node.
The relation is acyclic, but every known node still has a known child above it,
so the prior view has no frontier at all. -/
def endlessParent : Parent EndlessNode
  | .old child, .old prior => prior < child
  | _, _ => False

/-- A numeric rank used only to show that the endless relation is acyclic. -/
def endlessRank : EndlessNode → Nat
  | .newTip => 0
  | .old n => n + 1

theorem endlessParent_rank
    {child prior : EndlessNode}
    (hParent : endlessParent child prior) :
    endlessRank prior < endlessRank child := by
  cases child <;> cases prior <;>
    simp [endlessParent, endlessRank] at hParent ⊢
  exact hParent

/-- Every transitive ancestry step strictly decreases rank when followed from
child to prior. -/
theorem endlessAncestor_rank
    {child prior : EndlessNode}
    (hAncestor : Ancestor endlessParent child prior) :
    endlessRank prior < endlessRank child := by
  induction hAncestor with
  | direct hParent =>
      exact endlessParent_rank hParent
  | trans hParent _ ih =>
      exact Nat.lt_trans ih (endlessParent_rank hParent)

theorem endlessAcyclic : Acyclic endlessParent := by
  intro node hAncestor
  have hRank := endlessAncestor_rank hAncestor
  exact (Nat.lt_irrefl _ hRank)

theorem endlessParentClosed :
    ParentClosed endlessParent endlessKnown := by
  intro child prior hKnown hParent
  cases child <;> cases prior <;>
    simp [endlessKnown, endlessParent] at hKnown hParent ⊢

/-- The endless prior view has no frontier node: every known old node has a
strictly later known old child. -/
theorem endlessNoFrontier (node : EndlessNode) :
    ¬ Frontier endlessParent endlessKnown node := by
  intro hFrontier
  rcases hFrontier with ⟨hKnown, hNoChild⟩
  cases node with
  | newTip =>
      exact hKnown
  | old n =>
      exact hNoChild (.old (n + 1))
        (by simp [endlessKnown])
        (by simp [endlessParent])

theorem endlessParentsFromFrontier :
    ParentsFromFrontier endlessParent endlessKnown .newTip := by
  intro prior hParent
  cases prior <;> simp [endlessParent] at hParent

/-- Because the prior frontier is empty and `newTip` parents nothing, it
vacuously consumes the whole prior frontier. -/
theorem endlessConsumesWholeFrontier :
    ConsumesWholeFrontier endlessParent endlessKnown .newTip := by
  intro node
  constructor
  · intro hParent
    cases node <;> simp [endlessParent] at hParent
  · intro hFrontier
    exact False.elim (endlessNoFrontier node hFrontier)

/-- Despite acyclicity, parent closure, freshness, and exact whole-frontier
consumption, the old chain is not preserved in the new tip's ancestry.

This is the infinite counterexample that a finite Alloy scope cannot express. -/
theorem acyclicityAloneDoesNotPreserveAncestry :
    Acyclic endlessParent ∧
    ParentClosed endlessParent endlessKnown ∧
    ¬ endlessKnown .newTip ∧
    ParentsFromFrontier endlessParent endlessKnown .newTip ∧
    ConsumesWholeFrontier endlessParent endlessKnown .newTip ∧
    ¬ AllPriorKnownInAncestry endlessParent endlessKnown .newTip := by
  refine ⟨endlessAcyclic, endlessParentClosed, ?_,
    endlessParentsFromFrontier, endlessConsumesWholeFrontier, ?_⟩
  · simp [endlessKnown]
  · intro hAll
    have hAncestor : Ancestor endlessParent .newTip (.old 0) :=
      hAll (.old 0) (by simp [endlessKnown])
    have hRank := endlessAncestor_rank hAncestor
    simpa [endlessRank] using hRank

/-- The exact missing property in the endless counterexample is frontier
coverage, not acyclicity. -/
theorem endlessNotFrontierCovered :
    ¬ FrontierCovered endlessParent endlessKnown := by
  intro hCovered
  rcases hCovered (.old 0) (by simp [endlessKnown]) with
    ⟨tip, hTipFrontier, _⟩
  exact endlessNoFrontier tip hTipFrontier

end Loam.Observation044
