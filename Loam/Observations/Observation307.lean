import Loam.Observations.Observation306

namespace Loam.Observation307

set_option autoImplicit false

/-!
# Observation 307 — exact future classifiers

Observation 306 proved, for one concrete ActualReversal vocabulary:

    encode left = encode right
      iff
    FutureEquivalent left right

This observation names only that earned generic boundary.

An exact future classifier is a summary whose fibers are exactly the
future-context equivalence classes induced by a declared operation/question
vocabulary.

The goal is deliberately modest:

1. show that a surjective exact classifier is FutureSufficient;
2. show that any two exact classifiers collapse exactly the same state pairs.

No minimization algorithm, finite-index assumption, or quotient construction is
introduced here.
-/

universe uS uO uQ uA uM uN

/--
A summary exactly classifies future-context behaviour when summary equality is
equivalent to FutureEquivalent.
-/
def ExactFutureClassifier
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) : Prop :=
  ∀ left right,
    encode left = encode right ↔
      Loam.Observation192.FutureEquivalent
        answer step vocabulary left right

/--
Every exact classifier is automatically sound as a retention partition:
equal summaries imply future equivalence.
-/
theorem ExactFutureClassifier.sound
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    {answer : State → Question → Answer}
    {step : State → Operation → State}
    {vocabulary : Loam.Observation029.Vocabulary Question}
    {encode : State → Summary}
    (hExact : ExactFutureClassifier answer step vocabulary encode)
    {left right : State}
    (hEqual : encode left = encode right) :
    Loam.Observation192.FutureEquivalent
      answer step vocabulary left right :=
  (hExact left right).1 hEqual

/--
Every exact classifier is also complete as a behavioural partition:
future-equivalent states receive the same summary.
-/
theorem ExactFutureClassifier.complete
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    {answer : State → Question → Answer}
    {step : State → Operation → State}
    {vocabulary : Loam.Observation029.Vocabulary Question}
    {encode : State → Summary}
    (hExact : ExactFutureClassifier answer step vocabulary encode)
    {left right : State}
    (hFuture :
      Loam.Observation192.FutureEquivalent
        answer step vocabulary left right) :
    encode left = encode right :=
  (hExact left right).2 hFuture

/--
If every summary code is realized by some retained state, an exact classifier
constructively supplies enough information to answer every selected future
context.

Surjectivity avoids needing an arbitrary answer for summary values that never
occur.
-/
theorem surjective_exactFutureClassifier_implies_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hSurjective : Function.Surjective encode)
    (hExact : ExactFutureClassifier answer step vocabulary encode) :
    Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  classical
  let representative : Summary → State :=
    fun summary => Classical.choose (hSurjective summary)
  have hRepresentative :
      ∀ summary, encode (representative summary) = summary := by
    intro summary
    exact Classical.choose_spec (hSurjective summary)
  refine ⟨
    fun summary continuation question =>
      answer
        (Loam.Observation192.run
          step (representative summary) continuation)
        question,
    ?_⟩
  intro state continuation question hVisible
  have hEqual :
      encode (representative (encode state)) = encode state :=
    hRepresentative (encode state)
  have hFuture :
      Loam.Observation192.FutureEquivalent
        answer step vocabulary
        (representative (encode state)) state :=
    hExact.sound hEqual
  exact hFuture continuation question hVisible

/--
Any two exact future classifiers have the same kernel relation, regardless of
their concrete summary representation.
-/
theorem exactFutureClassifiers_have_same_fibers
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    {OtherSummary : Type uN}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (otherEncode : State → OtherSummary)
    (hExact : ExactFutureClassifier answer step vocabulary encode)
    (hOtherExact :
      ExactFutureClassifier answer step vocabulary otherEncode)
    (left right : State) :
    encode left = encode right ↔
      otherEncode left = otherEncode right := by
  rw [hExact left right, hOtherExact left right]

/-! ## The Observation-306 quotient is an exact future classifier -/

/--
The three-class ActualReversal encoding is one concrete exact future classifier.
-/
theorem reversal_retention_classes_are_exact :
    ExactFutureClassifier
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation305.encode :=
  Loam.Observation306.same_class_iff_futureEquivalent

/-- All three retention-class codes are realized by concrete retained states. -/
theorem reversal_retention_classes_surjective :
    Function.Surjective Loam.Observation305.encode := by
  intro retentionClass
  cases retentionClass with
  | alreadyReversed =>
      exact
        ⟨Loam.Observation304.alreadyReversedWitnessState,
          Loam.Observation305.already_reversed_witness_class⟩
  | blocked =>
      exact
        ⟨Loam.Observation304.blockedWitnessState,
          Loam.Observation305.blocked_witness_class⟩
  | available =>
      exact
        ⟨Loam.Observation304.availableWitnessState,
          Loam.Observation305.available_witness_class⟩

/--
The generic exact-classifier theorem independently recovers FutureSufficient for
the three behavioural classes.
-/
theorem reversal_retention_classes_futureSufficient_via_exact_classifier :
    Loam.Observation192.FutureSufficient
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation305.encode :=
  surjective_exactFutureClassifier_implies_futureSufficient
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    Loam.Observation305.encode
    reversal_retention_classes_surjective
    reversal_retention_classes_are_exact

/-!
## Finding

The concrete three-class result now exposes a reusable boundary:

    retained state
         |
         v
       encode
         |
         v
    summary code

is an ExactFutureClassifier exactly when:

    same summary code
         iff
    same selected behaviour under every allowed future continuation

If the summary representation contains no unrealized codes, exact
classification is already enough to construct a FutureSufficient decoder.

The representation itself is secondary. Any two exact classifiers induce the
same partition of retained states because both partitions are exactly
FutureEquivalent.

This is familiar quotient/factorization mathematics in a future-context
setting, not a novelty claim. Its value here is architectural: the retention
thread now has a named generic boundary between

- arbitrary safe summaries;
- exact behavioural summaries;
- future-context equivalence itself.

The next step, if earned, would be executable synthesis or refinement toward an
exact classifier. Observation 307 does not attempt that.
-/

end Loam.Observation307
