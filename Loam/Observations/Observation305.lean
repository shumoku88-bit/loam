import Loam.Observations.Observation304

namespace Loam.Observation305

set_option autoImplicit false

/-!
# Observation 305 — the three behavioural retention classes

Observation 304 proved that a three-bit summary is FutureSufficient for one
declared ActualReversal vocabulary:

- future operation: publish the fixed A -> B reversal;
- selected question: is A already reversed?

Those three bits are operational evidence, but they are not yet the smallest
semantic description of future behaviour.

For this vocabulary, every retained state falls into one of three behavioural
classes:

1. alreadyReversed — the selected answer is already true;
2. blocked — the selected answer is false and publishing A -> B cannot change it;
3. available — the selected answer is false and publishing A -> B changes it to true.

This observation proves that the three-class summary is FutureSufficient and
that any FutureSufficient summary must assign different codes to three concrete
witness states exhibiting those behaviours.

The lower bound is behavioural, not a claim that this is a universal minimal
encoding for arbitrary reversal vocabularies.
-/

inductive RetentionClass where
  | alreadyReversed
  | blocked
  | available
  deriving Repr, DecidableEq

/-- Collapse the operational three-bit summary to its selected future behaviour. -/
def classOfSummary
    (summary : Loam.Observation304.Summary) : RetentionClass :=
  if summary.aIsReversed then
    .alreadyReversed
  else if summary.aUsed || summary.bUsed then
    .blocked
  else
    .available

/-- Behavioural retention summary over the existing Observation-304 state. -/
def encode
    (state : Loam.Observation304.State) : RetentionClass :=
  classOfSummary (Loam.Observation304.encode state)

/-- Decode the selected current answer directly from the behavioural class. -/
def decodeCurrent :
    RetentionClass → Loam.Observation304.Question → Bool
  | .alreadyReversed, .aIsReversed => true
  | .blocked, .aIsReversed => false
  | .available, .aIsReversed => false

private theorem decode_classOfSummary
    (summary : Loam.Observation304.Summary) :
    decodeCurrent (classOfSummary summary) .aIsReversed =
      summary.aIsReversed := by
  cases summary with
  | mk aUsed bUsed aIsReversed =>
      cases aUsed <;> cases bUsed <;> cases aIsReversed <;>
        native_decide

theorem decodeCurrent_encode
    (state : Loam.Observation304.State) :
    decodeCurrent (encode state) .aIsReversed =
      Loam.Observation304.answer state .aIsReversed := by
  change
    decodeCurrent
        (classOfSummary (Loam.Observation304.encode state))
        .aIsReversed =
      Loam.Observation304.answer state .aIsReversed
  rw [decode_classOfSummary]
  rfl

theorem encode_is_currently_sufficient :
    Loam.Observation029.SufficientFor
      Loam.Observation304.answer
      Loam.Observation304.Vocabulary
      encode := by
  refine ⟨decodeCurrent, ?_⟩
  intro state question _
  cases question
  exact decodeCurrent_encode state

/--
The semantic transition has only one interesting edge:

    available --publishAB--> alreadyReversed

The other two classes are stable.
-/
def summaryStep :
    RetentionClass → Loam.Observation304.Operation → RetentionClass
  | .alreadyReversed, .publishAB => .alreadyReversed
  | .blocked, .publishAB => .blocked
  | .available, .publishAB => .alreadyReversed

private theorem summaryStep_classOfSummary
    (summary : Loam.Observation304.Summary) :
    summaryStep (classOfSummary summary) .publishAB =
      classOfSummary
        (Loam.Observation304.summaryStep summary .publishAB) := by
  cases summary with
  | mk aUsed bUsed aIsReversed =>
      cases aUsed <;> cases bUsed <;> cases aIsReversed <;>
        native_decide

/-- The behavioural transition commutes with the retained-state transition. -/
theorem summaryStep_commutes
    (state : Loam.Observation304.State)
    (operation : Loam.Observation304.Operation) :
    summaryStep (encode state) operation =
      encode (Loam.Observation304.step state operation) := by
  cases operation
  calc
    summaryStep (encode state) .publishAB =
        classOfSummary
          (Loam.Observation304.summaryStep
            (Loam.Observation304.encode state) .publishAB) :=
      summaryStep_classOfSummary (Loam.Observation304.encode state)
    _ =
        classOfSummary
          (Loam.Observation304.encode
            (Loam.Observation304.step state .publishAB)) :=
      congrArg classOfSummary
        (Loam.Observation304.summaryStep_commutes state .publishAB)
    _ = encode (Loam.Observation304.step state .publishAB) := rfl

/-- The three behavioural classes are exactly locally maintainable. -/
theorem encode_is_updateIndependent :
    Loam.Observation297.UpdateIndependent
      Loam.Observation304.step encode :=
  ⟨summaryStep, summaryStep_commutes⟩

theorem retentionCertificate :
    Loam.Observation298.MaintainedCertificate
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      encode :=
  { current := encode_is_currently_sufficient
    update := encode_is_updateIndependent }

theorem encode_is_futureSufficient :
    Loam.Observation192.FutureSufficient
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      encode :=
  retentionCertificate.futureSufficient

def retentionVerdict :
    Loam.Observation298.RetentionVerdict
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      encode :=
  .preserved encode_is_futureSufficient

/-- The behavioural class still genuinely discards retained source detail. -/
theorem encode_is_not_injective :
    ¬ Function.Injective encode := by
  intro hClassInjective
  apply Loam.Observation304.encode_is_not_injective
  intro left right hOperationalSummary
  apply hClassInjective
  exact congrArg classOfSummary hOperationalSummary

/-! ## Three concrete future behaviours -/

theorem available_witness_class :
    encode Loam.Observation304.availableWitnessState =
      .available := by
  native_decide

theorem blocked_witness_class :
    encode Loam.Observation304.blockedWitnessState =
      .blocked := by
  native_decide

theorem already_reversed_witness_class :
    encode Loam.Observation304.alreadyReversedWitnessState =
      .alreadyReversed := by
  native_decide

private theorem available_current_answer :
    Loam.Observation304.answer
        Loam.Observation304.availableWitnessState .aIsReversed =
      false := by
  native_decide

private theorem blocked_current_answer :
    Loam.Observation304.answer
        Loam.Observation304.blockedWitnessState .aIsReversed =
      false := by
  native_decide

private theorem already_reversed_current_answer :
    Loam.Observation304.answer
        Loam.Observation304.alreadyReversedWitnessState .aIsReversed =
      true := by
  native_decide

private theorem available_after_publish_answer :
    Loam.Observation304.answer
        (Loam.Observation304.step
          Loam.Observation304.availableWitnessState .publishAB)
        .aIsReversed =
      true := by
  native_decide

private theorem blocked_after_publish_answer :
    Loam.Observation304.answer
        (Loam.Observation304.step
          Loam.Observation304.blockedWitnessState .publishAB)
        .aIsReversed =
      false := by
  native_decide

theorem available_not_futureEquivalent_blocked :
    ¬ Loam.Observation192.FutureEquivalent
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation304.availableWitnessState
      Loam.Observation304.blockedWitnessState := by
  intro hFuture
  have hAfter :=
    hFuture [.publishAB] .aIsReversed
      (by simp [Loam.Observation304.Vocabulary])
  change
    Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.availableWitnessState
          [.publishAB])
        .aIsReversed =
      Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.blockedWitnessState
          [.publishAB])
        .aIsReversed
    at hAfter
  simp [Loam.Observation192.run] at hAfter
  rw [available_after_publish_answer, blocked_after_publish_answer] at hAfter
  simp at hAfter

theorem available_not_futureEquivalent_alreadyReversed :
    ¬ Loam.Observation192.FutureEquivalent
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation304.availableWitnessState
      Loam.Observation304.alreadyReversedWitnessState := by
  intro hFuture
  have hNow :=
    hFuture [] .aIsReversed
      (by simp [Loam.Observation304.Vocabulary])
  change
    Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.availableWitnessState [])
        .aIsReversed =
      Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.alreadyReversedWitnessState [])
        .aIsReversed
    at hNow
  simp [Loam.Observation192.run] at hNow
  rw [available_current_answer, already_reversed_current_answer] at hNow
  simp at hNow

theorem blocked_not_futureEquivalent_alreadyReversed :
    ¬ Loam.Observation192.FutureEquivalent
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      Loam.Observation304.blockedWitnessState
      Loam.Observation304.alreadyReversedWitnessState := by
  intro hFuture
  have hNow :=
    hFuture [] .aIsReversed
      (by simp [Loam.Observation304.Vocabulary])
  change
    Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.blockedWitnessState [])
        .aIsReversed =
      Loam.Observation304.answer
        (Loam.Observation192.run
          Loam.Observation304.step
          Loam.Observation304.alreadyReversedWitnessState [])
        .aIsReversed
    at hNow
  simp [Loam.Observation192.run] at hNow
  rw [blocked_current_answer, already_reversed_current_answer] at hNow
  simp at hNow

/-!
Any future-sufficient summary must keep these three behaviours separate.

This is a representation-independent lower bound: it does not say another
summary must use the same fields or constructors, only that it needs at least
three distinct codes on these three concrete future behaviours.
-/
universe uM

theorem every_futureSufficient_summary_separates_three_behaviours
    {Summary : Type uM}
    (candidate : Loam.Observation304.State → Summary)
    (hSufficient :
      Loam.Observation192.FutureSufficient
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        candidate) :
    candidate Loam.Observation304.availableWitnessState ≠
        candidate Loam.Observation304.blockedWitnessState ∧
      candidate Loam.Observation304.availableWitnessState ≠
        candidate Loam.Observation304.alreadyReversedWitnessState ∧
      candidate Loam.Observation304.blockedWitnessState ≠
        candidate Loam.Observation304.alreadyReversedWitnessState := by
  constructor
  · intro hEqual
    exact available_not_futureEquivalent_blocked
      (Loam.Observation192.equalFutureSummaryInvisible
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        hSufficient hEqual)
  · constructor
    · intro hEqual
      exact available_not_futureEquivalent_alreadyReversed
        (Loam.Observation192.equalFutureSummaryInvisible
          Loam.Observation304.answer
          Loam.Observation304.step
          Loam.Observation304.Vocabulary
          hSufficient hEqual)
    · intro hEqual
      exact blocked_not_futureEquivalent_alreadyReversed
        (Loam.Observation192.equalFutureSummaryInvisible
          Loam.Observation304.answer
          Loam.Observation304.step
          Loam.Observation304.Vocabulary
          hSufficient hEqual)

/-!
## Finding

For the selected ActualReversal future vocabulary, the retention problem has a
small behavioural shape:

    available
       |
       | publish A -> B
       v
    alreadyReversed

    blocked ----------> blocked
    alreadyReversed --> alreadyReversed

The complete reversal history and even Observation 304's three operational bits
contain more representational detail than this future vocabulary needs.

The three-class summary is:

- non-injective over retained source states;
- currently sufficient;
- exactly locally maintainable;
- therefore FutureSufficient.

The three concrete witnesses also give a matching behavioural lower bound:
every FutureSufficient summary must assign them pairwise distinct codes.

This does not prove a universal minimal encoding theorem for ActualReversal.
It does show, for one declared operation/question vocabulary, both sides of the
retention problem:

    upper bound: three behavioural classes are sufficient
    lower bound: three pairwise distinguishable behaviours must remain separate

That is closer to answering "what information must survive?" than merely finding
a safe summary or merely finding an unsafe one.
-/

end Loam.Observation305
