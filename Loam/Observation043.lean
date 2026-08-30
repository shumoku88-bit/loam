namespace Loam.Observation043

set_option autoImplicit false

universe u

/-- A view is represented only by membership. No finiteness assumption is
needed by the settlement theorem. -/
abbrev NodeSet (Node : Type u) := Node → Prop

/-- `parent child prior` means that `child` directly revises or settles
`prior`. -/
abbrev Parent (Node : Type u) := Node → Node → Prop

/-- A node is on the frontier when it is known and no known node names it as a
parent. -/
def Frontier {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node) : NodeSet Node :=
  fun node =>
    known node ∧
      ∀ child, known child → ¬ parent child node

/-- Add exactly one newly known node. -/
def Add {Node : Type u}
    (known : NodeSet Node)
    (newNode : Node) : NodeSet Node :=
  fun node => known node ∨ node = newNode

/-- Every parent of an already-known child is already known. -/
def ParentClosed {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node) : Prop :=
  ∀ child prior, known child → parent child prior → known prior

/-- The new node is permitted to point only at the prior frontier. -/
def ParentsFromFrontier {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node) : Prop :=
  ∀ prior, parent newNode prior → Frontier parent known prior

/-- The new node itself is on the later frontier. Parent closure excludes an
old node from pointing to the fresh node, while `ParentsFromFrontier` excludes
a self-parent. -/
theorem newNodeIsFrontier
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node)
    (hFresh : ¬ known newNode)
    (hClosed : ParentClosed parent known)
    (hParents : ParentsFromFrontier parent known newNode) :
    Frontier parent (Add known newNode) newNode := by
  unfold Frontier
  constructor
  · exact Or.inr rfl
  · intro child hLaterChild hParent
    rcases hLaterChild with hKnownChild | hEq
    · exact hFresh (hClosed child newNode hKnownChild hParent)
    · subst child
      exact hFresh (hParents newNode hParent).1

/-- An old node survives on the later frontier exactly when it was already on
the prior frontier and the new node does not consume it. -/
theorem oldFrontierAfterIff
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode node : Node)
    (hNotNew : node ≠ newNode) :
    Frontier parent (Add known newNode) node ↔
      Frontier parent known node ∧ ¬ parent newNode node := by
  constructor
  · intro hLater
    rcases hLater with ⟨hLaterKnown, hNoLaterChild⟩
    have hKnown : known node := by
      rcases hLaterKnown with hKnown | hEq
      · exact hKnown
      · exact False.elim (hNotNew hEq)
    constructor
    · constructor
      · exact hKnown
      · intro child hKnownChild hParent
        exact hNoLaterChild child (Or.inl hKnownChild) hParent
    · intro hParent
      exact hNoLaterChild newNode (Or.inr rfl) hParent
  · intro hOld
    rcases hOld with ⟨hOldFrontier, hNoNewParent⟩
    constructor
    · exact Or.inl hOldFrontier.1
    · intro child hLaterChild hParent
      rcases hLaterChild with hKnownChild | hEq
      · exact hOldFrontier.2 child hKnownChild hParent
      · subst child
        exact hNoNewParent hParent

/-- The later view has exactly one frontier node, namely the new node. -/
def SoleFrontier {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node) : Prop :=
  ∀ node, Frontier parent (Add known newNode) node ↔ node = newNode

/-- The new node consumes exactly the entire prior frontier. -/
def ConsumesWholeFrontier {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node) : Prop :=
  ∀ node, parent newNode node ↔ Frontier parent known node

/-- Observation 042's bounded Alloy law lifts to an unbounded theorem.

Under a one-node addition from a parent-closed view, with every new parent
chosen from the prior frontier, the new node is the sole later frontier node
iff it parents exactly the whole prior frontier.

No finite-node bound, household vocabulary, explanation vocabulary, chronology,
or meaning field appears in the theorem. The only logical decidability needed
for the reverse inference is whether the new node parents a given node. -/
theorem soleFrontier_iff_consumesWholeFrontier
    {Node : Type u}
    (parent : Parent Node)
    (known : NodeSet Node)
    (newNode : Node)
    (hFresh : ¬ known newNode)
    (hClosed : ParentClosed parent known)
    (hParents : ParentsFromFrontier parent known newNode)
    (hParentDecidable : ∀ node, Decidable (parent newNode node)) :
    SoleFrontier parent known newNode ↔
      ConsumesWholeFrontier parent known newNode := by
  constructor
  · intro hSole node
    constructor
    · intro hParent
      exact hParents node hParent
    · intro hOldFrontier
      cases hParentDecidable node with
      | isTrue hParent =>
          exact hParent
      | isFalse hNoParent =>
          have hNotNew : node ≠ newNode := by
            intro hEq
            subst node
            exact hFresh hOldFrontier.1
          have hLaterFrontier :
              Frontier parent (Add known newNode) node :=
            (oldFrontierAfterIff parent known newNode node hNotNew).2
              ⟨hOldFrontier, hNoParent⟩
          have hEq : node = newNode := (hSole node).1 hLaterFrontier
          exact False.elim (hNotNew hEq)
  · intro hConsumes node
    constructor
    · intro hLaterFrontier
      rcases hLaterFrontier.1 with hKnown | hEq
      · have hNotNew : node ≠ newNode := by
          intro hEqNew
          subst node
          exact hFresh hKnown
        have hOld :
            Frontier parent known node ∧ ¬ parent newNode node :=
          (oldFrontierAfterIff parent known newNode node hNotNew).1
            hLaterFrontier
        have hParent : parent newNode node :=
          (hConsumes node).2 hOld.1
        exact False.elim (hOld.2 hParent)
      · exact hEq
    · intro hEq
      subst node
      exact newNodeIsFrontier parent known newNode hFresh hClosed hParents

end Loam.Observation043
