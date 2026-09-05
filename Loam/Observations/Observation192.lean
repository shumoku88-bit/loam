import Loam.Observations.Observation029
import Loam.Observations.Observation191

namespace Loam.Observation192

set_option autoImplicit false

/-!
# Observation 192 — future-context equivalence

Observation 029 made retained-state sufficiency relative to a future question
vocabulary. Observation 191 then showed that a selected observation family
induces an observational quotient, with closure characterized by factorization
through that quotient.

This observation asks whether the earlier word `future` was only about which
questions may later become visible, or whether allowed future *operations* also
refine the quotient.

The candidate is intentionally small. Given a deterministic state transition,
two states are future-context equivalent when every finite continuation of
allowed operations leaves every selected question with the same answer.

This is a Nerode-style / behavioural-equivalence shape, not a claim that LOAM is
a finite automaton. No finite-index, regular-language, acceptance, coalgebraic
production abstraction, or minimization implementation is assumed.
-/

universe uS uO uQ uA uM

section Generic

variable {State : Type uS}
variable {Operation : Type uO}
variable {Question : Type uQ}
variable {Answer : Type uA}
variable {Summary : Type uM}

/-- Execute one finite continuation of deterministic operations. -/
def run
    (step : State → Operation → State) :
    State → List Operation → State
  | state, [] => state
  | state, operation :: rest => run step (step state operation) rest

/--
Two states are indistinguishable by every selected question after every finite
continuation of allowed operations.
-/
def FutureEquivalent
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) : Prop :=
  ∀ continuation question,
    vocabulary question →
      answer (run step left continuation) question =
        answer (run step right continuation) question

@[refl] theorem futureEquivalent_refl
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (state : State) :
    FutureEquivalent answer step vocabulary state state := by
  intro continuation question _
  rfl

@[symm] theorem futureEquivalent_symm
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h : FutureEquivalent answer step vocabulary left right) :
    FutureEquivalent answer step vocabulary right left := by
  intro continuation question hVisible
  exact (h continuation question hVisible).symm

theorem futureEquivalent_trans
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    {left middle right : State}
    (hLeft : FutureEquivalent answer step vocabulary left middle)
    (hRight : FutureEquivalent answer step vocabulary middle right) :
    FutureEquivalent answer step vocabulary left right := by
  intro continuation question hVisible
  exact (hLeft continuation question hVisible).trans
    (hRight continuation question hVisible)

/-- Empty continuation recovers Observation 029's current observational equivalence. -/
theorem futureEquivalent_implies_currentEquivalent
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h : FutureEquivalent answer step vocabulary left right) :
    Loam.Observation029.Equivalent answer vocabulary left right := by
  intro question hVisible
  exact h [] question hVisible

/--
Future-context equivalence is stable under taking the same next operation on
both states. This is the right-congruence pressure absent from plain current
observation equivalence.
-/
theorem futureEquivalent_after_step
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (h : FutureEquivalent answer step vocabulary left right)
    (operation : Operation) :
    FutureEquivalent answer step vocabulary
      (step left operation) (step right operation) := by
  intro continuation question hVisible
  exact h (operation :: continuation) question hVisible

/-- A relation is stable when applying the same operation preserves it. -/
def StepStable
    (step : State → Operation → State)
    (relation : State → State → Prop) : Prop :=
  ∀ left right,
    relation left right →
      ∀ operation, relation (step left operation) (step right operation)

/-- A relation is observationally sound when related states agree right now. -/
def ObservationallySound
    (answer : State → Question → Answer)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (relation : State → State → Prop) : Prop :=
  ∀ left right,
    relation left right →
      Loam.Observation029.Equivalent answer vocabulary left right

/-- Future equivalence itself is observationally sound. -/
theorem futureEquivalent_is_observationallySound
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question) :
    ObservationallySound answer vocabulary
      (FutureEquivalent answer step vocabulary) := by
  intro left right h
  exact futureEquivalent_implies_currentEquivalent answer step vocabulary h

/-- Future equivalence itself is stable under every allowed operation. -/
theorem futureEquivalent_is_stepStable
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question) :
    StepStable step (FutureEquivalent answer step vocabulary) := by
  intro left right h operation
  exact futureEquivalent_after_step answer step vocabulary h operation

/--
Any relation that is both current-observation-sound and step-stable is contained
in future-context equivalence.

Together with the previous two theorems, this characterizes `FutureEquivalent`
as the greatest relation, by inclusion, that both respects the selected current
observations and survives every allowed next operation.
-/
theorem sound_stepStable_relation_refines_futureEquivalent
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (relation : State → State → Prop)
    (hSound : ObservationallySound answer vocabulary relation)
    (hStable : StepStable step relation) :
    ∀ left right,
      relation left right →
        FutureEquivalent answer step vocabulary left right := by
  intro left right hRelation continuation
  induction continuation generalizing left right with
  | nil =>
      intro question hVisible
      exact hSound left right hRelation question hVisible
  | cons operation rest ih =>
      intro question hVisible
      have hNext := hStable left right hRelation operation
      simpa [run] using
        (ih (left := step left operation) (right := step right operation)
          hNext question hVisible)

/-! ## Future contexts as an Observation-029 / Observation-191 quotient -/

abbrev ContextualQuestion (Operation : Type uO) (Question : Type uQ) :=
  List Operation × Question

/-- Turn a continuation + terminal question into one ordinary observation. -/
def contextualAnswer
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (state : State) :
    ContextualQuestion Operation Question → Answer
  | (continuation, question) =>
      answer (run step state continuation) question

/-- A contextual question is selected exactly when its terminal question is selected. -/
def contextualVocabulary
    (vocabulary : Loam.Observation029.Vocabulary Question) :
    Loam.Observation029.Vocabulary (ContextualQuestion Operation Question)
  | (_, question) => vocabulary question

/--
Future equivalence is ordinary Observation-029 equivalence after lifting the
question space from `Question` to `Continuation × Question`.
-/
theorem futureEquivalent_iff_contextualEquivalent
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) :
    FutureEquivalent answer step vocabulary left right ↔
      Loam.Observation029.Equivalent
        (contextualAnswer answer step)
        (contextualVocabulary vocabulary)
        left right := by
  constructor
  · intro h contextual hVisible
    exact h contextual.1 contextual.2 hVisible
  · intro h continuation question hVisible
    exact h (continuation, question) hVisible

/--
The same lifted question family is exactly an Observation-191
`IndistinguishableBy` relation. Observation 191's quotient/factorization result
can therefore be applied to *future contexts* without changing its generic
mathematics.
-/
theorem futureEquivalent_iff_observation191_indistinguishable
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) :
    FutureEquivalent answer step vocabulary left right ↔
      Loam.Observation191.IndistinguishableBy
        (Value := fun _ : ContextualQuestion Operation Question => Answer)
        (fun contextual state => contextualAnswer answer step state contextual)
        (contextualVocabulary vocabulary)
        left right := by
  constructor
  · intro h contextual hVisible
    exact h contextual.1 contextual.2 hVisible
  · intro h continuation question hVisible
    exact h (continuation, question) hVisible

/-! ## Future-aware retained summaries -/

/--
A summary is sufficient for future contexts when one decoder can recover every
selected answer after every allowed finite continuation from the summary alone.
-/
def FutureSufficient
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary) : Prop :=
  ∃ decode : Summary → List Operation → Question → Answer,
    ∀ state continuation question,
      vocabulary question →
        decode (encode state) continuation question =
          answer (run step state continuation) question

/-- Equal future-sufficient summaries can collapse only future-equivalent states. -/
theorem equalFutureSummaryInvisible
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    {encode : State → Summary}
    (hSufficient : FutureSufficient answer step vocabulary encode)
    {left right : State}
    (hEncode : encode left = encode right) :
    FutureEquivalent answer step vocabulary left right := by
  rcases hSufficient with ⟨decode, hDecode⟩
  intro continuation question hVisible
  calc
    answer (run step left continuation) question =
        decode (encode left) continuation question :=
      (hDecode left continuation question hVisible).symm
    _ = decode (encode right) continuation question :=
      congrArg (fun summary => decode summary continuation question) hEncode
    _ = answer (run step right continuation) question :=
      hDecode right continuation question hVisible

end Generic

/-! ## Concrete witness: current equality can fail after one allowed operation -/

structure RevealState where
  visible : Bool
  hidden : Bool
  deriving DecidableEq, Repr

inductive RevealOperation where
  | reveal
  deriving DecidableEq, Repr

inductive RevealQuestion where
  | visible
  deriving DecidableEq, Repr

/-- One operation copies retained hidden state into the visible answer. -/
def revealStep (state : RevealState) : RevealOperation → RevealState
  | .reveal => { state with visible := state.hidden }

/-- The current vocabulary can ask only for the visible bit. -/
def revealAnswer (state : RevealState) : RevealQuestion → Bool
  | .visible => state.visible

def VisibleVocabulary : Loam.Observation029.Vocabulary RevealQuestion :=
  fun _ => True

private def hiddenFalse : RevealState :=
  { visible := false, hidden := false }

private def hiddenTrue : RevealState :=
  { visible := false, hidden := true }

/-- The two states are indistinguishable by the current question vocabulary. -/
theorem hidden_states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      revealAnswer VisibleVocabulary hiddenFalse hiddenTrue := by
  intro question _
  cases question
  rfl

/-- But the same states are distinguished after one allowed `reveal` continuation. -/
theorem hidden_states_are_not_futureEquivalent :
    ¬ FutureEquivalent
      revealAnswer revealStep VisibleVocabulary hiddenFalse hiddenTrue := by
  intro h
  have hReveal := h [.reveal] .visible (by simp [VisibleVocabulary])
  simp [run, revealStep, revealAnswer, hiddenFalse, hiddenTrue] at hReveal

/-! ## Observation-029 summary pressure becomes strictly stronger -/

/-- The current visible bit alone is the obvious current-state summary. -/
def encodeVisible (state : RevealState) : Bool :=
  state.visible

def decodeVisible (summary : Bool) : RevealQuestion → Bool
  | .visible => summary

/-- The visible-bit summary is sufficient for the current vocabulary. -/
theorem visible_summary_is_currently_sufficient :
    Loam.Observation029.SufficientFor
      revealAnswer VisibleVocabulary encodeVisible := by
  refine ⟨decodeVisible, ?_⟩
  intro state question _
  cases question
  rfl

/--
The same summary is not sufficient once future operations are included, because
it collapses two states that `reveal` later distinguishes.
-/
theorem visible_summary_is_not_future_sufficient :
    ¬ FutureSufficient
      revealAnswer revealStep VisibleVocabulary encodeVisible := by
  intro hSufficient
  have hEquivalent :
      FutureEquivalent
        revealAnswer revealStep VisibleVocabulary hiddenFalse hiddenTrue :=
    equalFutureSummaryInvisible
      revealAnswer revealStep VisibleVocabulary hSufficient (by rfl)
  exact hidden_states_are_not_futureEquivalent hEquivalent

/-!
## Finding

Observation 029's vocabulary-relative quotient is the zero-continuation face of
a stricter dynamic quotient when allowed operations can expose currently hidden
distinctions.

The candidate structure is:

```text
state
  + allowed finite operation continuations
  + selected terminal questions
        -> future-context observational equivalence
```

`FutureEquivalent` is:

- an equivalence relation;
- a refinement of current Observation-029 equivalence;
- stable under taking the same next operation;
- the greatest, by relation inclusion, current-observation-sound step-stable
  relation;
- exactly ordinary observational equivalence after treating
  `Continuation × Question` as the observation language;
- therefore directly compatible with Observation 191's observational quotient
  and factorization machinery;
- a necessary boundary for any retained summary that claims to answer those
  future contexts.

The concrete witness proves that current sufficiency and future-context
sufficiency can differ strictly.

This is deliberately called *Nerode-style*, not the Myhill-Nerode theorem itself.
There is no language acceptance problem, finite-index claim, minimal DFA claim,
or production state-machine abstraction here. Coalgebraic behavioural
minimization may be a useful external comparison, but this observation does not
introduce a coalgebra library or claim that LOAM authority/correction/time
semantics have already been captured by one transition system.
-/

end Loam.Observation192
