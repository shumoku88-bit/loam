import Loam.Observation044

namespace Loam.Observation046

open Loam.Observation043
open Loam.Observation044

set_option autoImplicit false

universe u

/-- A particular frontier node covers a known node when it is either that node
itself or lies above it in ancestry. -/
def Covers {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (tip node : Node) : Prop :=
  Frontier parent known tip ∧
    (tip = node ∨ Ancestor parent tip node)

/-- `FrontierCovered` is exactly an existential law. It does not itself name a
particular covering frontier. -/
theorem frontierCovered_iff_existsCover
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node) :
    FrontierCovered parent known ↔
      ∀ node, known node → ∃ tip, Covers parent known tip node := by
  rfl

/-- Classical choice can turn the existential law into a selector without
storing an explicit witness in the graph. The selector is intentionally
noncomputable and carries no canonical-choice semantics. -/
noncomputable def chooseCoveringFrontier
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (hCovered : FrontierCovered parent known)
    (node : Node)
    (hKnown : known node) : Node :=
  Classical.choose (hCovered node hKnown)

theorem chooseCoveringFrontier_covers
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (hCovered : FrontierCovered parent known)
    (node : Node)
    (hKnown : known node) :
    Covers parent known
      (chooseCoveringFrontier parent known hCovered node hKnown) node := by
  exact Classical.choose_spec (hCovered node hKnown)

/-- Small graph where one old node has two distinct covering frontiers. -/
inductive ForkNode where
  | root
  | left
  | right
  deriving DecidableEq

def forkKnown : NodeSet ForkNode := fun _ => True

def forkParent : Parent ForkNode
  | .left, .root => True
  | .right, .root => True
  | _, _ => False

theorem forkLeftFrontier :
    Frontier forkParent forkKnown .left := by
  constructor
  · trivial
  · intro child _ hParent
    cases child <;> simp [forkParent] at hParent

theorem forkRightFrontier :
    Frontier forkParent forkKnown .right := by
  constructor
  · trivial
  · intro child _ hParent
    cases child <;> simp [forkParent] at hParent

theorem forkLeftCoversRoot :
    Covers forkParent forkKnown .left .root := by
  refine ⟨forkLeftFrontier, Or.inr ?_⟩
  exact Ancestor.direct (by simp [forkParent])

theorem forkRightCoversRoot :
    Covers forkParent forkKnown .right .root := by
  refine ⟨forkRightFrontier, Or.inr ?_⟩
  exact Ancestor.direct (by simp [forkParent])

theorem forkFrontierCovered :
    FrontierCovered forkParent forkKnown := by
  intro node _
  cases node with
  | root => exact ⟨.left, forkLeftFrontier, Or.inr (Ancestor.direct (by simp [forkParent]))⟩
  | left => exact ⟨.left, forkLeftFrontier, Or.inl rfl⟩
  | right => exact ⟨.right, forkRightFrontier, Or.inl rfl⟩

/-- The graph and the coverage law do not determine a unique answer to
"which frontier covers root?". -/
theorem forkRootHasNoUniqueCover :
    ¬ ExistsUnique (fun tip => Covers forkParent forkKnown tip .root) := by
  intro hUnique
  rcases hUnique with ⟨tip, _, hOnly⟩
  have hLeft : ForkNode.left = tip := hOnly .left forkLeftCoversRoot
  have hRight : ForkNode.right = tip := hOnly .right forkRightCoversRoot
  have hBad : ForkNode.left = ForkNode.right := hLeft.trans hRight.symm
  cases hBad

end Loam.Observation046
