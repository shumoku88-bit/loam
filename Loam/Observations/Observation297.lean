import Loam.Observations.Observation029
import Loam.Observations.Observation192

namespace Loam.Observation297

set_option autoImplicit false

/-!
# Observation 297 — warehouse independence versus future sufficiency

This observation compares LOAM's `FutureSufficient` boundary with classical
database view-complement / independent-warehouse ideas.

The comparison is deliberately structural rather than historical:

- current query independence corresponds to answering selected questions from a
  retained summary;
- update independence corresponds to updating that summary locally after a
  source operation, without consulting the original source state;
- a classical lossless view + complement can reconstruct the whole source,
  which is stronger than merely answering a selected future vocabulary.

The generic theorems below test exactly which implications hold.
-/

universe uS uO uQ uA uM uV uC

section Generic

variable {State : Type uS}
variable {Operation : Type uO}
variable {Question : Type uQ}
variable {Answer : Type uA}
variable {Summary : Type uM}

/--
Warehouse-style update independence: one local summary transition reproduces
the encoded summary of the updated source state.

The source operation itself is available to the summary transition; the original
source state is not.
-/
def UpdateIndependent
    (step : State → Operation → State)
    (encode : State → Summary) : Prop :=
  ∃ summaryStep : Summary → Operation → Summary,
    ∀ state operation,
      summaryStep (encode state) operation = encode (step state operation)

/-- Run the same finite operation continuation entirely on summaries. -/
private def runSummary
    (summaryStep : Summary → Operation → Summary) :
    Summary → List Operation → Summary
  | summary, [] => summary
  | summary, operation :: rest =>
      runSummary summaryStep (summaryStep summary operation) rest

/-- Exact one-step maintenance lifts to every finite continuation. -/
theorem runSummary_commutes
    (step : State → Operation → State)
    (encode : State → Summary)
    (summaryStep : Summary → Operation → Summary)
    (hMaintain :
      ∀ state operation,
        summaryStep (encode state) operation = encode (step state operation))
    (state : State)
    (continuation : List Operation) :
    runSummary summaryStep (encode state) continuation =
      encode (Loam.Observation192.run step state continuation) := by
  induction continuation generalizing state with
  | nil => rfl
  | cons operation rest ih =>
      simp only [runSummary, Loam.Observation192.run]
      rw [hMaintain]
      exact ih (step state operation)

/--
Current query sufficiency plus exact local summary maintenance is enough for
LOAM future sufficiency.

This is the direct abstract counterpart of combining query independence and
update independence.
-/
theorem query_and_update_independence_imply_futureSufficient
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hQuery : Loam.Observation029.SufficientFor answer vocabulary encode)
    (hUpdate : UpdateIndependent step encode) :
    Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  rcases hQuery with ⟨decode, hDecode⟩
  rcases hUpdate with ⟨summaryStep, hMaintain⟩
  refine ⟨
    fun summary continuation question =>
      decode (runSummary summaryStep summary continuation) question, ?_⟩
  intro state continuation question hVisible
  change
    decode (runSummary summaryStep (encode state) continuation) question =
      answer (Loam.Observation192.run step state continuation) question
  rw [runSummary_commutes step encode summaryStep hMaintain]
  exact hDecode
    (Loam.Observation192.run step state continuation)
    question hVisible

/--
A reconstructing complement is the classical strong case: view + complement
recover the exact source state.
-/
def ReconstructingComplement
    {View : Type uV}
    {Complement : Type uC}
    (view : State → View)
    (complement : State → Complement) : Prop :=
  ∃ recover : View × Complement → State,
    ∀ state, recover (view state, complement state) = state

/-- Exact source reconstruction makes the combined representation query-sufficient. -/
theorem reconstructingComplement_implies_currentSufficient
    {View : Type uV}
    {Complement : Type uC}
    (answer : State → Question → Answer)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (view : State → View)
    (complement : State → Complement)
    (hComplement : ReconstructingComplement view complement) :
    Loam.Observation029.SufficientFor
      answer vocabulary (fun state => (view state, complement state)) := by
  rcases hComplement with ⟨recover, hRecover⟩
  refine ⟨fun summary question => answer (recover summary) question, ?_⟩
  intro state question _
  change
    answer (recover (view state, complement state)) question =
      answer state question
  rw [hRecover]

/-- Exact source reconstruction also makes the combined representation locally maintainable. -/
theorem reconstructingComplement_implies_updateIndependent
    {View : Type uV}
    {Complement : Type uC}
    (step : State → Operation → State)
    (view : State → View)
    (complement : State → Complement)
    (hComplement : ReconstructingComplement view complement) :
    UpdateIndependent step (fun state => (view state, complement state)) := by
  rcases hComplement with ⟨recover, hRecover⟩
  refine ⟨
    fun summary operation =>
      ( view (step (recover summary) operation)
      , complement (step (recover summary) operation) ), ?_⟩
  intro state operation
  change
    ( view (step (recover (view state, complement state)) operation)
    , complement (step (recover (view state, complement state)) operation) ) =
      ( view (step state operation)
      , complement (step state operation) )
  rw [hRecover]

/--
Exact source reconstruction is sufficient for every selected future-context
question, without any additional update-maintenance theorem.
-/
theorem reconstructingComplement_implies_futureSufficient
    {View : Type uV}
    {Complement : Type uC}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (view : State → View)
    (complement : State → Complement)
    (hComplement : ReconstructingComplement view complement) :
    Loam.Observation192.FutureSufficient
      answer step vocabulary (fun state => (view state, complement state)) := by
  rcases hComplement with ⟨recover, hRecover⟩
  refine ⟨
    fun summary continuation question =>
      answer
        (Loam.Observation192.run step (recover summary) continuation)
        question, ?_⟩
  intro state continuation question _
  change
    answer
        (Loam.Observation192.run
          step (recover (view state, complement state)) continuation)
        question =
      answer (Loam.Observation192.run step state continuation) question
  rw [hRecover]

end Generic

/-! ## Strictness witness -/

/--
`junk` is retained representation detail that no selected answer depends on.
`promote` changes visible state while preserving that irrelevant detail.
-/
structure ExampleState where
  visible : Bool
  junk : Bool
  deriving Repr, DecidableEq

inductive ExampleOperation where
  | promote
  deriving Repr, DecidableEq

inductive ExampleQuestion where
  | visible
  deriving Repr, DecidableEq

def exampleStep (state : ExampleState) : ExampleOperation → ExampleState
  | .promote => { state with visible := true }

def exampleAnswer (state : ExampleState) : ExampleQuestion → Bool
  | .visible => state.visible

def ExampleVocabulary :
    Loam.Observation029.Vocabulary ExampleQuestion :=
  fun _ => True

/--
The summary always retains the visible bit. It retains junk only after visible
has become true. Thus two currently-collapsed states can later receive different
summary representations even though their selected future answers remain equal.
-/
def exampleEncode (state : ExampleState) : Bool × Bool :=
  (state.visible, if state.visible then state.junk else false)

private def exampleFutureDecode
    (summary : Bool × Bool)
    (continuation : List ExampleOperation) : ExampleQuestion → Bool
  | .visible =>
      match continuation with
      | [] => summary.1
      | _ :: _ => true

private theorem run_after_promote_visible
    (state : ExampleState)
    (rest : List ExampleOperation) :
    (Loam.Observation192.run
      exampleStep (exampleStep state .promote) rest).visible = true := by
  induction rest generalizing state with
  | nil => simp [Loam.Observation192.run, exampleStep]
  | cons operation tail ih =>
      cases operation
      simp only [Loam.Observation192.run]
      exact ih (exampleStep state .promote)

/-- The representation-sensitive summary still answers every future question. -/
theorem exampleEncode_is_futureSufficient :
    Loam.Observation192.FutureSufficient
      exampleAnswer exampleStep ExampleVocabulary exampleEncode := by
  refine ⟨exampleFutureDecode, ?_⟩
  intro state continuation question _
  cases question
  cases continuation with
  | nil =>
      simp [exampleFutureDecode, exampleEncode, exampleAnswer,
        Loam.Observation192.run]
  | cons operation rest =>
      cases operation
      simp only [exampleFutureDecode, exampleAnswer, Loam.Observation192.run]
      exact (run_after_promote_visible state rest).symm

private def hiddenFalse : ExampleState :=
  { visible := false, junk := false }

private def hiddenTrue : ExampleState :=
  { visible := false, junk := true }

/-- The two distinct source states currently have exactly the same summary. -/
theorem hidden_states_encode_equal :
    exampleEncode hiddenFalse = exampleEncode hiddenTrue := by
  rfl

/-- After the same operation, their exact encoded representations differ. -/
theorem promoted_encodings_differ :
    exampleEncode (exampleStep hiddenFalse .promote) ≠
      exampleEncode (exampleStep hiddenTrue .promote) := by
  native_decide

/--
Future sufficiency does not imply warehouse-style exact update independence.

The summary contains more representation detail after `promote` than is needed
for any selected answer. Because the two equal initial summaries would have to
map to two different next summaries, no deterministic local summary transition
can reproduce `exampleEncode` exactly.
-/
theorem futureSufficient_does_not_imply_updateIndependent :
    Loam.Observation192.FutureSufficient
        exampleAnswer exampleStep ExampleVocabulary exampleEncode ∧
      ¬ UpdateIndependent exampleStep exampleEncode := by
  constructor
  · exact exampleEncode_is_futureSufficient
  · intro hUpdate
    rcases hUpdate with ⟨summaryStep, hMaintain⟩
    have hSameNext :
        exampleEncode (exampleStep hiddenFalse .promote) =
          exampleEncode (exampleStep hiddenTrue .promote) := by
      calc
        exampleEncode (exampleStep hiddenFalse .promote) =
            summaryStep (exampleEncode hiddenFalse) .promote :=
          (hMaintain hiddenFalse .promote).symm
        _ = summaryStep (exampleEncode hiddenTrue) .promote := by
          rw [hidden_states_encode_equal]
        _ = exampleEncode (exampleStep hiddenTrue .promote) :=
          hMaintain hiddenTrue .promote
    exact promoted_encodings_differ hSameNext

/-- A simpler summary keeps only the selected visible information. -/
def visibleOnlyEncode (state : ExampleState) : Bool :=
  state.visible

private def visibleOnlyDecode (summary : Bool) : ExampleQuestion → Bool
  | .visible => summary

/-- The visible-only summary answers the selected current vocabulary. -/
theorem visibleOnlyEncode_is_currently_sufficient :
    Loam.Observation029.SufficientFor
      exampleAnswer ExampleVocabulary visibleOnlyEncode := by
  refine ⟨visibleOnlyDecode, ?_⟩
  intro state question _
  cases question
  rfl

/-- The visible-only summary is exactly locally maintainable under `promote`. -/
theorem visibleOnlyEncode_is_updateIndependent :
    UpdateIndependent exampleStep visibleOnlyEncode := by
  refine ⟨fun _ operation =>
    match operation with
    | .promote => true, ?_⟩
  intro state operation
  cases operation
  rfl

/-- Yet the query/update-independent summary still forgets retained `junk`. -/
theorem query_and_update_independence_do_not_require_injective_encoding :
    Loam.Observation029.SufficientFor
        exampleAnswer ExampleVocabulary visibleOnlyEncode ∧
      UpdateIndependent exampleStep visibleOnlyEncode ∧
      ¬ Function.Injective visibleOnlyEncode := by
  refine ⟨visibleOnlyEncode_is_currently_sufficient,
    visibleOnlyEncode_is_updateIndependent, ?_⟩
  intro hInjective
  have hState : hiddenFalse = hiddenTrue :=
    hInjective (by rfl)
  have hJunk := congrArg ExampleState.junk hState
  have : False := by
    simpa [hiddenFalse, hiddenTrue] using hJunk
  exact this

/--
Future-sufficient summaries need not reconstruct exact retained source state.
This separates LOAM's selected-future-answer criterion from a classical lossless
view + complement requirement.
-/
theorem futureSufficient_does_not_require_injective_encoding :
    Loam.Observation192.FutureSufficient
        exampleAnswer exampleStep ExampleVocabulary exampleEncode ∧
      ¬ Function.Injective exampleEncode := by
  constructor
  · exact exampleEncode_is_futureSufficient
  · intro hInjective
    have hState : hiddenFalse = hiddenTrue :=
      hInjective hidden_states_encode_equal
    have hJunk := congrArg ExampleState.junk hState
    have : False := by
      simpa [hiddenFalse, hiddenTrue] using hJunk
    exact this

/-!
## Finding

The comparison separates three strengths:

    reconstruct exact source
      > exact local summary maintenance + current query sufficiency
      > selected future-answer sufficiency

`>` here means strictly stronger in the generic setting tested above.

Classical view complements deliberately recover the whole source. Warehouse
query/update independence requires both answerability and local maintenance of
the warehouse representation. LOAM `FutureSufficient` asks only whether the
declared future operation/question vocabulary can still be answered.

Therefore the database literature is a direct ancestor of the LOAM question,
but the notions are not identical. In particular, LOAM can regard a summary as
future-sufficient even when its exact representation is not locally maintainable
and even when it does not reconstruct the retained source state.

This is not a novelty claim. It is a precise boundary for the literature
comparison and for deciding which stronger database-style obligation a future
LOAM retention verifier should or should not adopt.
-/

end Loam.Observation297
