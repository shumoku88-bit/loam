import Loam.Observations.Observation305

namespace Loam.Observation306

set_option autoImplicit false

/-!
# Observation 306 — behavioural quotient equals future-context equivalence

Observation 305 derived three retention classes for one declared
ActualReversal future vocabulary:

- available;
- blocked;
- alreadyReversed.

It proved those classes are FutureSufficient and that three concrete witnesses
must remain pairwise separated by any FutureSufficient summary.

This observation closes the remaining gap for that vocabulary.

The three-class encoding is not merely sufficient. Equality of encoded classes
is exactly the same relation as FutureEquivalent.

The proof uses a two-answer behavioural signature:

    current selected answer
    answer after one publishAB

For the three classes those signatures are:

    available        -> (false, true)
    blocked          -> (false, false)
    alreadyReversed  -> (true,  true)

Because the only allowed operation is repeated publication of the same fixed
A -> B reversal, that signature is enough to identify the complete selected
future behaviour.
-/

/-- The two observations that identify the three behavioural classes. -/
def behaviourSignature
    (retentionClass : Loam.Observation305.RetentionClass) : Bool × Bool :=
  ( Loam.Observation305.decodeCurrent
      retentionClass .aIsReversed
  , Loam.Observation305.decodeCurrent
      (Loam.Observation305.summaryStep retentionClass .publishAB)
      .aIsReversed )

theorem available_signature :
    behaviourSignature .available = (false, true) := by
  rfl

theorem blocked_signature :
    behaviourSignature .blocked = (false, false) := by
  rfl

theorem alreadyReversed_signature :
    behaviourSignature .alreadyReversed = (true, true) := by
  rfl

/-- The current/one-step answer pair identifies each retention class uniquely. -/
theorem behaviourSignature_injective :
    Function.Injective behaviourSignature := by
  intro left right hEqual
  cases left <;> cases right <;>
    simp [behaviourSignature,
      Loam.Observation305.decodeCurrent,
      Loam.Observation305.summaryStep] at hEqual ⊢

/-- The class signature agrees with the retained state's actual two observations. -/
theorem behaviourSignature_encode
    (state : Loam.Observation304.State) :
    behaviourSignature (Loam.Observation305.encode state) =
      ( Loam.Observation304.answer state .aIsReversed
      , Loam.Observation304.answer
          (Loam.Observation304.step state .publishAB)
          .aIsReversed ) := by
  apply Prod.ext
  · exact Loam.Observation305.decodeCurrent_encode state
  · rw [behaviourSignature]
    change
      Loam.Observation305.decodeCurrent
          (Loam.Observation305.summaryStep
            (Loam.Observation305.encode state) .publishAB)
          .aIsReversed =
        Loam.Observation304.answer
          (Loam.Observation304.step state .publishAB)
          .aIsReversed
    rw [Loam.Observation305.summaryStep_commutes]
    exact
      Loam.Observation305.decodeCurrent_encode
        (Loam.Observation304.step state .publishAB)

/--
Equal behavioural classes imply equality under every selected future context.

This is the easy direction supplied by the already-proved FutureSufficient
certificate.
-/
theorem same_class_implies_futureEquivalent
    {left right : Loam.Observation304.State}
    (hClass :
      Loam.Observation305.encode left =
        Loam.Observation305.encode right) :
    Loam.Observation192.FutureEquivalent
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      left right :=
  Loam.Observation192.equalFutureSummaryInvisible
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    Loam.Observation305.encode_is_futureSufficient
    hClass

/--
Future-equivalent retained states must lie in the same behavioural class.

Only two selected observations are needed to recover the class: now, and after
one common publishAB operation.
-/
theorem futureEquivalent_implies_same_class
    {left right : Loam.Observation304.State}
    (hFuture :
      Loam.Observation192.FutureEquivalent
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        left right) :
    Loam.Observation305.encode left =
      Loam.Observation305.encode right := by
  apply Loam.Observation306.behaviourSignature_injective
  rw [behaviourSignature_encode, behaviourSignature_encode]
  apply Prod.ext
  · have hNow :=
      hFuture [] .aIsReversed
        (by simp [Loam.Observation304.Vocabulary])
    simpa [Loam.Observation192.run] using hNow
  · have hAfter :=
      hFuture [.publishAB] .aIsReversed
        (by simp [Loam.Observation304.Vocabulary])
    simpa [Loam.Observation192.run] using hAfter

/--
For the selected reversal vocabulary, the three-class encoding is exactly the
future-context quotient relation.
-/
theorem same_class_iff_futureEquivalent
    (left right : Loam.Observation304.State) :
    Loam.Observation305.encode left =
        Loam.Observation305.encode right ↔
      Loam.Observation192.FutureEquivalent
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        left right := by
  constructor
  · exact same_class_implies_futureEquivalent
  · exact futureEquivalent_implies_same_class

/-!
## Finding

For this declared future vocabulary:

    retained ActualReversal state
              |
              v
    FutureEquivalent quotient
              |
              v
       three classes
      /      |       \
 available blocked alreadyReversed

Observation 305 had already shown:

- the three classes are sufficient;
- all three behaviours are genuinely needed.

Observation 306 strengthens that to an exact relation:

    same retention class
        iff
    FutureEquivalent

So the three-class summary is not merely one safe compression among many.
Its fibers are exactly the behavioural equivalence classes induced by the
selected future operation/question vocabulary.

This remains a deliberately small, vocabulary-relative result. It does not
claim a generic minimization algorithm, finite-index theorem, or universal
ActualReversal quotient.

What it does establish is the complete local pattern that the broader retention
work has been approaching:

    retained evidence
        -> declared future vocabulary
        -> behavioural equivalence
        -> quotient classes
        -> safe semantic compression

That gives a concrete Lean-checked instance of "retain exactly the distinctions
the declared future can observe."
-/

end Loam.Observation306
