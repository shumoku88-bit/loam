import Loam.Observations.Observation192
import Loam.Observations.Observation297

namespace Loam.Observation298

set_option autoImplicit false

/-!
# Observation 298 — proof-directed retention verifier boundary

Observation 192 gives the semantic criterion: a retained summary is
`FutureSufficient` when it preserves every selected answer after every allowed
finite continuation.

Observation 297 relates that criterion to stronger database-style obligations.

This observation asks for the smallest reusable verifier interface around a
candidate compression.

The result is intentionally not a complete search algorithm. It admits two
machine-checkable forms of evidence:

1. a positive preservation certificate;
2. a concrete distinguishing counterexample.

A future search procedure, model checker, Alloy model, or AI-generated candidate
may produce either form. Lean owns the final semantic check.
-/

universe uS uO uQ uA uM

/--
A compact counterexample payload.

It contains only the two retained states and the future context that is claimed
to distinguish them. Equality of the proposed summary and inequality of the
future answers are checked separately.
-/
structure CounterexamplePayload
    (State : Type uS)
    (Operation : Type uO)
    (Question : Type uQ) where
  left : State
  right : State
  continuation : List Operation
  question : Question

/--
A payload is a valid retention counterexample when:

- its terminal question is selected;
- the proposed compression collapses the two source states;
- the same future continuation yields different selected answers.
-/
def ValidCounterexample
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (payload : CounterexamplePayload State Operation Question) : Prop :=
  vocabulary payload.question ∧
    encode payload.left = encode payload.right ∧
    answer
        (Loam.Observation192.run
          step payload.left payload.continuation)
        payload.question ≠
      answer
        (Loam.Observation192.run
          step payload.right payload.continuation)
        payload.question

/--
Any valid distinguishing payload refutes future sufficiency of the candidate
compression.
-/
theorem validCounterexample_refutes_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (payload : CounterexamplePayload State Operation Question)
    (hValid : ValidCounterexample answer step vocabulary encode payload) :
    ¬ Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  intro hSufficient
  rcases hValid with ⟨hVisible, hEncode, hDifferent⟩
  have hEquivalent :
      Loam.Observation192.FutureEquivalent
        answer step vocabulary payload.left payload.right :=
    Loam.Observation192.equalFutureSummaryInvisible
      answer step vocabulary hSufficient hEncode
  exact hDifferent
    (hEquivalent payload.continuation payload.question hVisible)

/--
An executable checker for a supplied payload when equality and vocabulary
membership are decidable.

This checks one proposed witness; it does not search the state space.
-/
def checkCounterexample
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : CounterexamplePayload State Operation Question) : Bool :=
  match decideVocabulary payload.question with
  | isFalse _ => false
  | isTrue _ =>
      if hEncode : encode payload.left = encode payload.right then
        if hDifferent :
            answer
                (Loam.Observation192.run
                  step payload.left payload.continuation)
                payload.question ≠
              answer
                (Loam.Observation192.run
                  step payload.right payload.continuation)
                payload.question then
          true
        else
          false
      else
        false

theorem checkCounterexample_eq_true_iff
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : CounterexamplePayload State Operation Question) :
    checkCounterexample
        answer step vocabulary decideVocabulary encode payload = true ↔
      ValidCounterexample answer step vocabulary encode payload := by
  unfold checkCounterexample ValidCounterexample
  cases hVisible : decideVocabulary payload.question with
  | isFalse hNotVisible =>
      simp [hNotVisible]
  | isTrue hVisibleProof =>
      by_cases hEncode : encode payload.left = encode payload.right
      · by_cases hDifferent :
          answer
              (Loam.Observation192.run
                step payload.left payload.continuation)
              payload.question ≠
            answer
              (Loam.Observation192.run
                step payload.right payload.continuation)
              payload.question
        · simp [hEncode, hDifferent, hVisibleProof]
        · simp [hEncode, hDifferent]
      · simp [hEncode]

/--
A reusable positive certificate built from the stronger warehouse-style route.

It is intentionally only one way to certify a candidate. A candidate may be
`FutureSufficient` without admitting exact local summary maintenance, as
Observation 297 already proves.
-/
structure MaintainedCertificate
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) where
  current :
    Loam.Observation029.SufficientFor
      answer vocabulary encode
  update :
    Loam.Observation297.UpdateIndependent step encode

theorem MaintainedCertificate.futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    {answer : State → Question → Answer}
    {step : State → Operation → State}
    {vocabulary : Loam.Observation029.Vocabulary Question}
    {encode : State → Summary}
    (certificate :
      MaintainedCertificate answer step vocabulary encode) :
    Loam.Observation192.FutureSufficient
      answer step vocabulary encode :=
  Loam.Observation297.query_and_update_independence_imply_futureSufficient
    answer step vocabulary encode certificate.current certificate.update

/--
A proof-directed verdict.

`preserved` may carry any direct proof of `FutureSufficient`, not only a
warehouse-style maintained certificate. `refuted` carries a concrete future
context witness.

No completeness claim is made: the verifier boundary does not assert that an
automatic procedure can always construct one of the two constructors.
-/
inductive RetentionVerdict
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) : Type (max uS uO uQ uA uM) where
  | preserved
      (certificate :
        Loam.Observation192.FutureSufficient
          answer step vocabulary encode)
  | refuted
      (payload : CounterexamplePayload State Operation Question)
      (witness :
        ValidCounterexample answer step vocabulary encode payload)

/-- Every produced verdict decides the semantic preservation proposition. -/
def RetentionVerdict.toDecidable
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    {answer : State → Question → Answer}
    {step : State → Operation → State}
    {vocabulary : Loam.Observation029.Vocabulary Question}
    {encode : State → Summary}
    (verdict : RetentionVerdict answer step vocabulary encode) :
    Decidable
      (Loam.Observation192.FutureSufficient
        answer step vocabulary encode) :=
  match verdict with
  | .preserved certificate => isTrue certificate
  | .refuted payload witness =>
      isFalse
        (validCounterexample_refutes_futureSufficient
          answer step vocabulary encode payload witness)

/-! ## Positive witness: maintained summary -/

def maintainedVisibleOnlyCertificate :
    MaintainedCertificate
      Loam.Observation297.exampleAnswer
      Loam.Observation297.exampleStep
      Loam.Observation297.ExampleVocabulary
      Loam.Observation297.visibleOnlyEncode :=
  { current :=
      Loam.Observation297.visibleOnlyEncode_is_currently_sufficient
    update :=
      Loam.Observation297.visibleOnlyEncode_is_updateIndependent }

def maintainedVisibleOnlyVerdict :
    RetentionVerdict
      Loam.Observation297.exampleAnswer
      Loam.Observation297.exampleStep
      Loam.Observation297.ExampleVocabulary
      Loam.Observation297.visibleOnlyEncode :=
  .preserved maintainedVisibleOnlyCertificate.futureSufficient

/-! ## Negative witness: one distinguishing future context -/

private def revealLeft : Loam.Observation192.RevealState :=
  { visible := false, hidden := false }

private def revealRight : Loam.Observation192.RevealState :=
  { visible := false, hidden := true }

private def revealCounterexample :
    CounterexamplePayload
      Loam.Observation192.RevealState
      Loam.Observation192.RevealOperation
      Loam.Observation192.RevealQuestion :=
  { left := revealLeft
    right := revealRight
    continuation := [.reveal]
    question := .visible }

def decideVisibleVocabulary :
    ∀ question : Loam.Observation192.RevealQuestion,
      Decidable (Loam.Observation192.VisibleVocabulary question) :=
  fun _ => isTrue trivial

theorem revealCounterexample_is_valid :
    ValidCounterexample
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation192.encodeVisible
      revealCounterexample := by
  simp [ValidCounterexample, revealCounterexample, revealLeft, revealRight,
    Loam.Observation192.VisibleVocabulary,
    Loam.Observation192.encodeVisible,
    Loam.Observation192.revealAnswer,
    Loam.Observation192.revealStep,
    Loam.Observation192.run]

theorem revealCounterexample_checker_accepts :
    checkCounterexample
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      decideVisibleVocabulary
      Loam.Observation192.encodeVisible
      revealCounterexample = true := by
  exact
    (checkCounterexample_eq_true_iff
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      decideVisibleVocabulary
      Loam.Observation192.encodeVisible
      revealCounterexample).2
      revealCounterexample_is_valid

def revealVerdict :
    RetentionVerdict
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation192.encodeVisible :=
  .refuted revealCounterexample revealCounterexample_is_valid

/-!
## Finding

The smallest useful verifier boundary is not a universal minimization algorithm.

It is a proof protocol:

    candidate compression
        |
        +-- preservation certificate
        |      -> FutureSufficient
        |
        +-- distinguishing payload
               -> checker
               -> not FutureSufficient

The negative payload is deliberately small and transportable:

    two states
    one finite continuation
    one selected terminal question

A search mechanism may be replaced without changing the semantic checker.
Likewise, positive certificates may come from warehouse-style maintenance,
direct proofs, stronger reconstructing complements, or future proof patterns.

This separation keeps search heuristic and semantic trust distinct.
-/

end Loam.Observation298
