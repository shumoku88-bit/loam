import Loam.Observations.Observation193

namespace Loam.Observation194

open Loam.Core

set_option autoImplicit false

/-!
# Observation 194 — Fail-closed future definedness

Observation 193 showed that one real future `EventCorrection` can distinguish two
currently equal correction-frontier quantities. This observation asks a sharper
question:

> Can two worlds with exactly the same retained Event evidence and the same
> current correction-frontier answer differ only in hidden Correction topology,
> such that the same future Correction leaves one world defined and makes the
> other fail closed?

The witness deliberately uses only the existing Correction operation and the
existing `CorrectionFrontier` admission boundary. No production semantics are
changed.
-/

private def wallet : LocusId := ⟨"wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def oneEffectEvent
    (idToken effectToken : String)
    (quanta : Int) : Event :=
  { id := ⟨idToken⟩
    effects :=
      [Effect.ofQuantity
        ⟨effectToken⟩ wallet jpy (Quantity.ofQuanta quanta)]
    keyNodup := by simp }

private def sharedEvents : EventMemory :=
  { events :=
      [ oneEffectEvent "a" "a-effect" (-10)
      , oneEffectEvent "b" "b-effect" 10
      , oneEffectEvent "c" "c-effect" (-10)
      , oneEffectEvent "d" "d-effect" 10
      ]
    idNodup := by native_decide }

private def leftBaseCorrection : EventCorrection :=
  { id := ⟨"base-correction"⟩
    target := ⟨"a"⟩
    replacement := ⟨"b"⟩ }

private def rightBaseCorrection : EventCorrection :=
  { id := ⟨"base-correction"⟩
    target := ⟨"c"⟩
    replacement := ⟨"d"⟩ }

private def leftCorrections : EventCorrectionMemory :=
  { corrections := [leftBaseCorrection]
    idNodup := by simp }

private def rightCorrections : EventCorrectionMemory :=
  { corrections := [rightBaseCorrection]
    idNodup := by simp }

private def leftState : Loam.Observation193.CorrectionState :=
  { events := sharedEvents, corrections := leftCorrections }

private def rightState : Loam.Observation193.CorrectionState :=
  { events := sharedEvents, corrections := rightCorrections }

private def futureCorrection : EventCorrection :=
  { id := ⟨"future-correction"⟩
    target := ⟨"b"⟩
    replacement := ⟨"a"⟩ }

private def publishFuture : Loam.Observation193.CorrectionOperation :=
  .publish futureCorrection

/-- The two worlds retain exactly the same physical Event evidence. -/
theorem event_evidence_is_identical :
    leftState.events = rightState.events := by
  rfl

/-- Each current one-edge Correction relation is independently admissible. -/
theorem left_is_currently_admissible :
    Loam.Application.correctionFrontierAdmissible
      leftState.events leftState.corrections = true := by
  native_decide

theorem right_is_currently_admissible :
    Loam.Application.correctionFrontierAdmissible
      rightState.events rightState.corrections = true := by
  native_decide

/-- Different current frontiers nevertheless answer the selected quantity equally. -/
theorem left_current_answer :
    Loam.Observation193.correctionAnswer
      leftState .walletQuantity = some 10 := by
  native_decide

theorem right_current_answer :
    Loam.Observation193.correctionAnswer
      rightState .walletQuantity = some 10 := by
  native_decide

/-- The current Observation-029 vocabulary cannot distinguish the two worlds. -/
theorem states_are_currently_equivalent :
    Loam.Observation029.Equivalent
      Loam.Observation193.correctionAnswer
      Loam.Observation193.CorrectionVocabulary
      leftState rightState := by
  intro question _
  cases question
  rw [left_current_answer, right_current_answer]

/-!
## Same future relation, different semantic availability

Appending `b -> a` closes a cycle only in the left world:

```text
left:  a -> b -> a      cycle
right: c -> d   b -> a  disjoint finite paths
```

The raw transition itself remains total and merely retains the new relation fact.
Fail-closed semantic availability is decided later by `CorrectionFrontier`.
-/

/-- The same future Correction makes the left relation graph inadmissible. -/
theorem left_after_future_is_inadmissible :
    Loam.Application.correctionFrontierAdmissible
      (Loam.Observation193.correctionStep leftState publishFuture).events
      (Loam.Observation193.correctionStep leftState publishFuture).corrections = false := by
  native_decide

/-- The right relation graph remains a collection of disjoint finite paths. -/
theorem right_after_future_is_admissible :
    Loam.Application.correctionFrontierAdmissible
      (Loam.Observation193.correctionStep rightState publishFuture).events
      (Loam.Observation193.correctionStep rightState publishFuture).corrections = true := by
  native_decide

/-- Fail-closed frontier projection therefore returns no answer on the left. -/
theorem left_after_future_answer :
    Loam.Observation193.correctionAnswer
      (Loam.Observation193.correctionStep leftState publishFuture)
      .walletQuantity = none := by
  native_decide

/-- The same future operation remains defined on the right and yields quantity zero. -/
theorem right_after_future_answer :
    Loam.Observation193.correctionAnswer
      (Loam.Observation193.correctionStep rightState publishFuture)
      .walletQuantity = some 0 := by
  native_decide

/--
Current equality is strictly weaker than future-context equality even when the
future distinction is semantic definedness rather than two different quantities.
-/
theorem states_are_not_futureEquivalent :
    ¬ Loam.Observation192.FutureEquivalent
      Loam.Observation193.correctionAnswer
      Loam.Observation193.correctionStep
      Loam.Observation193.CorrectionVocabulary
      leftState rightState := by
  intro hFuture
  have hAfter :=
    hFuture [publishFuture] .walletQuantity
      (by simp [Loam.Observation193.CorrectionVocabulary])
  change
    Loam.Observation193.correctionAnswer
        (Loam.Observation193.correctionStep leftState publishFuture)
        .walletQuantity =
      Loam.Observation193.correctionAnswer
        (Loam.Observation193.correctionStep rightState publishFuture)
        .walletQuantity
    at hAfter
  rw [left_after_future_answer, right_after_future_answer] at hAfter
  simp at hAfter

/-- The distinguishing operation still leaves the shared Event evidence untouched. -/
theorem event_evidence_remains_identical_after_future :
    (Loam.Observation193.correctionStep leftState publishFuture).events =
      (Loam.Observation193.correctionStep rightState publishFuture).events := by
  rw [Loam.Observation193.correctionStep_preserves_events]
  rw [Loam.Observation193.correctionStep_preserves_events]
  exact event_evidence_is_identical

/-!
## Finding

Observation 193 established future quantitative distinction under real Correction
semantics. Observation 194 strengthens the boundary:

```text
same retained Event evidence
+ same current CorrectionFrontier answer
    does not imply
same future semantic availability
```

The decisive hidden state is retained relation topology. The same explicit future
Correction is harmless in one world and creates a cycle in the other. Existing
`CorrectionFrontier` refuses the cyclic world rather than inventing an ordering,
winner, or fallback answer.

For the contextual observation used by `FutureEquivalent`, `Option` definedness is
therefore observable structure:

```text
none != some quantity
```

This does not mean failure is an accounting quantity. It means a future-context
quotient must retain enough evidence to preserve not only future values but also
whether the selected semantic question remains admissible at all.

The result remains Correction-specific. It does not yet unify branching,
`EventResolution`, ActualValidity correction, routing, time, publication failure,
or manifest authority under one transition algebra. No new mathematical theorem
is claimed.
-/

end Loam.Observation194
