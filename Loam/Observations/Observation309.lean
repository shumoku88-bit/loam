import Loam.Observations.Observation308

namespace Loam.Observation309

set_option autoImplicit false

/-!
# Observation 309 — depth-one synthesis recovers the reversal future quotient

Observation 308 generated bounded future-answer signatures from a finite
SearchSpace without being given a retention encoding.

For the ActualReversal vocabulary, depth one produced the three answer vectors

    [false, true]
    [false, false]
    [true, true]

that happened to line up with the independently proved
available / blocked / alreadyReversed classes.

This observation proves that the alignment is exact for every retained state,
not only for the three witness states.

For this vocabulary:

    equality of depth-one generated signatures
      iff
    equality of the hand-derived three behavioural classes
      iff
    FutureEquivalent

It also proves that depth zero is insufficient, because available and blocked
have the same current answer but different future behaviour.

So the selected example has a precise bounded-completeness result:

    depth 0  — too shallow
    depth 1  — recovers the full future-context quotient

This remains a concrete result for one operation/question vocabulary, not a
generic finite-depth completeness theorem.
-/

/-- The generated depth-one answer vector, usable on any retained reversal state. -/
def reversalDepthOneSignature
    (state : Loam.Observation304.State) : List Bool :=
  Loam.Observation308.boundedBehaviourSignature
    Loam.Observation308.reversalSynthesisSpace
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    Loam.Observation308.decideReversalVocabulary
    state

/-- Convert the independently derived two-answer class signature to a list. -/
def pairToList (pair : Bool × Bool) : List Bool :=
  [pair.1, pair.2]

/-- The generated-list representation of one hand-derived retention class. -/
def classSignature
    (retentionClass : Loam.Observation305.RetentionClass) : List Bool :=
  pairToList (Loam.Observation306.behaviourSignature retentionClass)

theorem pairToList_injective :
    Function.Injective pairToList := by
  intro left right hEqual
  rcases left with ⟨leftNow, leftNext⟩
  rcases right with ⟨rightNow, rightNext⟩
  simp [pairToList] at hEqual ⊢
  exact hEqual

theorem classSignature_injective :
    Function.Injective classSignature := by
  intro left right hEqual
  apply Loam.Observation306.behaviourSignature_injective
  apply pairToList_injective
  simpa [classSignature] using hEqual

/--
For every retained state, the mechanically generated depth-one answer vector is
exactly the list form of the independently derived behavioural-class signature.
-/
theorem reversalDepthOneSignature_eq_classSignature
    (state : Loam.Observation304.State) :
    reversalDepthOneSignature state =
      classSignature (Loam.Observation305.encode state) := by
  calc
    reversalDepthOneSignature state =
        [ Loam.Observation304.answer state .aIsReversed
        , Loam.Observation304.answer
            (Loam.Observation304.step state .publishAB)
            .aIsReversed ] := by
      simp [reversalDepthOneSignature,
        Loam.Observation308.boundedBehaviourSignature,
        Loam.Observation308.reversal_bounded_contexts,
        Loam.Observation192.run]
    _ =
        classSignature (Loam.Observation305.encode state) := by
      unfold classSignature
      rw [Loam.Observation306.behaviourSignature_encode]
      rfl

/--
Depth-one signature equality is exactly equality of the three independently
derived behavioural classes.
-/
theorem same_depth_one_signature_iff_same_class
    (left right : Loam.Observation304.State) :
    reversalDepthOneSignature left =
        reversalDepthOneSignature right ↔
      Loam.Observation305.encode left =
        Loam.Observation305.encode right := by
  constructor
  · intro hSignature
    apply classSignature_injective
    calc
      classSignature (Loam.Observation305.encode left) =
          reversalDepthOneSignature left :=
        (reversalDepthOneSignature_eq_classSignature left).symm
      _ = reversalDepthOneSignature right := hSignature
      _ = classSignature (Loam.Observation305.encode right) :=
        reversalDepthOneSignature_eq_classSignature right
  · intro hClass
    rw [reversalDepthOneSignature_eq_classSignature,
      reversalDepthOneSignature_eq_classSignature,
      hClass]

/--
The bounded depth-one signature is therefore an exact classifier for the
unbounded selected future semantics.
-/
theorem same_depth_one_signature_iff_futureEquivalent
    (left right : Loam.Observation304.State) :
    reversalDepthOneSignature left =
        reversalDepthOneSignature right ↔
      Loam.Observation192.FutureEquivalent
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        left right := by
  rw [same_depth_one_signature_iff_same_class]
  exact Loam.Observation306.same_class_iff_futureEquivalent left right

theorem reversalDepthOneSignature_is_exact :
    Loam.Observation307.ExactFutureClassifier
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      reversalDepthOneSignature :=
  same_depth_one_signature_iff_futureEquivalent

/-! ## Depth zero is not enough -/

def reversalDepthZeroSpace :
    Loam.Observation299.SearchSpace
      Loam.Observation304.State
      Loam.Observation304.Operation
      Loam.Observation304.Question :=
  { states :=
      [ Loam.Observation304.availableWitnessState
      , Loam.Observation304.blockedWitnessState
      , Loam.Observation304.alreadyReversedWitnessState
      ]
    operations := [.publishAB]
    questions := [.aIsReversed]
    depth := 0 }

def reversalDepthZeroSignature
    (state : Loam.Observation304.State) : List Bool :=
  Loam.Observation308.boundedBehaviourSignature
    reversalDepthZeroSpace
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    Loam.Observation308.decideReversalVocabulary
    state

/--
At depth zero, available and blocked are still merged because both currently
answer false.
-/
theorem depth_zero_merges_available_and_blocked :
    reversalDepthZeroSignature
        Loam.Observation304.availableWitnessState =
      reversalDepthZeroSignature
        Loam.Observation304.blockedWitnessState := by
  native_decide

/--
That depth-zero collision is semantically wrong for the unbounded future
vocabulary, so depth zero cannot be an exact future classifier.
-/
theorem reversalDepthZeroSignature_is_not_exact :
    ¬ Loam.Observation307.ExactFutureClassifier
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      reversalDepthZeroSignature := by
  intro hExact
  have hFuture :=
    hExact.sound depth_zero_merges_available_and_blocked
  exact
    Loam.Observation305.available_not_futureEquivalent_blocked hFuture

/-!
## Finding

The synthesis and proof threads now meet exactly in the reversal example.

The bounded generator sees only:

    states
    operation list
    question list
    depth

At depth one it produces answer vectors. Observation 309 proves that the fibers
of those generated vectors are exactly the fibers of the independently derived
three-class summary, and therefore exactly FutureEquivalent.

    depth-one generated signature equality
                |
                v
        same retention class
                |
                v
         FutureEquivalent

Depth zero demonstrably fails because it merges available and blocked.

So this example now has both:

    synthesis:
      future answers -> candidate classes

    certification:
      candidate classes <-> unbounded future semantics

The result does not say that depth one suffices in general, or that bounded
search can discover a sufficient depth automatically. It gives one Lean-checked
instance in which a bounded behavioural synthesis recovers the exact future
quotient, together with a proof that the immediately smaller depth does not.
-/

end Loam.Observation309
