import Loam.Observations.Observation316

namespace Loam.Observation317

set_option autoImplicit false

/-!
# Observation 317 — finite behavioural quotient and finite characterization

Observation 316 proved concrete minimality results for two selected future
languages. This observation moves one level up and asks when finite
characterization exists at all.

The useful boundary is not that the raw retained state type is finite. It may be
large or infinite. What matters is whether the declared future semantics admits
a finite exact classifier.

Two directions are proved.

1. Finite exact classifier -> finite future-characterizing set

   If future equivalence is exactly equality under some finite summary type,
   then only finitely many summary classes are realized. For each pair of
   distinct realized classes, choose one admitted future context that separates
   representatives of those classes. The finite collection of all such chosen
   contexts characterizes the entire state space.

2. Finite future-characterizing set + finite answers -> finite exact classifier

   A finite context list gives a finite answer tuple. Equality of those tuples
   is exactly equality on the selected contexts, and therefore exactly
   FutureEquivalentUnder when the contexts are characterizing.

This is a finite-index / finite-distinguishing-experiment result in the spirit
of Myhill-Nerode and characterization-set theory. No novelty claim is made.
The LOAM-specific use is that the raw retained state can remain unbounded while
the future-behaviour quotient is finite.
-/

universe uS uO uQ uA uM

/--
A finite exact future quotient is any classifier into a finite summary type
whose equality fibers are exactly the declared future-equivalence classes.

The summary need not be minimal and need not be surjective. Unused codes are
harmless.
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
  Summary : Type uM
  finiteSummary : Finite Summary
  encode : State → Summary
  exact :
    Loam.Observation312.ExactFutureClassifierUnder
      answer step operationVocabulary questionVocabulary encode

/--
If two states are not future-equivalent, classical logic exposes one admitted
future context whose answers differ.
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
  unfold Loam.Observation312.FutureEquivalentUnder at hNot
  push_neg at hNot
  rcases hNot with
    ⟨continuation, question, hAllowed, hVisible, hDifferent⟩
  exact
    ⟨(continuation, question),
      ⟨hAllowed, hVisible⟩,
      hDifferent⟩

/-! ## Finite quotient -> finite characterizing set -/

/-- A summary code actually realized by at least one retained state. -/
def RealizedSummary
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary) :=
  { summary : Summary // ∃ state, encode state = summary }

noncomputable def realizedRepresentative
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary)
    (summary : RealizedSummary encode) : State :=
  Classical.choose summary.property

theorem encode_realizedRepresentative
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary)
    (summary : RealizedSummary encode) :
    encode (realizedRepresentative encode summary) = summary.1 :=
  Classical.choose_spec summary.property

/-- Two distinct realized quotient codes. -/
def DistinctRealizedPair
    {State : Type uS}
    {Summary : Type uM}
    (encode : State → Summary) :=
  { pair : RealizedSummary encode × RealizedSummary encode //
      pair.1 ≠ pair.2 }

noncomputable def distinguishingContextForRealizedPair
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hExact :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary encode)
    (pair : DistinctRealizedPair encode) :
    Loam.Observation314.FutureContext Operation Question := by
  have hNot :
      ¬ Loam.Observation312.FutureEquivalentUnder
        answer step operationVocabulary questionVocabulary
        (realizedRepresentative encode pair.1.1)
        (realizedRepresentative encode pair.1.2) := by
    intro hFuture
    have hEncode :=
      (hExact
        (realizedRepresentative encode pair.1.1)
        (realizedRepresentative encode pair.1.2)).2 hFuture
    have hValues : pair.1.1.1 = pair.1.2.1 := by
      calc
        pair.1.1.1 =
            encode (realizedRepresentative encode pair.1.1) :=
          (encode_realizedRepresentative encode pair.1.1).symm
        _ =
            encode (realizedRepresentative encode pair.1.2) :=
          hEncode
        _ = pair.1.2.1 :=
          encode_realizedRepresentative encode pair.1.2
    exact pair.2 (Subtype.ext hValues)
  exact
    Classical.choose
      (exists_distinguishing_context_of_not_futureEquivalentUnder
        answer step operationVocabulary questionVocabulary hNot)

theorem distinguishingContextForRealizedPair_spec
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hExact :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary encode)
    (pair : DistinctRealizedPair encode) :
    Loam.Observation314.ContextAllowedUnder
        operationVocabulary questionVocabulary
        (distinguishingContextForRealizedPair
          answer step operationVocabulary questionVocabulary encode hExact pair) ∧
      Loam.Observation314.contextAnswer
          answer step
          (realizedRepresentative encode pair.1.1)
          (distinguishingContextForRealizedPair
            answer step operationVocabulary questionVocabulary encode hExact pair) ≠
        Loam.Observation314.contextAnswer
          answer step
          (realizedRepresentative encode pair.1.2)
          (distinguishingContextForRealizedPair
            answer step operationVocabulary questionVocabulary encode hExact pair) := by
  unfold distinguishingContextForRealizedPair
  apply Classical.choose_spec

/--
Enumerate one selected distinguishing context for every pair of distinct
realized quotient classes.
-/
noncomputable def quotientCharacterizingContexts
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [Fintype Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hExact :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary encode) :
    List (Loam.Observation314.FutureContext Operation Question) := by
  classical
  letI : Fintype (RealizedSummary encode) := Fintype.ofFinite _
  letI : Fintype (DistinctRealizedPair encode) := Fintype.ofFinite _
  exact
    (Finset.univ.toList :
      List (DistinctRealizedPair encode)).map
        (distinguishingContextForRealizedPair
          answer step operationVocabulary questionVocabulary encode hExact)

/--
A finite exact quotient always yields a finite future-characterizing set.

Raw State is unrestricted. Finiteness is required only of the exact behavioural
summary.
-/
theorem finiteFutureQuotient_has_finite_characterizing_set
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (encode : State → Summary)
    (hFinite : Finite Summary)
    (hExact :
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary encode) :
    ∃ contexts,
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts := by
  classical
  letI : Finite Summary := hFinite
  letI : Fintype Summary := Fintype.ofFinite Summary
  let contexts :=
    quotientCharacterizingContexts
      answer step operationVocabulary questionVocabulary encode hExact
  refine ⟨contexts, ?_⟩
  constructor
  · intro context hMem
    dsimp [contexts] at hMem
    rw [quotientCharacterizingContexts] at hMem
    rcases List.mem_map.mp hMem with ⟨pair, _, rfl⟩
    exact
      (distinguishingContextForRealizedPair_spec
        answer step operationVocabulary questionVocabulary encode hExact pair).1
  · intro left right
    constructor
    · intro hSame
      apply (hExact left right).1
      by_contra hEncode
      let leftCode : RealizedSummary encode :=
        ⟨encode left, ⟨left, rfl⟩⟩
      let rightCode : RealizedSummary encode :=
        ⟨encode right, ⟨right, rfl⟩⟩
      have hCodes : leftCode ≠ rightCode := by
        intro h
        apply hEncode
        exact congrArg Subtype.val h
      let pair : DistinctRealizedPair encode :=
        ⟨(leftCode, rightCode), hCodes⟩
      let context :=
        distinguishingContextForRealizedPair
          answer step operationVocabulary questionVocabulary encode hExact pair
      have hPairMem :
          pair ∈
            (Finset.univ.toList :
              List (DistinctRealizedPair encode)) := by
        simp
      have hContextMem : context ∈ contexts := by
        dsimp [contexts, quotientCharacterizingContexts, context]
        exact List.mem_map.mpr ⟨pair, hPairMem, rfl⟩
      have hAllowed :
          Loam.Observation314.ContextAllowedUnder
            operationVocabulary questionVocabulary context :=
        (distinguishingContextForRealizedPair_spec
          answer step operationVocabulary questionVocabulary encode hExact pair).1
      have hRepresentativeDifferent :
          Loam.Observation314.contextAnswer
              answer step
              (realizedRepresentative encode pair.1.1)
              context ≠
            Loam.Observation314.contextAnswer
              answer step
              (realizedRepresentative encode pair.1.2)
              context :=
        (distinguishingContextForRealizedPair_spec
          answer step operationVocabulary questionVocabulary encode hExact pair).2
      have hLeftEncode :
          encode left =
            encode (realizedRepresentative encode pair.1.1) := by
        calc
          encode left = pair.1.1.1 := rfl
          _ = encode (realizedRepresentative encode pair.1.1) :=
            (encode_realizedRepresentative encode pair.1.1).symm
      have hRightEncode :
          encode right =
            encode (realizedRepresentative encode pair.1.2) := by
        calc
          encode right = pair.1.2.1 := rfl
          _ = encode (realizedRepresentative encode pair.1.2) :=
            (encode_realizedRepresentative encode pair.1.2).symm
      have hLeftFuture :=
        (hExact
          left
          (realizedRepresentative encode pair.1.1)).1 hLeftEncode
      have hRightFuture :=
        (hExact
          right
          (realizedRepresentative encode pair.1.2)).1 hRightEncode
      have hLeftAnswer :
          Loam.Observation314.contextAnswer answer step left context =
            Loam.Observation314.contextAnswer
              answer step
              (realizedRepresentative encode pair.1.1)
              context := by
        exact
          hLeftFuture
            context.1 context.2 hAllowed.1 hAllowed.2
      have hRightAnswer :
          Loam.Observation314.contextAnswer answer step right context =
            Loam.Observation314.contextAnswer
              answer step
              (realizedRepresentative encode pair.1.2)
              context := by
        exact
          hRightFuture
            context.1 context.2 hAllowed.1 hAllowed.2
      have hCurrentSame := hSame context hContextMem
      exact
        hRepresentativeDifferent
          (hLeftAnswer.symm.trans
            (hCurrentSame.trans hRightAnswer))
    · intro hFuture context hMem
      have hAllowed : Loam.Observation314.ContextAllowedUnder
          operationVocabulary questionVocabulary context := by
        dsimp [contexts] at hMem
        rw [quotientCharacterizingContexts] at hMem
        rcases List.mem_map.mp hMem with ⟨pair, _, rfl⟩
        exact
          (distinguishingContextForRealizedPair_spec
            answer step operationVocabulary questionVocabulary encode hExact pair).1
      exact
        hFuture
          context.1 context.2 hAllowed.1 hAllowed.2

/-! ## Finite characterizing set + finite answers -> finite quotient -/

/--
Finite answer tuples indexed only by the number of selected contexts.
-/
def FiniteAnswerProfile
    (Answer : Type uA) : Nat → Type uA
  | 0 => PUnit
  | n + 1 => Answer × FiniteAnswerProfile Answer n

def finiteAnswerProfileFintype
    {Answer : Type uA}
    [Fintype Answer] :
    (n : Nat) → Fintype (FiniteAnswerProfile Answer n)
  | 0 => inferInstance
  | n + 1 =>
      letI := finiteAnswerProfileFintype n
      inferInstance

/--
Encode the answers to a finite context list into a nested finite tuple.
-/
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

/--
Equality of finite tuples is exactly equality on every listed future context.
-/
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
      simp [finiteContextProfile, Loam.Observation315.EquivalentOnContexts]
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
A finite characterizing set with a finite answer type produces a finite exact
future quotient. The quotient code is simply the finite answer tuple over the
characterizing contexts.
-/
theorem finite_characterizing_set_has_finite_future_quotient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    [Fintype Answer]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (operationVocabulary : Loam.Observation312.OperationVocabulary Operation)
    (questionVocabulary : Loam.Observation029.Vocabulary Question)
    (contexts : List (Loam.Observation314.FutureContext Operation Question))
    (hCharacterizing :
      Loam.Observation315.FutureCharacterizingSetUnder
        answer step operationVocabulary questionVocabulary contexts) :
    ∃ hFinite : Finite (FiniteAnswerProfile Answer contexts.length),
      Loam.Observation312.ExactFutureClassifierUnder
        answer step operationVocabulary questionVocabulary
        (finiteContextProfile answer step contexts) := by
  letI : Fintype (FiniteAnswerProfile Answer contexts.length) :=
    finiteAnswerProfileFintype contexts.length
  refine ⟨by infer_instance, ?_⟩
  intro left right
  rw [finiteContextProfile_eq_iff_equivalentOnContexts]
  exact hCharacterizing.2 left right

/-!
## Finding

The finite-characterization story can now be stated without assuming that the
raw retained state space is finite.

Forward:

    finite exact behavioural summary
      -> finitely many realized summary classes
      -> choose one distinguishing future context per distinct class pair
      -> finite FutureCharacterizingSetUnder

Reverse, when answers are finite:

    finite FutureCharacterizingSetUnder
      -> finite answer tuple
      -> ExactFutureClassifierUnder into a finite type

So the central finiteness boundary is behavioural:

    raw State may be unbounded
              |
              v
      FutureEquivalentUnder
              |
              v
       finite quotient
              |
              v
    finite distinguishing profile

This should not be read as a new Myhill-Nerode theorem. The finite-index /
finite-distinguishing-set relationship is classical territory. The useful LOAM
result is that the same shape is now explicit and Lean-certified for the
retained-evidence future semantics already developed in Observations 192–316.

The next step should therefore be comparative rather than immediately adding
another semantic family: line up this exact theorem boundary against
characterization sets, Nerode finite index, and observational-completeness
results, then identify what remains specifically about retained evidence and
future-operation vocabularies.
-/

end Loam.Observation317
