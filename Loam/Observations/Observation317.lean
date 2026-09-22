import Loam.Observations.Observation316

namespace Loam.Observation317

set_option autoImplicit false

/-!
# Observation 317 — finite behavioural quotient and finite characterization

Observation 316 proved concrete minimality results. This observation asks the
more structural question:

> when does the declared future semantics itself have only finitely many
> behavioural classes, even if the raw retained State type is large or
> unbounded?

LOAM does not need a Mathlib-style finite type to state that boundary. A finite
future quotient is witnessed directly by a finite list of retained states such
that every retained state is future-equivalent to one listed representative.

Two directions are proved.

1. finite behavioural quotient -> finite future-characterizing set

   For every pair of listed representatives that are not future-equivalent,
   classical choice selects one admitted future context that distinguishes
   them. There are only finitely many representative pairs, so the resulting
   context list is finite. Agreement on that list forces agreement between
   representatives and therefore between every covered retained state.

2. finite future-characterizing set + explicit finite answer vocabulary
   -> finite behavioural quotient

   A finite context list induces a finite answer tuple. When every possible
   Answer occurs in a caller-supplied finite list, all possible tuples can be
   enumerated. For every realized tuple we choose one retained representative.
   Characterization then proves that every retained state is future-equivalent
   to one of those finitely many representatives.

This is finite-index / distinguishing-experiment territory familiar from
Myhill-Nerode and characterization-set theory. No novelty claim is made. The
useful LOAM boundary is that raw retained state need not itself be finite.
-/

universe uS uO uQ uA uM

/--
A finite cover of all declared future-equivalence classes.

Representatives may contain duplicates or multiple states from the same
behavioural class. Minimality is deliberately not required.
-/
structure FiniteFutureQuotientUnder
    (State : Type uS)
    (Operation : Type uO)
    (Question : Type uQ)
    (Answer : Type uA)
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question) where
  representatives : List State
  covers :
    ∀ state,
      ∃ representative,
        representative ∈ representatives ∧
          Loam.Observation312.FutureEquivalentUnder
            answer step operationVocabulary questionVocabulary
            state representative

/--
If two states are not future-equivalent, one admitted future context
distinguishes them.
-/
theorem exists_distinguishing_context_of_not_futureEquivalentUnder
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (hNot :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    ∃ context : Loam.Observation314.FutureContext Operation Question,
      Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context ∧
        Loam.Observation314.contextAnswer answer step left context ≠
          Loam.Observation314.contextAnswer answer step right context := by
  classical
  apply Classical.byContradiction
  intro hNoContext
  apply hNot
  intro continuation question hAllowed hVisible
  apply Classical.byContradiction
  intro hDifferent
  exact
    hNoContext
      ⟨(continuation, question),
        ⟨hAllowed, hVisible⟩,
        hDifferent⟩

/-! ## Selecting finitely many distinguishing contexts -/

noncomputable def distinguishingContext?
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State) :
    Option (Loam.Observation314.FutureContext Operation Question) := by
  classical
  if hFuture :
      Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right then
    exact none
  else
    exact some
      (Classical.choose
        (exists_distinguishing_context_of_not_futureEquivalentUnder
          answer step operationVocabulary questionVocabulary hFuture))

theorem distinguishingContext?_spec
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State)
    {context : Loam.Observation314.FutureContext Operation Question}
    (hSome :
      distinguishingContext?
        answer step operationVocabulary questionVocabulary left right =
          some context) :
    Loam.Observation314.ContextAllowedUnder
        operationVocabulary questionVocabulary context ∧
      Loam.Observation314.contextAnswer answer step left context ≠
        Loam.Observation314.contextAnswer answer step right context := by
  classical
  unfold distinguishingContext? at hSome
  by_cases hFuture :
      Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right
  · simp [hFuture] at hSome
  · simp [hFuture] at hSome
    subst context
    exact
      Classical.choose_spec
        (exists_distinguishing_context_of_not_futureEquivalentUnder
          answer step operationVocabulary questionVocabulary hFuture)

theorem distinguishingContext?_exists_of_not_futureEquivalent
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    {left right : State}
    (hNot :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    ∃ context,
      distinguishingContext?
          answer step operationVocabulary questionVocabulary left right =
        some context ∧
      Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context ∧
      Loam.Observation314.contextAnswer answer step left context ≠
        Loam.Observation314.contextAnswer answer step right context := by
  classical
  let witness :=
    Classical.choose
      (exists_distinguishing_context_of_not_futureEquivalentUnder
        answer step operationVocabulary questionVocabulary hNot)
  have hSpec :=
    Classical.choose_spec
      (exists_distinguishing_context_of_not_futureEquivalentUnder
        answer step operationVocabulary questionVocabulary hNot)
  refine ⟨witness, ?_, hSpec.1, hSpec.2⟩
  simp [distinguishingContext?, hNot, witness]

/--
Collect all selected distinguishing contexts between one left representative
and a finite list of possible right representatives.
-/
noncomputable def distinguishingContextsAgainst
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left : State) :
    List State → List (Loam.Observation314.FutureContext Operation Question)
  | [] => []
  | right :: rest =>
      match
        distinguishingContext?
          answer step operationVocabulary questionVocabulary left right
      with
      | none =>
          distinguishingContextsAgainst
            answer step operationVocabulary questionVocabulary left rest
      | some context =>
          context ::
            distinguishingContextsAgainst
              answer step operationVocabulary questionVocabulary left rest

theorem distinguishingContextsAgainst_allowed
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left : State)
    (rights : List State)
    {context : Loam.Observation314.FutureContext Operation Question}
    (hMem :
      context ∈
        distinguishingContextsAgainst
          answer step operationVocabulary questionVocabulary left rights) :
    Loam.Observation314.ContextAllowedUnder
      operationVocabulary questionVocabulary context := by
  induction rights with
  | nil =>
      simp [distinguishingContextsAgainst] at hMem
  | cons right rest ih =>
      cases hOption :
          distinguishingContext?
            answer step operationVocabulary questionVocabulary left right with
      | none =>
          apply ih
          simpa [distinguishingContextsAgainst, hOption] using hMem
      | some selected =>
          have hParts :
              context = selected ∨
                context ∈
                  distinguishingContextsAgainst
                    answer step operationVocabulary questionVocabulary
                    left rest := by
            simpa [distinguishingContextsAgainst, hOption] using hMem
          rcases hParts with hHere | hTail
          · subst context
            exact
              (distinguishingContext?_spec
                answer step operationVocabulary questionVocabulary
                left right hOption).1
          · exact ih hTail

theorem distinguishingContextsAgainst_contains
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (left right : State)
    (rights : List State)
    (hRight : right ∈ rights)
    (hNot :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    ∃ context,
      context ∈
        distinguishingContextsAgainst
          answer step operationVocabulary questionVocabulary left rights ∧
      Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context ∧
      Loam.Observation314.contextAnswer answer step left context ≠
        Loam.Observation314.contextAnswer answer step right context := by
  induction rights generalizing right with
  | nil =>
      simp at hRight
  | cons head rest ih =>
      rcases List.mem_cons.mp hRight with hHere | hTail
      · subst head
        rcases
          distinguishingContext?_exists_of_not_futureEquivalent
            answer step operationVocabulary questionVocabulary hNot with
          ⟨context, hSome, hAllowed, hDifferent⟩
        refine ⟨context, ?_, hAllowed, hDifferent⟩
        simp [distinguishingContextsAgainst, hSome]
      · rcases ih right hTail hNot with
          ⟨context, hMem, hAllowed, hDifferent⟩
        refine ⟨context, ?_, hAllowed, hDifferent⟩
        cases hOption :
            distinguishingContext?
              answer step operationVocabulary questionVocabulary left head with
        | none =>
            simpa [distinguishingContextsAgainst, hOption] using hMem
        | some selected =>
            simp [distinguishingContextsAgainst, hOption, hMem]

/--
Traverse every listed left representative against the full representative
list. This intentionally permits duplicate contexts; finiteness and semantic
coverage matter here, not minimality.
-/
noncomputable def distinguishingContextsFrom
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (all : List State) :
    List State → List (Loam.Observation314.FutureContext Operation Question)
  | [] => []
  | left :: rest =>
      distinguishingContextsAgainst
          answer step operationVocabulary questionVocabulary left all ++
        distinguishingContextsFrom
          answer step operationVocabulary questionVocabulary all rest

noncomputable def quotientCharacterizingContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (representatives : List State) :
    List (Loam.Observation314.FutureContext Operation Question) :=
  distinguishingContextsFrom
    answer step operationVocabulary questionVocabulary
    representatives representatives

theorem distinguishingContextsFrom_allowed
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (all remaining : List State)
    {context : Loam.Observation314.FutureContext Operation Question}
    (hMem :
      context ∈
        distinguishingContextsFrom
          answer step operationVocabulary questionVocabulary all remaining) :
    Loam.Observation314.ContextAllowedUnder
      operationVocabulary questionVocabulary context := by
  induction remaining with
  | nil =>
      simp [distinguishingContextsFrom] at hMem
  | cons left rest ih =>
      have hParts :
          context ∈
              distinguishingContextsAgainst
                answer step operationVocabulary questionVocabulary left all ∨
            context ∈
              distinguishingContextsFrom
                answer step operationVocabulary questionVocabulary all rest := by
        simpa [distinguishingContextsFrom] using hMem
      rcases hParts with hHead | hTail
      · exact
          distinguishingContextsAgainst_allowed
            answer step operationVocabulary questionVocabulary
            left all hHead
      · exact ih hTail

theorem distinguishingContextsFrom_contains
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (all remaining : List State)
    (left right : State)
    (hLeft : left ∈ remaining)
    (hRight : right ∈ all)
    (hNot :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary left right) :
    ∃ context,
      context ∈
        distinguishingContextsFrom
          answer step operationVocabulary questionVocabulary all remaining ∧
      Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context ∧
      Loam.Observation314.contextAnswer answer step left context ≠
        Loam.Observation314.contextAnswer answer step right context := by
  induction remaining generalizing left right with
  | nil =>
      simp at hLeft
  | cons head rest ih =>
      rcases List.mem_cons.mp hLeft with hHere | hTail
      · subst head
        rcases
          distinguishingContextsAgainst_contains
            answer step operationVocabulary questionVocabulary
            left right all hRight hNot with
          ⟨context, hMem, hAllowed, hDifferent⟩
        refine ⟨context, ?_, hAllowed, hDifferent⟩
        exact
          List.mem_append.mpr
            (Or.inl hMem)
      · rcases ih left right hTail hRight hNot with
          ⟨context, hMem, hAllowed, hDifferent⟩
        refine ⟨context, ?_, hAllowed, hDifferent⟩
        exact
          List.mem_append.mpr
            (Or.inr hMem)

/--
A finite cover of future-equivalence classes induces a finite
future-characterizing set.
-/
theorem finiteFutureQuotient_has_finite_characterizing_set
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (quotient :
      FiniteFutureQuotientUnder
        State Operation Question Answer
        answer step operationVocabulary questionVocabulary) :
    ∃ contexts,
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts := by
  let contexts :=
    quotientCharacterizingContexts
      answer step operationVocabulary questionVocabulary
      quotient.representatives
  refine ⟨contexts, ?_⟩
  constructor
  · intro context hMem
    exact
      distinguishingContextsFrom_allowed
        answer step operationVocabulary questionVocabulary
        quotient.representatives quotient.representatives
        hMem
  · intro left right
    constructor
    · intro hSame
      rcases quotient.covers left with
        ⟨leftRepresentative, hLeftMem, hLeftFuture⟩
      rcases quotient.covers right with
        ⟨rightRepresentative, hRightMem, hRightFuture⟩
      have hRepresentativesFuture :
          Loam.Observation312.FutureEquivalentUnder
            answer step operationVocabulary questionVocabulary
            leftRepresentative rightRepresentative := by
        apply Classical.byContradiction
        intro hNot
        rcases
          distinguishingContextsFrom_contains
            answer step operationVocabulary questionVocabulary
            quotient.representatives quotient.representatives
            leftRepresentative rightRepresentative
            hLeftMem hRightMem hNot with
          ⟨context, hContextMem, hAllowed, hDifferent⟩
        have hCurrentSame : Loam.Observation314.contextAnswer
              answer step left context =
            Loam.Observation314.contextAnswer
              answer step right context :=
          hSame context hContextMem
        have hLeftAnswer : Loam.Observation314.contextAnswer
              answer step left context =
            Loam.Observation314.contextAnswer
              answer step leftRepresentative context :=
          hLeftFuture
            context.1 context.2 hAllowed.1 hAllowed.2
        have hRightAnswer : Loam.Observation314.contextAnswer
              answer step right context =
            Loam.Observation314.contextAnswer
              answer step rightRepresentative context :=
          hRightFuture
            context.1 context.2 hAllowed.1 hAllowed.2
        exact
          hDifferent
            (hLeftAnswer.symm.trans
              (hCurrentSame.trans hRightAnswer))
      exact
        Loam.Observation312.futureEquivalentUnder_trans
          answer step operationVocabulary questionVocabulary
          hLeftFuture
          (Loam.Observation312.futureEquivalentUnder_trans
            answer step operationVocabulary questionVocabulary
            hRepresentativesFuture
            (Loam.Observation312.futureEquivalentUnder_symm
              answer step operationVocabulary questionVocabulary
              hRightFuture))
    · intro hFuture context hMem
      have hAllowed :
          Loam.Observation314.ContextAllowedUnder
            operationVocabulary questionVocabulary context :=
        distinguishingContextsFrom_allowed
          answer step operationVocabulary questionVocabulary
          quotient.representatives quotient.representatives hMem
      exact
        hFuture
          context.1 context.2 hAllowed.1 hAllowed.2

/-! ## Finite characterizing set + finite answers -> finite quotient -/

/-- A nested answer tuple with exactly n coordinates. -/
def FiniteAnswerProfile
    (Answer : Type uA) : Nat → Type uA
  | 0 => PUnit
  | n + 1 => Answer × FiniteAnswerProfile Answer n

/-- Encode the answers to one finite future-context list. -/
def finiteContextProfile
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State) :
    (contexts : List (Loam.Observation314.FutureContext Operation Question)) →
      State →
        FiniteAnswerProfile Answer contexts.length
  | [], _ => PUnit.unit
  | context :: rest, state =>
      (Loam.Observation314.contextAnswer answer step state context,
        finiteContextProfile answer step rest state)

theorem finiteContextProfile_eq_iff_equivalentOnContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (left right : State) :
    finiteContextProfile answer step contexts left =
        finiteContextProfile answer step contexts right ↔
      Loam.Observation315.EquivalentOnContexts
        answer step contexts left right := by
  induction contexts with
  | nil =>
      constructor
      · intro _ context hMem
        simp at hMem
      · intro _
        rfl
  | cons head tail ih =>
      constructor
      · intro hProfile context hMem
        have hHead :
            Loam.Observation314.contextAnswer answer step left head =
              Loam.Observation314.contextAnswer answer step right head :=
          congrArg Prod.fst hProfile
        have hTail :
            finiteContextProfile answer step tail left =
              finiteContextProfile answer step tail right :=
          congrArg Prod.snd hProfile
        rcases List.mem_cons.mp hMem with hHere | hThere
        · subst context
          exact hHead
        · exact (ih.mp hTail) context hThere
      · intro hEquivalent
        apply Prod.ext
        · exact hEquivalent head (by simp)
        · apply ih.mpr
          intro context hMem
          exact hEquivalent context (by simp [hMem])

/--
The nested finite context profile is exact whenever the contexts are
future-characterizing. This direction needs no finiteness assumption on Answer.
-/
theorem finiteContextProfile_is_exact
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
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts) :
    Loam.Observation312.ExactFutureClassifierUnder
      answer step operationVocabulary questionVocabulary
      (finiteContextProfile answer step contexts) := by
  intro left right
  rw [finiteContextProfile_eq_iff_equivalentOnContexts]
  exact hCharacterizing.2 left right

/-- Enumerate every n-coordinate tuple over an explicit finite answer list. -/
def allFiniteAnswerProfiles
    {Answer : Type uA}
    (answerValues : List Answer) :
    (n : Nat) → List (FiniteAnswerProfile Answer n)
  | 0 => [PUnit.unit]
  | n + 1 =>
      answerValues.flatMap
        (fun value =>
          (allFiniteAnswerProfiles answerValues n).map
            (fun rest => (value, rest)))

theorem finiteContextProfile_mem_allFiniteAnswerProfiles
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (answerValues : List Answer)
    (hAnswerValues : ∀ value : Answer, value ∈ answerValues)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (state : State) :
    finiteContextProfile answer step contexts state ∈
      allFiniteAnswerProfiles answerValues contexts.length := by
  induction contexts with
  | nil =>
      exact List.mem_cons.mpr (Or.inl rfl)
  | cons context rest ih =>
      have hHead :
          Loam.Observation314.contextAnswer answer step state context ∈
            answerValues :=
        hAnswerValues _
      apply List.mem_flatMap_of_mem hHead
      exact
        List.mem_map.mpr
          ⟨finiteContextProfile answer step rest state, ih, rfl⟩

/--
For every realized code in a finite code list, retain one representative state.
Unrealized codes contribute nothing.
-/
noncomputable def representativesForCodes
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary) :
    List Summary → List State
  | [] => []
  | code :: rest => by
      classical
      if hRealized : ∃ state, encode state = code then
        exact
          Classical.choose hRealized ::
            representativesForCodes encode rest
      else
        exact representativesForCodes encode rest

theorem representativesForCodes_covers
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary)
    (codes : List Summary)
    (state : State)
    (hCode : encode state ∈ codes) :
    ∃ representative,
      representative ∈ representativesForCodes encode codes ∧
        encode representative = encode state := by
  classical
  induction codes with
  | nil =>
      simp at hCode
  | cons code rest ih =>
      rcases List.mem_cons.mp hCode with hHere | hTail
      · have hRealized : ∃ candidate, encode candidate = code :=
          ⟨state, hHere⟩
        let representative := Classical.choose hRealized
        refine ⟨representative, ?_, ?_⟩
        · simp [representativesForCodes, hRealized, representative]
        · exact
            (Classical.choose_spec hRealized).trans hHere.symm
      · rcases ih hTail with
          ⟨representative, hRepresentativeMem, hEncode⟩
        by_cases hRealized : ∃ candidate, encode candidate = code
        · refine ⟨representative, ?_, hEncode⟩
          simp [representativesForCodes, hRealized, hRepresentativeMem]
        · refine ⟨representative, ?_, hEncode⟩
          simpa [representativesForCodes, hRealized]
            using hRepresentativeMem

/--
A finite future-characterizing set plus an explicit finite list covering every
possible Answer yields a finite cover of the full future-equivalence quotient.
-/
noncomputable def finite_characterizing_set_has_finite_future_quotient
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
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts)
    (answerValues : List Answer)
    (hAnswerValues : ∀ value : Answer, value ∈ answerValues) :
    FiniteFutureQuotientUnder
      State Operation Question Answer
      answer step operationVocabulary questionVocabulary := by
  let encode :=
    finiteContextProfile answer step contexts
  let codes :=
    allFiniteAnswerProfiles answerValues contexts.length
  let representatives :=
    representativesForCodes encode codes
  refine
    { representatives := representatives
      covers := ?_ }
  intro state
  have hCode : encode state ∈ codes := by
    exact
      finiteContextProfile_mem_allFiniteAnswerProfiles
        answer step answerValues hAnswerValues contexts state
  rcases
      representativesForCodes_covers
        encode codes state hCode with
    ⟨representative, hRepresentativeMem, hSameCode⟩
  refine ⟨representative, hRepresentativeMem, ?_⟩
  apply
    (hCharacterizing.2 state representative).1
  apply
    (finiteContextProfile_eq_iff_equivalentOnContexts
      answer step contexts state representative).1
  exact hSameCode.symm

/-!
## Finding

The finite-index story now avoids any assumption that raw State itself is
finite.

Forward:

    finite representative cover of FutureEquivalentUnder classes
      -> finitely many representative pairs
      -> one selected distinguishing context for each inequivalent pair
      -> finite FutureCharacterizingSetUnder

Reverse:

    finite FutureCharacterizingSetUnder
      + explicit finite Answer vocabulary
      -> finitely many possible answer tuples
      -> choose one retained representative for every realized tuple
      -> finite representative cover of FutureEquivalentUnder classes

The finite context profile is also an ExactFutureClassifierUnder, independently
of whether Answer is finite. Answer finiteness is required only to conclude that
there are finitely many possible profile codes.

So the actual boundary is behavioural:

    potentially unbounded retained State
                |
                v
       FutureEquivalentUnder
                |
                v
       finite quotient index
                |
                v
      finite distinguishing profile

This is intentionally presented as a correspondence with classical
finite-index / characterization-set ideas, not as a novelty claim. The next
research step should compare this exact Lean boundary with the literature before
adding another semantic example.
-/

end Loam.Observation317
