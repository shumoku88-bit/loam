import Loam.Observations.Observation307

namespace Loam.Observation312

set_option autoImplicit false

/-!
# Observation 312 — future contexts relative to an operation vocabulary

Observation 192 made future-context equivalence relative to a selected question
vocabulary, but every value of the Operation type was implicitly allowed in a
continuation.

That was harmless for the small Reveal and ActualReversal fixtures, where the
operation type itself was already narrow. It becomes material for semantics such
as document provenance:

    Operation := publish : DocumentDerivation -> Operation

where a bounded experiment may intentionally admit only one or a few publication
shapes.

This observation makes that missing dimension explicit.

A future-context claim is now relative to two declared vocabularies:

    OperationVocabulary : Operation -> Prop
    QuestionVocabulary  : Question  -> Prop

The original Observation-192 semantics are recovered exactly when every
operation is selected.
-/

universe uS uO uQ uA uM

/-- Predicate selecting which operations belong to the declared future language. -/
abbrev OperationVocabulary (Operation : Type uO) :=
  Operation → Prop

/-- Every operation is selected. This recovers Observation 192's original boundary. -/
def AllOperations
    {Operation : Type uO} :
    OperationVocabulary Operation :=
  fun _ => True

/-- Every operation appearing in one finite continuation is selected. -/
def ContinuationAllowed
    {Operation : Type uO}
    (operationVocabulary : OperationVocabulary Operation)
    (continuation : List Operation) : Prop :=
  ∀ operation, operation ∈ continuation → operationVocabulary operation

@[simp] theorem empty_continuation_allowed
    {Operation : Type uO}
    (operationVocabulary : OperationVocabulary Operation) :
    ContinuationAllowed operationVocabulary [] := by
  intro operation hMem
  simp at hMem

theorem cons_continuation_allowed_iff
    {Operation : Type uO}
    (operationVocabulary : OperationVocabulary Operation)
    (operation : Operation)
    (rest : List Operation) :
    ContinuationAllowed operationVocabulary (operation :: rest) ↔
      operationVocabulary operation ∧
        ContinuationAllowed operationVocabulary rest := by
  constructor
  · intro h
    constructor
    · exact h operation (by simp)
    · intro candidate hMem
      exact h candidate (by simp [hMem])
  · rintro ⟨hOperation, hRest⟩ candidate hMem
    simp at hMem
    rcases hMem with rfl | hTail
    · exact hOperation
    · exact hRest candidate hTail

/--
Future-context equivalence relative to both an operation vocabulary and a
terminal-question vocabulary.
-/
def FutureEquivalentUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) : Prop :=
  ∀ continuation question,
    ContinuationAllowed operationVocabulary continuation →
      questionVocabulary question →
        answer (Loam.Observation192.run step left continuation) question =
          answer (Loam.Observation192.run step right continuation) question

@[refl] theorem futureEquivalentUnder_refl
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (state : State) :
    FutureEquivalentUnder
      answer step operationVocabulary questionVocabulary state state := by
  intro continuation question _ _
  rfl

@[symm] theorem futureEquivalentUnder_symm
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h :
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    FutureEquivalentUnder
      answer step operationVocabulary questionVocabulary right left := by
  intro continuation question hAllowed hVisible
  exact (h continuation question hAllowed hVisible).symm

theorem futureEquivalentUnder_trans
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left middle right : State}
    (hLeft :
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left middle)
    (hRight :
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary middle right) :
    FutureEquivalentUnder
      answer step operationVocabulary questionVocabulary left right := by
  intro continuation question hAllowed hVisible
  exact
    (hLeft continuation question hAllowed hVisible).trans
      (hRight continuation question hAllowed hVisible)

/-- Empty continuation still recovers the selected current observations. -/
theorem futureEquivalentUnder_implies_currentEquivalent
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h :
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    Loam.Observation029.Equivalent answer questionVocabulary left right := by
  intro question hVisible
  exact h [] question (empty_continuation_allowed operationVocabulary) hVisible

/--
Future equivalence under a declared operation language is stable after applying
one selected operation.
-/
theorem futureEquivalentUnder_after_allowed_step
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h :
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right)
    (operation : Operation)
    (hOperation : operationVocabulary operation) :
    FutureEquivalentUnder
      answer step operationVocabulary questionVocabulary
      (step left operation) (step right operation) := by
  intro continuation question hAllowed hVisible
  have hCons :
      ContinuationAllowed
        operationVocabulary (operation :: continuation) :=
    (cons_continuation_allowed_iff
      operationVocabulary operation continuation).2
      ⟨hOperation, hAllowed⟩
  exact h (operation :: continuation) question hCons hVisible

/-! ## Compatibility with Observation 192 -/

/--
When every operation is allowed, the operation-relative definition is exactly
Observation 192's original FutureEquivalent.
-/
theorem futureEquivalentUnder_all_iff_futureEquivalent
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) :
    FutureEquivalentUnder
        answer step (AllOperations : OperationVocabulary Operation)
        questionVocabulary left right ↔
      Loam.Observation192.FutureEquivalent
        answer step questionVocabulary left right := by
  constructor
  · intro h continuation question hVisible
    exact h continuation question
      (by
        intro operation hMem
        simp [AllOperations])
      hVisible
  · intro h continuation question _ hVisible
    exact h continuation question hVisible

/-! ## Future-sufficient summaries under selected operations -/

/--
A summary is sufficient for the declared future language when one decoder can
answer every selected terminal question after every selected continuation.
-/
def FutureSufficientUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) : Prop :=
  ∃ decode : Summary → List Operation → Question → Answer,
    ∀ state continuation question,
      ContinuationAllowed operationVocabulary continuation →
        questionVocabulary question →
          decode (encode state) continuation question =
            answer (Loam.Observation192.run step state continuation) question

/-- Equal selected-future summaries can collapse only selected-future-equivalent states. -/
theorem equalFutureSummaryInvisibleUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {encode : State → Summary}
    (hSufficient :
      FutureSufficientUnder
        answer step operationVocabulary questionVocabulary encode)
    {left right : State}
    (hEncode : encode left = encode right) :
    FutureEquivalentUnder
      answer step operationVocabulary questionVocabulary left right := by
  rcases hSufficient with ⟨decode, hDecode⟩
  intro continuation question hAllowed hVisible
  calc
    answer (Loam.Observation192.run step left continuation) question =
        decode (encode left) continuation question :=
      (hDecode left continuation question hAllowed hVisible).symm
    _ = decode (encode right) continuation question :=
      congrArg
        (fun summary => decode summary continuation question)
        hEncode
    _ = answer (Loam.Observation192.run step right continuation) question :=
      hDecode right continuation question hAllowed hVisible

/--
All-operations future sufficiency is exactly Observation 192's original
FutureSufficient.
-/
theorem futureSufficientUnder_all_iff_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) :
    FutureSufficientUnder
        answer step (AllOperations : OperationVocabulary Operation)
        questionVocabulary encode ↔
      Loam.Observation192.FutureSufficient
        answer step questionVocabulary encode := by
  constructor
  · rintro ⟨decode, hDecode⟩
    refine ⟨decode, ?_⟩
    intro state continuation question hVisible
    exact hDecode state continuation question
      (by
        intro operation hMem
        simp [AllOperations])
      hVisible
  · rintro ⟨decode, hDecode⟩
    refine ⟨decode, ?_⟩
    intro state continuation question _ hVisible
    exact hDecode state continuation question hVisible

/-! ## Exact future classifiers under selected operations -/

/--
A summary is an exact classifier for the declared operation/question language
when its fibers are exactly FutureEquivalentUnder.
-/
def ExactFutureClassifierUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) : Prop :=
  ∀ left right,
    encode left = encode right ↔
      FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right

/--
The all-operations exact-classifier boundary is exactly Observation 307's
ExactFutureClassifier.
-/
theorem exactFutureClassifierUnder_all_iff_exactFutureClassifier
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) :
    ExactFutureClassifierUnder
        answer step (AllOperations : OperationVocabulary Operation)
        questionVocabulary encode ↔
      Loam.Observation307.ExactFutureClassifier
        answer step questionVocabulary encode := by
  constructor
  · intro hExact left right
    rw [hExact left right]
    exact
      futureEquivalentUnder_all_iff_futureEquivalent
        answer step questionVocabulary left right
  · intro hExact left right
    rw [hExact left right]
    exact
      (futureEquivalentUnder_all_iff_futureEquivalent
        answer step questionVocabulary left right).symm

/-!
## Finding

The earlier phrase "declared future vocabulary" now has both coordinates:

    selected operations
      ×
    selected terminal questions

This matters whenever Operation is wider than the future language one intends to
preserve.

The new boundary is conservative:

    OperationVocabulary = AllOperations

recovers the existing Observation-192 / Observation-307 definitions exactly.

This avoids weakening earlier results while making later bounded experiments
honest about which future operations they are claiming to support.

The next useful pressure test is document provenance, whose operation type can
publish arbitrary derivation edges even when one experiment intentionally
selects only a particular future edge.
-/

end Loam.Observation312
