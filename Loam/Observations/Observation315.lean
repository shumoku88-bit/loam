import Loam.Observations.Observation314

namespace Loam.Observation315

set_option autoImplicit false

/-!
# Observation 315 — finite future-characterizing sets

Observation 314 introduced a deliberately strong finite future-context basis:
every admitted future context must have one listed representative whose answer
agrees uniformly for every retained state.

This observation separates that strong factorization property from the weaker
property actually needed to recover the behavioural quotient.

A finite context set is future-characterizing when equality of answers on just
those contexts is equivalent to full FutureEquivalentUnder.

This is the direct analogue of the role played by characterization sets in
finite-state behavioural testing:

    same answers on finite selected experiments
        iff
    same behaviour under the whole declared future language

The result has three parts:

1. a finite characterizing set is exactly enough for its finite answer profile
   to be an ExactFutureClassifierUnder;
2. every FutureContextBasisUnder is future-characterizing;
3. the converse fails: finite contexts can jointly characterize all future
   behaviour even when some other future observation is not uniformly equal to
   any one selected context.

The third point matters. Observation 314's basis condition is therefore a useful
strong certificate, not the weakest possible completeness condition.

No novelty claim is made. The purpose is to align the LOAM proof boundary more
precisely with familiar automata / behavioural-testing terminology while
preserving the synthesis -> independent certification architecture.
-/

universe uS uO uQ uA

/-- Equality of answers on one caller-selected finite context set. -/
def EquivalentOnContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (left right : State) : Prop :=
  ∀ context,
    context ∈ contexts →
      Loam.Observation314.contextAnswer answer step left context =
        Loam.Observation314.contextAnswer answer step right context

/--
Equality of the finite basis-profile functions is exactly equality on all listed
contexts.
-/
theorem basisProfile_eq_iff_equivalentOnContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (left right : State) :
    Loam.Observation314.basisProfile answer step contexts left =
        Loam.Observation314.basisProfile answer step contexts right ↔
      EquivalentOnContexts answer step contexts left right := by
  constructor
  · intro hProfile context hMem
    have hAtContext := congrFun hProfile context
    exact congrFun hAtContext hMem
  · intro hEquivalent
    funext context
    funext hMem
    exact hEquivalent context hMem

/--
A finite context set characterizes the declared future behaviour when:

- every listed context belongs to the declared future language; and
- two retained states agree on all listed contexts iff they are
  FutureEquivalentUnder for the whole declared language.
-/
def FutureCharacterizingSetUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question)) : Prop :=
  (∀ context,
      context ∈ contexts →
        Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context) ∧
    ∀ left right,
      EquivalentOnContexts answer step contexts left right ↔
        Loam.Observation312.FutureEquivalentUnder
          answer step operationVocabulary questionVocabulary left right

/--
A finite future-characterizing set induces an exact classifier by simply
recording the answers to its listed contexts.
-/
theorem futureCharacterizingSet_profile_is_exact
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hCharacterizing :
      FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts) :
    Loam.Observation312.ExactFutureClassifierUnder
      answer step operationVocabulary questionVocabulary
      (Loam.Observation314.basisProfile answer step contexts) := by
  intro left right
  rw [basisProfile_eq_iff_equivalentOnContexts]
  exact hCharacterizing.2 left right

/--
Conversely, if all listed contexts are admitted and their finite profile is an
exact future classifier, then the contexts form a future-characterizing set.
-/
theorem exact_profile_implies_futureCharacterizingSet
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hAllowed :
      ∀ context,
        context ∈ contexts →
          Loam.Observation314.ContextAllowedUnder
            operationVocabulary questionVocabulary context)
    (hExact :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary
        (Loam.Observation314.basisProfile answer step contexts)) :
    FutureCharacterizingSetUnder
      answer step operationVocabulary questionVocabulary contexts := by
  constructor
  · exact hAllowed
  · intro left right
    rw [← basisProfile_eq_iff_equivalentOnContexts]
    exact hExact left right

/--
So, under the trivial admission side-condition, "finite characterizing set" and
"finite profile is exact" are the same semantic requirement.
-/
theorem futureCharacterizingSet_iff_exact_profile
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hAllowed :
      ∀ context,
        context ∈ contexts →
          Loam.Observation314.ContextAllowedUnder
            operationVocabulary questionVocabulary context) :
    FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts ↔
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary
        (Loam.Observation314.basisProfile answer step contexts) := by
  constructor
  · exact
      futureCharacterizingSet_profile_is_exact
        answer step operationVocabulary questionVocabulary contexts
  · exact
      exact_profile_implies_futureCharacterizingSet
        answer step operationVocabulary questionVocabulary contexts hAllowed

/--
Observation 314's stronger basis property always supplies a future-
characterizing set.
-/
theorem futureContextBasis_implies_futureCharacterizingSet
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hBasis :
      Loam.Observation314.FutureContextBasisUnder
        answer step operationVocabulary questionVocabulary contexts) :
    FutureCharacterizingSetUnder
      answer step operationVocabulary questionVocabulary contexts := by
  apply
    exact_profile_implies_futureCharacterizingSet
      answer step operationVocabulary questionVocabulary contexts
  · exact hBasis.1
  · exact
      Loam.Observation314.futureContextBasis_profile_is_exact
        answer step operationVocabulary questionVocabulary contexts hBasis

/-! ## The two Observation-314 bases are therefore characterizing sets -/

theorem reversal_depth_one_contexts_characterize :
    FutureCharacterizingSetUnder
      Loam.Observation304.answer
      Loam.Observation304.step
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary
          Loam.Observation304.Operation)
      Loam.Observation304.Vocabulary
      Loam.Observation314.reversalDepthOneContexts :=
  futureContextBasis_implies_futureCharacterizingSet
    Loam.Observation304.answer
    Loam.Observation304.step
    (Loam.Observation312.AllOperations :
      Loam.Observation312.OperationVocabulary
        Loam.Observation304.Operation)
    Loam.Observation304.Vocabulary
    Loam.Observation314.reversalDepthOneContexts
    Loam.Observation314.reversal_depth_one_contexts_form_basis

theorem provenance_depth_one_contexts_characterize :
    FutureCharacterizingSetUnder
      Loam.Examples.DocumentProvenanceFutureContext.answer
      Loam.Examples.DocumentProvenanceFutureContext.step
      Loam.Observation313.SelectedOperations
      Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
      Loam.Observation314.provenanceDepthOneContexts :=
  futureContextBasis_implies_futureCharacterizingSet
    Loam.Examples.DocumentProvenanceFutureContext.answer
    Loam.Examples.DocumentProvenanceFutureContext.step
    Loam.Observation313.SelectedOperations
    Loam.Examples.DocumentProvenanceFutureContext.Vocabulary
    Loam.Observation314.provenanceDepthOneContexts
    Loam.Observation314.provenance_depth_one_contexts_form_basis

/-! ## Strictness: characterizing does not imply basis -/

/--
A tiny retained state with two independent observable bits.
-/
structure ProbeState where
  x : Bool
  y : Bool
  deriving Repr, DecidableEq

inductive ProbeOperation where
  | noop
  deriving Repr, DecidableEq

inductive ProbeQuestion where
  | x
  | y
  | xor
  deriving Repr, DecidableEq

def probeStep (state : ProbeState) : ProbeOperation → ProbeState
  | .noop => state

def probeAnswer (state : ProbeState) : ProbeQuestion → Bool
  | .x => state.x
  | .y => state.y
  | .xor => if state.x then !state.y else state.y

def ProbeVocabulary : Loam.Observation029.Vocabulary ProbeQuestion :=
  fun _ => True

def probeContexts :
    List (Loam.Observation314.FutureContext ProbeOperation ProbeQuestion) :=
  [ ([], .x)
  , ([], .y)
  ]

theorem probe_run_identity
    (state : ProbeState)
    (continuation : List ProbeOperation) :
    Loam.Observation192.run probeStep state continuation = state := by
  induction continuation with
  | nil =>
      rfl
  | cons operation rest ih =>
      cases operation
      simp only [Loam.Observation192.run, probeStep]
      exact ih

/--
The two coordinate observations x and y characterize every future observation,
including xor, because every continuation is semantically a no-op and xor is
determined by x and y jointly.
-/
theorem probeContexts_characterize :
    FutureCharacterizingSetUnder
      probeAnswer
      probeStep
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary ProbeOperation)
      ProbeVocabulary
      probeContexts := by
  constructor
  · intro context hMem
    simp only [probeContexts, List.mem_cons] at hMem
    rcases hMem with hX | hTail
    · subst context
      constructor
      · exact
          Loam.Observation312.empty_continuation_allowed
            (Loam.Observation312.AllOperations :
              Loam.Observation312.OperationVocabulary ProbeOperation)
      · simp [ProbeVocabulary]
    · rcases hTail with hY | hImpossible
      · subst context
        constructor
        · exact
            Loam.Observation312.empty_continuation_allowed
              (Loam.Observation312.AllOperations :
                Loam.Observation312.OperationVocabulary ProbeOperation)
        · simp [ProbeVocabulary]
      · simp at hImpossible
  · intro left right
    constructor
    · intro hSame
      have hXContext :=
        hSame ([], .x) (by simp [probeContexts])
      have hYContext :=
        hSame ([], .y) (by simp [probeContexts])
      have hX : left.x = right.x := by
        simpa [Loam.Observation314.contextAnswer, probeAnswer,
          Loam.Observation192.run] using hXContext
      have hY : left.y = right.y := by
        simpa [Loam.Observation314.contextAnswer, probeAnswer,
          Loam.Observation192.run] using hYContext
      intro continuation question _ _
      rw [probe_run_identity left continuation,
        probe_run_identity right continuation]
      cases question <;> simp [probeAnswer, hX, hY]
    · intro hFuture context hMem
      have hAllowed :
          Loam.Observation314.ContextAllowedUnder
            (Loam.Observation312.AllOperations :
              Loam.Observation312.OperationVocabulary ProbeOperation)
            ProbeVocabulary context := by
        exact probeContexts_characterize.1 context hMem
      exact
        hFuture
          context.1
          context.2
          hAllowed.1
          hAllowed.2

private def probeXCounterexample : ProbeState :=
  { x := false, y := true }

private def probeYCounterexample : ProbeState :=
  { x := true, y := false }

/--
The same two contexts are not a FutureContextBasisUnder.

The admitted xor observation is determined by the pair (x,y), so it adds no new
state distinction. But xor is not uniformly equal to either x or y on every
state. Thus there is no single listed representative context for it.
-/
theorem probeContexts_are_not_basis :
    ¬ Loam.Observation314.FutureContextBasisUnder
      probeAnswer
      probeStep
      (Loam.Observation312.AllOperations :
        Loam.Observation312.OperationVocabulary ProbeOperation)
      ProbeVocabulary
      probeContexts := by
  intro hBasis
  have hXor :=
    hBasis.2
      []
      .xor
      (Loam.Observation312.empty_continuation_allowed
        (Loam.Observation312.AllOperations :
          Loam.Observation312.OperationVocabulary ProbeOperation))
      (by simp [ProbeVocabulary])
  rcases hXor with ⟨context, hMem, hRepresentative⟩
  simp only [probeContexts, List.mem_cons] at hMem
  rcases hMem with hX | hTail
  · subst context
    have hFalse := hRepresentative probeXCounterexample
    native_decide at hFalse
  · rcases hTail with hY | hImpossible
    · subst context
      have hFalse := hRepresentative probeYCounterexample
      native_decide at hFalse
    · simp at hImpossible

theorem futureCharacterizingSet_does_not_imply_futureContextBasis :
    FutureCharacterizingSetUnder
        probeAnswer
        probeStep
        (Loam.Observation312.AllOperations :
          Loam.Observation312.OperationVocabulary ProbeOperation)
        ProbeVocabulary
        probeContexts ∧
      ¬ Loam.Observation314.FutureContextBasisUnder
        probeAnswer
        probeStep
        (Loam.Observation312.AllOperations :
          Loam.Observation312.OperationVocabulary ProbeOperation)
        ProbeVocabulary
        probeContexts :=
  ⟨probeContexts_characterize, probeContexts_are_not_basis⟩

/-!
## Finding

Observation 314's finite future-context basis and the weaker behavioural notion
can now be separated cleanly.

Strong certificate:

    every admitted future context
      has one uniformly equivalent listed representative
        =>
    FutureContextBasisUnder

Behavioural completeness:

    equality on all listed contexts
      iff
    FutureEquivalentUnder
        <=>
    finite answer profile is an ExactFutureClassifierUnder

The strong basis always implies behavioural completeness, but not conversely.

The synthetic x/y/xor witness makes the distinction explicit:

    selected finite contexts = {x, y}

These two observations jointly determine xor and therefore characterize the full
future behaviour. But xor is not itself uniformly equal to x or y, so the two
contexts are not a basis in Observation 314's stronger representative-context
sense.

This changes the interpretation of the previous two LOAM examples.

ActualReversal and document provenance do not merely possess finite
characterizing sets. They satisfy the stronger basis property because all
selected future observations collapse to "before the first selected operation"
or "after at least one selected operation".

The next research pressure is therefore sharper:

1. bounded synthesis should seek a candidate finite characterizing set;
2. independent Lean certification should prove behavioural completeness;
3. a stronger basis proof is useful when available, but must not be required;
4. minimal context count and minimal distinguishing depth can now be stated over
   the weaker, literature-aligned characterizing notion.

That gives a better target for the next minimization step than adding another
semantic family.
-/

end Loam.Observation315
