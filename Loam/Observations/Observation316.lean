import Loam.Observations.Observation311
import Loam.Observations.Observation315

namespace Loam.Observation316

set_option autoImplicit false

/-!
# Observation 316 — minimal future characterization

Observations 309–315 established three distinct layers:

1. bounded future signatures can suggest a behavioural quotient;
2. an independent proof can certify one bounded signature as exact for the
   unbounded declared future language;
3. a finite future-characterizing set is the weaker semantic object actually
   needed for exact finite classification.

This observation asks the next question:

> when an exact bounded characterization has been found, can we prove that it
> cannot be made shallower or smaller?

Two notions are intentionally kept separate.

Generated-depth minimality
--------------------------

For the existing bounded-signature generators, depth one is exact and depth
zero is not exact in both the ActualReversal and selected document-provenance
examples. We name that as a least exact generated depth.

Semantic-depth minimality
-------------------------

For ActualReversal we prove the stronger statement: no finite
future-characterizing set made only of depth-zero contexts can characterize the
declared future language, while the known two depth-one contexts can. Thus one
is the least semantic characterizing depth, not merely the first successful
generator depth.

Context-count minimality
------------------------

A generic Boolean lower bound shows that three pairwise future-distinct retained
states cannot be characterized by zero or one Boolean-valued future context.
ActualReversal has three such behaviours, and its two known contexts are
characterizing. Therefore two is the minimum characterizing-set cardinality.

These are concrete minimality results. They do not claim that minimum
characterizing sets are computable in general, nor that partition stabilization
proves minimality.
-/

universe uS uO uQ uA

/-! ## Generic least-depth boundary -/

/--
A depth is least for a depth-indexed property when the property holds there and
fails at every smaller natural depth.
-/
def LeastDepth
    (property : Nat → Prop)
    (depth : Nat) : Prop :=
  property depth ∧
    ∀ smaller, smaller < depth → ¬ property smaller

/-- A reusable one-step minimality lemma. -/
theorem leastDepth_one
    (property : Nat → Prop)
    (hZero : ¬ property 0)
    (hOne : property 1) :
    LeastDepth property 1 := by
  constructor
  · exact hOne
  · intro smaller hSmaller
    cases smaller with
    | zero =>
        exact hZero
    | succ n =>
        simp at hSmaller

/-! ## Least exact depth for the existing generated signatures -/

def reversalGeneratedExactAtDepth
    (depth : Nat) : Prop :=
  Loam.Observation307.ExactFutureClassifier
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    (Loam.Observation311.reversalSignatureAtDepth depth)

theorem reversal_generated_depth_zero_not_exact :
    ¬ reversalGeneratedExactAtDepth 0 := by
  intro hExact
  have hCollision :
      Loam.Observation311.reversalSignatureAtDepth 0
          Loam.Observation304.availableWitnessState =
        Loam.Observation311.reversalSignatureAtDepth 0
          Loam.Observation304.blockedWitnessState := by
    native_decide
  exact
    Loam.Observation305.available_not_futureEquivalent_blocked
      (hExact.sound hCollision)

theorem reversal_generated_depth_one_exact :
    reversalGeneratedExactAtDepth 1 :=
  Loam.Observation311.reversal_depth_one_candidate_is_exact

theorem reversal_least_exact_generated_depth :
    LeastDepth reversalGeneratedExactAtDepth 1 :=
  leastDepth_one
    reversalGeneratedExactAtDepth
    reversal_generated_depth_zero_not_exact
    reversal_generated_depth_one_exact

def provenanceGeneratedExactAtDepth
    (depth : Nat) : Prop :=
  Loam.Observation312.ExactFutureClassifierUnder
    Loam.Examples.DocumentProvenanceFutureContext.answer
    Loam.Examples.DocumentProvenanceFutureContext.step
    Loam.Observation313.SelectedOperations
    Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
    (Loam.Observation313.provenanceSignatureAtDepth depth)

theorem provenance_generated_depth_zero_not_exact :
    ¬ provenanceGeneratedExactAtDepth 0 :=
  Loam.Observation313.provenance_depth_zero_signature_is_not_exact

theorem provenance_generated_depth_one_exact :
    provenanceGeneratedExactAtDepth 1 :=
  Loam.Observation313.provenance_depth_one_signature_is_exact

theorem provenance_least_exact_generated_depth :
    LeastDepth provenanceGeneratedExactAtDepth 1 :=
  leastDepth_one
    provenanceGeneratedExactAtDepth
    provenance_generated_depth_zero_not_exact
    provenance_generated_depth_one_exact

/-! ## Semantic characterizing depth -/

/-- Every listed continuation has length at most the requested depth. -/
def ContextsWithinDepth
    {Operation : Type uO}
    {Question : Type uQ}
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (depth : Nat) : Prop :=
  ∀ context,
    context ∈ contexts →
      context.1.length ≤ depth

/--
There exists a finite future-characterizing set using no continuation deeper
than the requested bound.
-/
def CharacterizingWithinDepth
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (depth : Nat) : Prop :=
  ∃ contexts,
    Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts ∧
      ContextsWithinDepth contexts depth

def reversalCharacterizingWithinDepth
    (depth : Nat) : Prop :=
  CharacterizingWithinDepth
    Loam.Observation304.answer
    Loam.Observation304.step
    (Loam.Observation312.AllOperations :
      Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
    Loam.Observation304.Vocabulary
    depth

/--
No collection of current-only ActualReversal contexts can distinguish available
from blocked. They have the same selected current answer but different selected
future behaviour.
-/
theorem reversal_no_characterizing_set_at_depth_zero :
    ¬ reversalCharacterizingWithinDepth 0 := by
  rintro ⟨contexts, hCharacterizing, hDepth⟩
  have hOn :
      Loam.Observation315.EquivalentOnContexts
        Loam.Observation304.answer
        Loam.Observation304.step
        contexts
        Loam.Observation304.availableWitnessState
        Loam.Observation304.blockedWitnessState := by
    rintro ⟨continuation, question⟩ hMem
    have hLength := hDepth (continuation, question) hMem
    have hLengthZero : continuation.length = 0 :=
      Nat.eq_zero_of_le_zero hLength
    have hEmpty : continuation = [] :=
      List.length_eq_zero.mp hLengthZero
    subst continuation
    cases question
    native_decide
  have hFutureUnder :=
    (hCharacterizing.2
      Loam.Observation304.availableWitnessState
      Loam.Observation304.blockedWitnessState).1 hOn
  have hFuture :=
    (Loam.Observation312.futureEquivalentUnder_all_iff_futureEquivalent
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation304.availableWitnessState
      Loam.Observation304.blockedWitnessState).1 hFutureUnder
  exact
    Loam.Observation305.available_not_futureEquivalent_blocked hFuture

theorem reversal_characterizing_set_exists_at_depth_one :
    reversalCharacterizingWithinDepth 1 := by
  refine ⟨
    Loam.Observation314.reversalDepthOneContexts,
    Loam.Observation315.reversal_depth_one_contexts_characterize,
    ?_⟩
  intro context hMem
  simp only
    [Loam.Observation314.reversalDepthOneContexts,
      List.mem_cons, List.mem_singleton] at hMem
  rcases hMem with hNow | hNext
  · subst context
    simp
  · subst context
    simp

/--
Depth one is therefore the least semantic depth at which any finite
future-characterizing set can exist for the selected ActualReversal language.
-/
theorem reversal_least_characterizing_depth :
    LeastDepth reversalCharacterizingWithinDepth 1 :=
  leastDepth_one
    reversalCharacterizingWithinDepth
    reversal_no_characterizing_set_at_depth_zero
    reversal_characterizing_set_exists_at_depth_one

/-! ## Generic Boolean cardinality lower bound -/

/--
If three retained states are pairwise distinct in the declared future semantics,
a Boolean-valued future-characterizing set needs at least two contexts.

With no contexts every pair agrees vacuously. With one context only two Boolean
answers are available, so two of the three states collide. Either case
contradicts pairwise future distinction.
-/
theorem three_pairwise_future_distinct_bool_states_need_two_contexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (answer : State → Question → Bool)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (first second third : State)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hCharacterizing :
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts)
    (hFirstSecond :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary first second)
    (hFirstThird :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary first third)
    (hSecondThird :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary second third) :
    2 ≤ contexts.length := by
  cases contexts with
  | nil =>
      exfalso
      apply hFirstSecond
      apply (hCharacterizing.2 first second).1
      intro context hMem
      simp at hMem
  | cons context rest =>
      cases rest with
      | nil =>
          have hCollision :
              Loam.Observation314.contextAnswer answer step first context =
                  Loam.Observation314.contextAnswer answer step second context ∨
                Loam.Observation314.contextAnswer answer step first context =
                  Loam.Observation314.contextAnswer answer step third context ∨
                Loam.Observation314.contextAnswer answer step second context =
                  Loam.Observation314.contextAnswer answer step third context := by
            cases hFirst :
                Loam.Observation314.contextAnswer answer step first context <;>
              cases hSecond :
                Loam.Observation314.contextAnswer answer step second context <;>
              cases hThird :
                Loam.Observation314.contextAnswer answer step third context <;>
              simp_all
          rcases hCollision with h12 | h13 | h23
          · exfalso
            apply hFirstSecond
            apply (hCharacterizing.2 first second).1
            intro candidate hMem
            simp only [List.mem_singleton] at hMem
            subst candidate
            exact h12
          · exfalso
            apply hFirstThird
            apply (hCharacterizing.2 first third).1
            intro candidate hMem
            simp only [List.mem_singleton] at hMem
            subst candidate
            exact h13
          · exfalso
            apply hSecondThird
            apply (hCharacterizing.2 second third).1
            intro candidate hMem
            simp only [List.mem_singleton] at hMem
            subst candidate
            exact h23
      | cons secondContext tail =>
          simp

/--
The selected ActualReversal semantics has three pairwise future-distinct witness
states even when phrased through the operation-relative AllOperations boundary.
-/
theorem reversal_three_witnesses_pairwise_distinct_under :
    (¬ Loam.Observation312.FutureEquivalentUnder
      Loam.Observation304.answer
      Loam.Observation304.step
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
      Loam.Observation304.Vocabulary
      Loam.Observation304.availableWitnessState
      Loam.Observation304.blockedWitnessState) ∧
    (¬ Loam.Observation312.FutureEquivalentUnder
      Loam.Observation304.answer
      Loam.Observation304.step
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
      Loam.Observation304.Vocabulary
      Loam.Observation304.availableWitnessState
      Loam.Observation304.alreadyReversedWitnessState) ∧
    (¬ Loam.Observation312.FutureEquivalentUnder
      Loam.Observation304.answer
      Loam.Observation304.step
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
      Loam.Observation304.Vocabulary
      Loam.Observation304.blockedWitnessState
      Loam.Observation304.alreadyReversedWitnessState) := by
  constructor
  · intro h
    exact
      Loam.Observation305.available_not_futureEquivalent_blocked
        ((Loam.Observation312.futureEquivalentUnder_all_iff_futureEquivalent
          Loam.Observation304.answer
          Loam.Observation304.step
          Loam.Observation304.Vocabulary
          Loam.Observation304.availableWitnessState
          Loam.Observation304.blockedWitnessState).1 h)
  · constructor
    · intro h
      exact
        Loam.Observation305.available_not_futureEquivalent_alreadyReversed
          ((Loam.Observation312.futureEquivalentUnder_all_iff_futureEquivalent
            Loam.Observation304.answer
            Loam.Observation304.step
            Loam.Observation304.Vocabulary
            Loam.Observation304.availableWitnessState
            Loam.Observation304.alreadyReversedWitnessState).1 h)
    · intro h
      exact
        Loam.Observation305.blocked_not_futureEquivalent_alreadyReversed
          ((Loam.Observation312.futureEquivalentUnder_all_iff_futureEquivalent
            Loam.Observation304.answer
            Loam.Observation304.step
            Loam.Observation304.Vocabulary
            Loam.Observation304.blockedWitnessState
            Loam.Observation304.alreadyReversedWitnessState).1 h)

/--
Two is the minimum number of Boolean future contexts needed by any finite
future-characterizing set for the selected ActualReversal language.
-/
def MinimumCharacterizingContextCount
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (minimum : Nat) : Prop :=
  (∃ contexts,
      Loam.Observation315.FutureCharacterizingSetUnder
          answer step operationVocabulary questionVocabulary contexts ∧
        contexts.length = minimum) ∧
    ∀ contexts,
      Loam.Observation315.FutureCharacterizingSetUnder
          answer step operationVocabulary questionVocabulary contexts →
        minimum ≤ contexts.length

theorem reversal_minimum_characterizing_context_count :
    MinimumCharacterizingContextCount
      Loam.Observation304.answer
      Loam.Observation304.step
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
      Loam.Observation304.Vocabulary
      2 := by
  constructor
  · refine ⟨
      Loam.Observation314.reversalDepthOneContexts,
      Loam.Observation315.reversal_depth_one_contexts_characterize,
      ?_⟩
    rfl
  · intro contexts hCharacterizing
    rcases reversal_three_witnesses_pairwise_distinct_under with
      ⟨h12, h13, h23⟩
    exact
      three_pairwise_future_distinct_bool_states_need_two_contexts
        Loam.Observation304.answer
        Loam.Observation304.step
        (Loam.Observation312.AllOperations :
          Loam.Observation312.OperationVocabulary Loam.Observation304.Operation)
        Loam.Observation304.Vocabulary
        Loam.Observation304.availableWitnessState
        Loam.Observation304.blockedWitnessState
        Loam.Observation304.alreadyReversedWitnessState
        contexts
        hCharacterizing
        h12
        h13
        h23

/-!
## Finding

The earlier statement

    "depth one works"

has now split into three stronger, precise claims.

Generated signatures:

    ActualReversal:
      depth 0 not exact
      depth 1 exact
      therefore least exact generated depth = 1

    selected document provenance:
      depth 0 not exact
      depth 1 exact
      therefore least exact generated depth = 1

ActualReversal semantic depth:

    no finite characterizing set using only depth-0 contexts exists
    the known depth-1 set characterizes
    therefore least characterizing depth = 1

ActualReversal cardinality:

    three pairwise future-distinct behaviours
      + Boolean answers
      => every characterizing set has at least 2 contexts

    the known depth-1 characterizing set has exactly 2 contexts

    therefore minimum characterizing-set size = 2

This is stronger than the explorer's earlier "first stable depth = 1":
minimality is now certified independently of finite partition stabilization.

The distinction between generated-depth minimality and semantic minimality is
kept explicit. For document provenance this observation proves the former only;
a representation-independent semantic depth/cardinality theorem can be added
later if there is a reason to expose or reconstruct the required witness
boundary. The present result avoids changing the provenance fixture merely to
make a counting theorem convenient.
-/

end Loam.Observation316
