import Loam.Observations.Observation313

namespace Loam.Observation314

set_option autoImplicit false

/-!
# Observation 314 — finite future-context bases

Observations 309 and 313 each proved a concrete bounded-completeness result:

- a finite set of current / depth-one observations generated a candidate
  behavioural signature;
- an independent unbounded proof then showed that signature equality was exactly
  future-context equivalence for the declared operation/question language.

Those examples leave a reusable question:

> What semantic condition makes a finite set of future contexts sufficient to
> classify every allowed future context?

This observation extracts one deliberately strong sufficient condition.

A finite list of future contexts is a basis when:

1. every listed context is itself admitted by the declared operation/question
   vocabularies; and
2. every admitted future context has one listed representative that produces
   the same answer in every retained state.

The second clause is intentionally uniform in the state. It says that the
unbounded future language collapses observationally onto finitely many
representative contexts.

Under that condition, the answer profile over the finite basis is an exact
future classifier.

This is close in spirit to characterization sets / distinguishing experiments
for finite-state machines and to familiar behavioural quotient constructions.
No novelty claim is made here. The purpose is to expose the exact proof
obligation that the two recent LOAM examples discharged in example-specific
ways.
-/

universe uS uO uQ uA uM

/-- One future observation context: a finite continuation and terminal question. -/
abbrev FutureContext
    (Operation : Type uO)
    (Question : Type uQ) :=
  List Operation × Question

/-- Evaluate one future observation context from one retained state. -/
def contextAnswer
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (state : State)
    (context : FutureContext Operation Question) : Answer :=
  answer
    (Loam.Observation192.run step state context.1)
    context.2

/-- A context belongs to the declared future language. -/
def ContextAllowedUnder
    {Operation : Type uO}
    {Question : Type uQ}
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (context : FutureContext Operation Question) : Prop :=
  Loam.Observation312.ContinuationAllowed
      operationVocabulary context.1 ∧
    questionVocabulary context.2

/--
A finite future-context basis for the declared future language.

Every listed context must be admitted. Conversely, every admitted context must
have a listed representative whose answer agrees for every retained state.

This is stronger than pairwise separation only. It is a direct finite
factorization condition for the whole selected future observation language.
-/
def FutureContextBasisUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (FutureContext Operation Question)) : Prop :=
  (∀ context,
      context ∈ contexts →
        ContextAllowedUnder
          operationVocabulary questionVocabulary context) ∧
    ∀ continuation question,
      Loam.Observation312.ContinuationAllowed
          operationVocabulary continuation →
        questionVocabulary question →
          ∃ context,
            context ∈ contexts ∧
              ∀ state,
                contextAnswer answer step state context =
                  answer
                    (Loam.Observation192.run step state continuation)
                    question

/--
The finite answer profile induced by one basis.

The membership proof is part of the function domain only to restrict the
profile to the finitely listed contexts. Proof irrelevance keeps the semantic
coordinate equal to the context itself.
-/
def basisProfile
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (contexts : List (FutureContext Operation Question))
    (state : State) :
    ∀ context, context ∈ contexts → Answer :=
  fun context _ =>
    contextAnswer answer step state context

/--
A finite future-context basis induces an exact classifier for the unbounded
declared future language.
-/
theorem futureContextBasis_profile_is_exact
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (FutureContext Operation Question))
    (hBasis :
      FutureContextBasisUnder
        answer step operationVocabulary questionVocabulary contexts) :
    Loam.Observation312.ExactFutureClassifierUnder
      answer step operationVocabulary questionVocabulary
      (basisProfile answer step contexts) := by
  intro left right
  constructor
  · intro hProfile
    intro continuation question hAllowed hVisible
    rcases
        hBasis.2 continuation question hAllowed hVisible with
      ⟨context, hMem, hRepresentative⟩
    have hAtContext :
        contextAnswer answer step left context =
          contextAnswer answer step right context := by
      have hAtContextFunction :=
        congrFun hProfile context
      exact congrFun hAtContextFunction hMem
    calc
      answer
          (Loam.Observation192.run step left continuation)
          question =
        contextAnswer answer step left context :=
          (hRepresentative left).symm
      _ =
        contextAnswer answer step right context :=
          hAtContext
      _ =
        answer
          (Loam.Observation192.run step right continuation)
          question :=
          hRepresentative right
  · intro hFuture
    funext context
    funext hMem
    have hContextAllowed :=
      hBasis.1 context hMem
    exact
      hFuture
        context.1
        context.2
        hContextAllowed.1
        hContextAllowed.2

/--
Any concrete encoding that induces exactly the same state-pair partition as the
finite basis profile is also an exact future classifier.

This is the bridge needed by an executable bounded signature representation:
the synthesis layer may use lists, vectors, class tags, or another finite code;
certification only needs equality of that code to have the same fibers as the
proved basis profile.
-/
theorem exact_of_same_fibers_as_basisProfile
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (FutureContext Operation Question))
    (encode : State → Summary)
    (hBasis :
      FutureContextBasisUnder
        answer step operationVocabulary questionVocabulary contexts)
    (hFibers :
      ∀ left right,
        encode left = encode right ↔
          basisProfile answer step contexts left =
            basisProfile answer step contexts right) :
    Loam.Observation312.ExactFutureClassifierUnder
      answer step operationVocabulary questionVocabulary encode := by
  intro left right
  rw [hFibers left right]
  exact
    futureContextBasis_profile_is_exact
      answer step operationVocabulary questionVocabulary contexts hBasis
      left right


/--
Any two exact classifiers under the same declared future language induce the
same equality partition on retained states.
-/
theorem exactFutureClassifiersUnder_have_same_fibers
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {LeftSummary : Type uM}
    {RightSummary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (leftEncode : State → LeftSummary)
    (rightEncode : State → RightSummary)
    (hLeft :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary leftEncode)
    (hRight :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary rightEncode)
    (left right : State) :
    leftEncode left = leftEncode right ↔
      rightEncode left = rightEncode right := by
  rw [hLeft left right, hRight left right]

/-! ## Document-provenance depth-one basis -/

abbrev ProvenanceState :=
  Loam.Examples.DocumentProvenanceFutureContext.State

abbrev ProvenanceOperation :=
  Loam.Examples.DocumentProvenanceFutureContext.Operation

abbrev ProvenanceQuestion :=
  Loam.Examples.DocumentProvenanceFutureContext.Question

/--
The two contexts mechanically generated at depth one in Observation 313.
-/
def provenanceDepthOneContexts :
    List (FutureContext ProvenanceOperation ProvenanceQuestion) :=
  [ ([], .aDerivedToDInTwoSteps)
  , ([Loam.Observation313.publishFuture], .aDerivedToDInTwoSteps)
  ]

/--
The provenance example's depth-one contexts are not merely distinguishing on
three witness states. They form a basis for every retained provenance state
under the selected operation/question language.
-/
theorem provenance_depth_one_contexts_form_basis :
    FutureContextBasisUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      Loam.Observation313.SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      provenanceDepthOneContexts := by
  constructor
  · intro context hMem
    simp only [provenanceDepthOneContexts, List.mem_cons,
      List.mem_singleton] at hMem
    rcases hMem with hNow | hNext
    · subst context
      constructor
      · exact
          Loam.Observation312.empty_continuation_allowed
            Loam.Observation313.SelectedOperations
      · simp [Loam.Examples.DocumentProvenanceFutureContext.Vocabulary]
    · subst context
      constructor
      · intro operation hOperation
        simp only [List.mem_cons, List.mem_singleton] at hOperation
        rcases hOperation with hOperation | hImpossible
        · subst operation
          rfl
        · simp at hImpossible
      · simp [Loam.Examples.DocumentProvenanceFutureContext.Vocabulary]
  · intro continuation question hAllowed _
    cases question
    by_cases hEmpty : continuation = []
    · subst continuation
      refine
        ⟨([], .aDerivedToDInTwoSteps), ?_, ?_⟩
      · simp [provenanceDepthOneContexts]
      · intro state
        rfl
    · refine
        ⟨([Loam.Observation313.publishFuture], .aDerivedToDInTwoSteps),
          ?_, ?_⟩
      · simp [provenanceDepthOneContexts]
      · intro state
        have hAnswer :=
          Loam.Observation313.selected_continuation_answer
            state continuation hAllowed
        have hAfter :
            Loam.Examples.DocumentProvenanceFutureContext.answer
                (Loam.Observation192.run
                  Loam.Examples.DocumentProvenanceFutureContext.step
                  state continuation)
                .aDerivedToDInTwoSteps =
              Loam.Examples.DocumentProvenanceFutureContext.answer
                (Loam.Examples.DocumentProvenanceFutureContext.step
                  state Loam.Observation313.publishFuture)
                .aDerivedToDInTwoSteps := by
          simpa [hEmpty] using hAnswer
        simpa [contextAnswer, Loam.Observation192.run] using hAfter.symm

theorem provenance_basis_profile_is_exact :
    Loam.Observation312.ExactFutureClassifierUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      Loam.Observation313.SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      (basisProfile
        Loam.Examples.DocumentProvenanceFutureContext.answer
        Loam.Examples.DocumentProvenanceFutureContext.step
        provenanceDepthOneContexts) :=
  futureContextBasis_profile_is_exact
    Loam.Examples.DocumentProvenanceFutureContext.answer
    Loam.Examples.DocumentProvenanceFutureContext.step
    Loam.Observation313.SelectedOperations
    Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
    provenanceDepthOneContexts
    provenance_depth_one_contexts_form_basis

/--
The mechanically generated depth-one list signature and the generic finite-basis
profile induce exactly the same partition on every retained provenance state.
-/
theorem provenance_generated_signature_has_basis_fibers
    (left right : ProvenanceState) :
    Loam.Observation313.provenanceSignatureAtDepth 1 left =
        Loam.Observation313.provenanceSignatureAtDepth 1 right ↔
      basisProfile
          Loam.Examples.DocumentProvenanceFutureContext.answer
          Loam.Examples.DocumentProvenanceFutureContext.step
          provenanceDepthOneContexts left =
        basisProfile
          Loam.Examples.DocumentProvenanceFutureContext.answer
          Loam.Examples.DocumentProvenanceFutureContext.step
          provenanceDepthOneContexts right := by
  exact
    exactFutureClassifiersUnder_have_same_fibers
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      Loam.Observation313.SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      (Loam.Observation313.provenanceSignatureAtDepth 1)
      (basisProfile
        Loam.Examples.DocumentProvenanceFutureContext.answer
        Loam.Examples.DocumentProvenanceFutureContext.step
        provenanceDepthOneContexts)
      Loam.Observation313.provenance_depth_one_signature_is_exact
      provenance_basis_profile_is_exact
      left right

/-!
## Finding

The two recent exact bounded-synthesis examples can now be read through one
generic sufficient condition.

The important object is not a magic depth number by itself. It is a finite set
of contexts that forms a basis for the selected future language:

    finite representative future contexts
                  |
                  v
        answer profile on the basis
                  |
                  v
      exact state-pair partition
                  |
                  v
       FutureEquivalentUnder

A depth bound becomes semantically meaningful only when the contexts generated
up to that depth contain such a basis.

This separates three questions that were previously close together:

1. exploration:
   which bounded contexts should be tried?
2. representation:
   how should their answer profile be encoded?
3. certification:
   do those contexts represent every admitted future observation?

Observation 314 answers only the third question with a reusable sufficient
condition. It does not claim that such a finite basis always exists, that the
smallest basis is computable in general, or that bounded partition stabilization
proves basis completeness.

That boundary also sharpens the next research options:

- connect Observation-308 list signatures to this basis theorem more directly;
- prove the ActualReversal depth-one context set satisfies the same basis
  condition; the provenance case is now proved above;
- study minimal bases / minimal distinguishing depth;
- compare the resulting proof obligation directly with automata
  characterization sets and observational completeness before adding another
  semantic family.
-/

end Loam.Observation314
