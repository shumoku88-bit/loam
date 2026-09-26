import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory

namespace Loam.Observation362

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 362 — settlement correction reuses ReplacementFrontier, but coupled reallocation needs more than row replacement

Observation 361 qualified the minimum correspondence payload:

    target commitment
    later Event
    later EffectKey
    exact settled Quantity

The next pressure corrects semantic attribution while leaving the physical
movement unchanged.

Selected history:

    one physical Effect = -1000 JPY

    original attribution
      A = 700
      B = 300

    corrected attribution
      A = 600
      B = 400

The physical Event is not corrected. Only the semantic correspondence changes.

This observation asks three separate questions:

1. Can ordinary one-to-one correspondence correction reuse generic
   ReplacementFrontier mechanics?
2. Does correction create real identity pressure for correspondence versions?
3. Is row-wise replacement sufficient when one user-visible correction intends
   a coupled 700/300 -> 600/400 redistribution?
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o362-settlement"⟩
private def settlementEffectKey : EffectKey := ⟨"o362-bank-debit"⟩

private def settlementEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      settlementEffectKey bank yen (Quantity.ofQuanta (-1000))
  ]

private def events? : Option EventMemory := do
  let settlement ← settlementEvent?
  EventMemory.ofEvents? [settlement]

structure CommitmentId where
  token : String
deriving Repr, DecidableEq

private def commitmentA : CommitmentId := ⟨"commitment-a"⟩
private def commitmentB : CommitmentId := ⟨"commitment-b"⟩

structure Commitment where
  id : CommitmentId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def commitments : List Commitment := [
  ⟨commitmentA, yen, Quantity.ofQuanta 800⟩,
  ⟨commitmentB, yen, Quantity.ofQuanta 800⟩
]

inductive CorrespondenceId where
  | originalA
  | originalB
  | correctedA
  | correctedB
  | alternativeA
deriving Repr, DecidableEq

structure SettlementCorrespondence where
  id : CorrespondenceId
  target : CommitmentId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

private def originalA : SettlementCorrespondence := {
  id := .originalA
  target := commitmentA
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 700
}

private def originalB : SettlementCorrespondence := {
  id := .originalB
  target := commitmentB
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 300
}

private def correctedA : SettlementCorrespondence := {
  id := .correctedA
  target := commitmentA
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 600
}

private def correctedB : SettlementCorrespondence := {
  id := .correctedB
  target := commitmentB
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 400
}

private def alternativeA : SettlementCorrespondence := {
  id := .alternativeA
  target := commitmentA
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 650
}

private def findCommitment?
    (id : CommitmentId) : Option Commitment :=
  commitments.find? fun commitment => commitment.id = id

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

private def targetSettledTotal
    (rows : List SettlementCorrespondence)
    (target : CommitmentId) : Int :=
  rows.foldl
    (fun total row =>
      if row.target = target then total + row.quantity.quanta else total)
    0

private def effectSettledTotal
    (rows : List SettlementCorrespondence)
    (event : EventId)
    (effect : EffectKey) : Int :=
  rows.foldl
    (fun total row =>
      if row.event = event && row.effect = effect then
        total + row.quantity.quanta
      else
        total)
    0

private def rowLocallyAdmissible
    (memory : EventMemory)
    (row : SettlementCorrespondence) : Bool :=
  match findCommitment? row.target, memory.findById? row.event with
  | some target, some event =>
      match findEffectByKey? event row.effect with
      | none => false
      | some physical =>
          row.quantity.quanta > 0 &&
          target.quantity.quanta > 0 &&
          physical.measure = target.measure &&
          physical.quantity.quanta < 0 &&
          row.quantity.quanta <= target.quantity.quanta &&
          row.quantity.quanta <= magnitudeQuanta physical.quantity
  | _, _ => false

private def correspondenceSetAdmissible
    (memory : EventMemory)
    (rows : List SettlementCorrespondence) : Bool :=
  rows.all (rowLocallyAdmissible memory) &&
  commitments.all fun target =>
    targetSettledTotal rows target.id <= target.quantity.quanta &&
  rows.all fun row =>
    match memory.findById? row.event with
    | none => false
    | some event =>
        match findEffectByKey? event row.effect with
        | none => false
        | some physical =>
            effectSettledTotal rows row.event row.effect <=
              magnitudeQuanta physical.quantity

private def outstanding
    (rows : List SettlementCorrespondence)
    (target : CommitmentId) : Int :=
  match findCommitment? target with
  | none => 0
  | some commitment =>
      commitment.quantity.quanta - targetSettledTotal rows target

/-!
## Pressure 1 — coordinate identity is insufficient once correction exists
-/

structure CorrespondenceCoordinate where
  target : CommitmentId
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def coordinate
    (row : SettlementCorrespondence) : CorrespondenceCoordinate := {
  target := row.target
  event := row.event
  effect := row.effect
}

theorem corrected_row_keeps_same_semantic_coordinate :
    coordinate originalA = coordinate correctedA ∧
    originalA ≠ correctedA := by
  native_decide

/--
If the semantic coordinate itself is used as replacement identity, correcting
700 -> 600 becomes a self-loop and generic ReplacementFrontier correctly
rejects it.

So correction requires either distinct retained version identity or a different
revision encoding that can distinguish old and new payloads.
-/
private def coordinatePresent
    (id : CorrespondenceCoordinate) : Bool :=
  decide (id = coordinate originalA)

private def coordinateSelfReplacement :
    List (ReplacementFrontier.Edge CorrespondenceCoordinate) := [
  {
    source := coordinate originalA
    successor := coordinate correctedA
  }
]

theorem coordinate_only_identity_cannot_name_two_versions :
    coordinateSelfReplacement = [
      {
        source := coordinate originalA
        successor := coordinate originalA
      }
    ] ∧
    ReplacementFrontier.structurallyAdmissible
      coordinatePresent coordinateSelfReplacement = false := by
  native_decide

/-!
## Pressure 2 — version identity lets ReplacementFrontier reuse its mechanics
-/

private structure CorrespondenceHistory where
  retained : List SettlementCorrespondence
  replacements : List (ReplacementFrontier.Edge CorrespondenceId)

private def present
    (history : CorrespondenceHistory)
    (id : CorrespondenceId) : Bool :=
  history.retained.any fun row => decide (row.id = id)

private def currentRows?
    (history : CorrespondenceHistory) :
    Option (List SettlementCorrespondence) :=
  if ReplacementFrontier.structurallyAdmissible
      (present history) history.replacements then
    some (ReplacementFrontier.frontier
      SettlementCorrespondence.id history.retained history.replacements)
  else
    none

private def originalHistory : CorrespondenceHistory := {
  retained := [originalA, originalB]
  replacements := []
}

private def correctedHistory : CorrespondenceHistory := {
  retained := [originalA, originalB, correctedA, correctedB]
  replacements := [
    { source := .originalA, successor := .correctedA },
    { source := .originalB, successor := .correctedB }
  ]
}

theorem generic_replacement_frontier_carries_complete_reallocation :
    currentRows? originalHistory = some [originalA, originalB] ∧
    currentRows? correctedHistory = some [correctedA, correctedB] := by
  native_decide

theorem old_and_corrected_views_are_both_physically_admissible :
    (do
      let memory ← events?
      pure (
        correspondenceSetAdmissible memory [originalA, originalB],
        correspondenceSetAdmissible memory [correctedA, correctedB])) =
      some (true, true) := by
  native_decide

theorem complete_reallocation_changes_only_semantic_attribution :
    outstanding [originalA, originalB] commitmentA = 100 ∧
    outstanding [originalA, originalB] commitmentB = 500 ∧
    outstanding [correctedA, correctedB] commitmentA = 200 ∧
    outstanding [correctedA, correctedB] commitmentB = 400 ∧
    effectSettledTotal [originalA, originalB]
      settlementEventId settlementEffectKey = 1000 ∧
    effectSettledTotal [correctedA, correctedB]
      settlementEventId settlementEffectKey = 1000 := by
  native_decide

/--
Ordinary sibling replacement conflict remains fail-closed without a
settlement-specific conflict rule.
-/
private def competingAHistory : CorrespondenceHistory := {
  retained := [originalA, correctedA, alternativeA]
  replacements := [
    { source := .originalA, successor := .correctedA },
    { source := .originalA, successor := .alternativeA }
  ]
}

theorem competing_correspondence_corrections_reuse_generic_conflict_refusal :
    ReplacementFrontier.structurallyAdmissible
      (present competingAHistory)
      competingAHistory.replacements = false ∧
    currentRows? competingAHistory = none := by
  native_decide

/-!
## Pressure 3 — independent row replacement does not encode coupled intent
-/

/--
A possible publication prefix after correcting only A.

Nothing is malformed:

    original B = 300
    corrected A = 600
    aggregate physical attribution = 900

The generic replacement frontier therefore has no reason to reject it.
-/
private def halfCorrectedHistory : CorrespondenceHistory := {
  retained := [originalA, originalB, correctedA]
  replacements := [
    { source := .originalA, successor := .correctedA }
  ]
}

theorem half_correction_is_structurally_valid_row_history :
    currentRows? halfCorrectedHistory = some [originalB, correctedA] := by
  native_decide

theorem half_correction_is_also_numerically_admissible :
    (do
      let memory ← events?
      pure (correspondenceSetAdmissible memory [originalB, correctedA])) =
      some true := by
  native_decide

theorem half_correction_publishes_neither_old_nor_intended_complete_split :
    effectSettledTotal [originalB, correctedA]
      settlementEventId settlementEffectKey = 900 ∧
    [originalB, correctedA] ≠ [originalA, originalB] ∧
    [originalB, correctedA] ≠ [correctedA, correctedB] := by
  native_decide

/-!
## Finding

Generic ReplacementFrontier is sufficient for the structural mechanics of one
settlement-correspondence correction.

It already supplies:

    append-only retained old/new rows
    one-to-one supersession
    closed references
    acyclicity
    sibling-conflict refusal
    current frontier filtering

No settlement-specific mutable update engine is needed.

But two new boundaries appear.

### 1. Correction earns correspondence-version identity pressure

Before correction, one normalized row per:

    target + Event + EffectKey

was sufficient for the selected questions.

After correction, old and new rows deliberately share that same semantic
coordinate while differing in Quantity.

The coordinate therefore cannot also be the version identity used by a
one-to-one replacement graph.

A production correction promise would need either:

- a retained correspondence identity/version identity independent of the
  semantic coordinate; or
- another revision encoding with equivalent distinguishing power.

Observation 362 does not choose the wire shape, but the information distinction
is now observable.

### 2. Row-wise replacement does not encode coupled redistribution intent

The intended correction is:

    700 / 300
        ->
    600 / 400

Two independent replacement edges can represent the completed result.

However, a prefix containing only:

    A 700 -> A 600

publishes the numerically coherent frontier:

    A 600
    B 300
    total attributed = 900

That state is neither the old allocation nor the intended completed allocation.

ReplacementFrontier is not wrong. It answers only row supersession.

If the product promises that "move 100 JPY of settlement attribution from A to
B" is one atomic semantic correction, that promise needs an additional boundary
beyond independent row replacement.

Possible future candidates include:

- one retained redistribution/group identity whose members become current
  together;
- one aggregate allocation fact containing the coupled edges;
- publication mechanics that keep an incomplete correction group inert until
  all members are present.

None is selected here.

If the product instead permits incremental independent corrections, the 900-JPY
intermediate frontier may be legitimate and no grouping primitive is required.

Therefore atomic grouping is query/workflow-relative, not a universal law of
settlement arithmetic.

## Current settlement candidate

The evidence family has now accumulated pressure for:

    SettlementCommitment
      stable identity
      source provenance
      settlement Measure
      exact Quantity

    SettlementEffectCorrespondence
      version identity, if correction is promised
      target commitment
      later Event
      later EffectKey
      exact settled Quantity

    generic ReplacementFrontier
      for one-to-one correspondence revision

    derived outstanding
      from the current admitted correspondence frontier

Still not earned:

- production correspondence persistence;
- a universal CorrectionGroup;
- atomic multi-row publication;
- settlement-specific mutation;
- correspondence deletion;
- multi-parent resolution;
- automatic matching;
- temporal ordering;
- FX semantics.

The next decision should be practical:

> Does any real card / brokerage / household workflow require one atomic
> multi-correspondence redistribution, or is row-by-row correction acceptable?

That practical requirement should earn grouping, rather than introducing a
generic batch object from mathematical possibility alone.
-/

end Loam.Observation362
