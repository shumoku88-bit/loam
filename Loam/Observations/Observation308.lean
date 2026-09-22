import Loam.Observations.Observation299
import Loam.Observations.Observation307

namespace Loam.Observation308

set_option autoImplicit false

/-!
# Observation 308 — bounded behavioural signature synthesis

Observation 299 used a finite SearchSpace to search for counterexamples.
Observations 306–307 then identified an exact future classifier for one small
ActualReversal vocabulary.

This observation adds the smallest synthesis-side bridge between those threads.

For a supplied finite semantic slice, enumerate every selected

    bounded continuation × terminal question

context and record the answer produced by one retained state in each context.

That answer vector is the state's bounded behavioural signature.

States with equal signatures are indistinguishable inside the supplied finite
slice and depth. Distinct realized signatures therefore give an executable
candidate quotient of the supplied states.

No claim is made that a bounded signature is globally FutureEquivalent. The
result is only exact for the contexts that were actually enumerated unless a
separate theorem connects the bounded signature to the unbounded semantics.
-/

universe uS uO uQ uA

/--
Enumerate the selected bounded future contexts carried by one SearchSpace.

Questions rejected by the declared vocabulary are omitted even if they were
accidentally included in SearchSpace.questions.
-/
def boundedContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (space : Loam.Observation299.SearchSpace State Operation Question)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question)) :
    List (List Operation × Question) :=
  (Loam.Observation299.continuationsUpTo
      space.operations space.depth).flatMap
    (fun continuation =>
      space.questions.filterMap
        (fun question =>
          match decideVocabulary question with
          | isTrue _ => some (continuation, question)
          | isFalse _ => none))

/--
The bounded future-answer vector for one retained state.

The order is deterministic because it follows SearchSpace operation-word order
and then SearchSpace question order.
-/
def boundedBehaviourSignature
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (space : Loam.Observation299.SearchSpace State Operation Question)
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (state : State) : List Answer :=
  (boundedContexts space vocabulary decideVocabulary).map
    (fun context =>
      answer
        (Loam.Observation192.run step state context.1)
        context.2)

/--
The distinct bounded behaviours actually realized by the caller-supplied state
slice.
-/
def realizedBehaviourSignatures
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    [DecidableEq Answer]
    (space : Loam.Observation299.SearchSpace State Operation Question)
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question)) :
    List (List Answer) :=
  (space.states.map
    (boundedBehaviourSignature
      space answer step vocabulary decideVocabulary)).eraseDups

/--
How many bounded behavioural classes are realized in the supplied finite state
slice.
-/
def realizedBehaviourClassCount
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    [DecidableEq Answer]
    (space : Loam.Observation299.SearchSpace State Operation Question)
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question)) : Nat :=
  (realizedBehaviourSignatures
    space answer step vocabulary decideVocabulary).length

/-! ## ActualReversal synthesis fixture -/

def decideReversalVocabulary :
    ∀ question : Loam.Observation304.Question,
      Decidable (Loam.Observation304.Vocabulary question) :=
  fun _ => isTrue trivial

/--
Supply only the three retained states already known to witness the three
behavioural classes. The explorer is not told their class labels.
-/
def reversalSynthesisSpace :
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
    depth := 1 }

/-- Depth one yields exactly the current and one-publication contexts. -/
theorem reversal_bounded_contexts :
    boundedContexts reversalSynthesisSpace
        Loam.Observation304.Vocabulary
        decideReversalVocabulary =
      [ ([], .aIsReversed)
      , ([.publishAB], .aIsReversed)
      ] := by
  native_decide

theorem reversal_available_signature :
    boundedBehaviourSignature reversalSynthesisSpace
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        decideReversalVocabulary
        Loam.Observation304.availableWitnessState =
      [false, true] := by
  native_decide

theorem reversal_blocked_signature :
    boundedBehaviourSignature reversalSynthesisSpace
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        decideReversalVocabulary
        Loam.Observation304.blockedWitnessState =
      [false, false] := by
  native_decide

theorem reversal_already_reversed_signature :
    boundedBehaviourSignature reversalSynthesisSpace
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        decideReversalVocabulary
        Loam.Observation304.alreadyReversedWitnessState =
      [true, true] := by
  native_decide

/--
Without being given the hand-written class labels, bounded observation generates
three distinct answer vectors from the three supplied retained worlds.
-/
theorem reversal_realized_signatures :
    realizedBehaviourSignatures reversalSynthesisSpace
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        decideReversalVocabulary =
      [ [false, true]
      , [false, false]
      , [true, true]
      ] := by
  native_decide

theorem reversal_realized_class_count :
    realizedBehaviourClassCount reversalSynthesisSpace
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        decideReversalVocabulary = 3 := by
  native_decide

/-!
## Finding

The search-side machinery can now synthesize a bounded behavioural partition
without being handed an encode function.

For the three retained ActualReversal witness worlds:

    retained states
         |
         v
    enumerate contexts
      [] / [publishAB]
         |
         v
    answer signatures
      /      |       \
 [F,T]   [F,F]    [T,T]
         |
         v
  three realized classes

Those three generated signatures line up with the independently proved exact
classes from Observations 305–307:

    [false, true]  — available
    [false, false] — blocked
    [true, true]   — alreadyReversed

The important boundary is that Observation 308 itself proves only bounded
classification. It does not infer that depth one is globally complete.

In this particular reversal vocabulary, Observation 306 already supplies the
separate unbounded theorem that the corresponding three behaviours exactly
match FutureEquivalent. A later observation may connect the generated bounded
signature to that exact classifier.

This is the first synthesis-shaped step:

    finite semantic slice
         -> bounded future answers
         -> generated behavioural signatures
         -> candidate quotient

without yet claiming a general minimization algorithm.
-/

end Loam.Observation308
