import Loam.Core.EventMemory

namespace Loam.Observation361

open Loam.Core

set_option autoImplicit false

/-!
# Observation 361 — settlement correspondence needs its own exact quantity

Observation 360 selected the cleaner current architecture:

    source-bounded OpenRelation
        !=
    independently measured SettlementCommitment
        +
    later SettlementEffectCorrespondence

The remaining question is correspondence granularity.

If every physical settlement Effect belongs wholly to one commitment, this shape
can appear sufficient:

    target commitment
    + later Event
    + later EffectKey

For example:

    commitment 1000 JPY
      <- Event A Effect -400 JPY
      <- Event B Effect -600 JPY

The physical Effect magnitudes happen to determine the 400 / 600 split.

But a stronger practical case breaks that inference:

    one bank debit Effect = -1000 JPY

    commitment A receives 700
    commitment B receives 300

One physical movement may therefore settle several independently meaningful
commitments.

The same bare pair of correspondences:

    debit Effect -> A
    debit Effect -> B

does not determine whether the split was:

    700 / 300
    600 / 400
    ...

provided the target and Effect aggregate bounds remain satisfied.

Observation 361 asks whether the settlement correspondence itself must retain an
exact settled Quantity.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def sourceEventA : EventId := ⟨"o361-source-a"⟩
private def sourceEffectA : EffectKey := ⟨"o361-source-a-effect"⟩
private def sourceEventB : EventId := ⟨"o361-source-b"⟩
private def sourceEffectB : EffectKey := ⟨"o361-source-b-effect"⟩
private def sourceEventC : EventId := ⟨"o361-source-c"⟩
private def sourceEffectC : EffectKey := ⟨"o361-source-c-effect"⟩

private def settlement400Id : EventId := ⟨"o361-settlement-400"⟩
private def settlement600Id : EventId := ⟨"o361-settlement-600"⟩
private def settlement1000Id : EventId := ⟨"o361-settlement-1000"⟩

private def settlement400Effect : EffectKey := ⟨"o361-cash-400"⟩
private def settlement600Effect : EffectKey := ⟨"o361-cash-600"⟩
private def settlement1000Effect : EffectKey := ⟨"o361-cash-1000"⟩

private def sourceA? : Option Event :=
  Event.ofEffects? sourceEventA [
    Effect.ofQuantity sourceEffectA bank yen (Quantity.ofQuanta 1)
  ]

private def sourceB? : Option Event :=
  Event.ofEffects? sourceEventB [
    Effect.ofQuantity sourceEffectB bank yen (Quantity.ofQuanta 1)
  ]

private def sourceC? : Option Event :=
  Event.ofEffects? sourceEventC [
    Effect.ofQuantity sourceEffectC bank yen (Quantity.ofQuanta 1)
  ]

private def settlement400? : Option Event :=
  Event.ofEffects? settlement400Id [
    Effect.ofQuantity settlement400Effect bank yen (Quantity.ofQuanta (-400))
  ]

private def settlement600? : Option Event :=
  Event.ofEffects? settlement600Id [
    Effect.ofQuantity settlement600Effect bank yen (Quantity.ofQuanta (-600))
  ]

private def settlement1000? : Option Event :=
  Event.ofEffects? settlement1000Id [
    Effect.ofQuantity settlement1000Effect bank yen (Quantity.ofQuanta (-1000))
  ]

private def events? : Option EventMemory := do
  let a ← sourceA?
  let b ← sourceB?
  let c ← sourceC?
  let s400 ← settlement400?
  let s600 ← settlement600?
  let s1000 ← settlement1000?
  EventMemory.ofEvents? [a, b, c, s400, s600, s1000]

structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

structure SettlementCommitment where
  id : SettlementCommitmentId
  sourceEvent : EventId
  sourceEffect : EffectKey
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def commitmentAId : SettlementCommitmentId := ⟨"commitment-a"⟩
private def commitmentBId : SettlementCommitmentId := ⟨"commitment-b"⟩
private def commitmentCId : SettlementCommitmentId := ⟨"commitment-c"⟩

private def commitmentA700 : SettlementCommitment := {
  id := commitmentAId
  sourceEvent := sourceEventA
  sourceEffect := sourceEffectA
  measure := yen
  quantity := Quantity.ofQuanta 700
}

private def commitmentB300 : SettlementCommitment := {
  id := commitmentBId
  sourceEvent := sourceEventB
  sourceEffect := sourceEffectB
  measure := yen
  quantity := Quantity.ofQuanta 300
}

private def commitmentA800 : SettlementCommitment := {
  commitmentA700 with
  quantity := Quantity.ofQuanta 800
}

private def commitmentB800 : SettlementCommitment := {
  commitmentB300 with
  quantity := Quantity.ofQuanta 800
}

private def commitmentC1000 : SettlementCommitment := {
  id := commitmentCId
  sourceEvent := sourceEventC
  sourceEffect := sourceEffectC
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

structure BareSettlementEffectCorrespondence where
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

structure SettlementEffectCorrespondence where
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

private def eraseQuantity
    (row : SettlementEffectCorrespondence) :
    BareSettlementEffectCorrespondence := {
  target := row.target
  event := row.event
  effect := row.effect
}

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def findCommitmentById?
    (commitments : List SettlementCommitment)
    (id : SettlementCommitmentId) :
    Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

private def targetSettledTotal
    (rows : List SettlementEffectCorrespondence)
    (target : SettlementCommitmentId) : Int :=
  rows.foldl
    (fun total row =>
      if row.target = target then total + row.quantity.quanta else total)
    0

private def effectSettledTotal
    (rows : List SettlementEffectCorrespondence)
    (event : EventId)
    (effect : EffectKey) : Int :=
  rows.foldl
    (fun total row =>
      if row.event = event && row.effect = effect then
        total + row.quantity.quanta
      else
        total)
    0

private def oneCorrespondenceLocallyAdmissible
    (memory : EventMemory)
    (commitments : List SettlementCommitment)
    (row : SettlementEffectCorrespondence) : Bool :=
  match findCommitmentById? commitments row.target,
        memory.findById? row.event with
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
    (commitments : List SettlementCommitment)
    (rows : List SettlementEffectCorrespondence) : Bool :=
  rows.all (oneCorrespondenceLocallyAdmissible memory commitments) &&
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

private def outstanding?
    (memory : EventMemory)
    (commitments : List SettlementCommitment)
    (rows : List SettlementEffectCorrespondence)
    (target : SettlementCommitmentId) : Option Int := do
  if !correspondenceSetAdmissible memory commitments rows then
    none
  let commitment ← findCommitmentById? commitments target
  some (commitment.quantity.quanta - targetSettledTotal rows target)

/-!
## Pressure 1 — one commitment can settle across multiple later Effects
-/

private def c400 : SettlementEffectCorrespondence := {
  target := commitmentCId
  event := settlement400Id
  effect := settlement400Effect
  quantity := Quantity.ofQuanta 400
}

private def c600 : SettlementEffectCorrespondence := {
  target := commitmentCId
  event := settlement600Id
  effect := settlement600Effect
  quantity := Quantity.ofQuanta 600
}

theorem one_commitment_can_be_partially_settled_then_completed :
    (do
      let memory ← events?
      pure (
        outstanding? memory [commitmentC1000] [c400] commitmentCId,
        outstanding? memory [commitmentC1000] [c400, c600] commitmentCId)) =
      some (some 600, some 0) := by
  native_decide

/-!
## Pressure 2 — one physical Effect can settle several commitments
-/

private def shared700 : SettlementEffectCorrespondence := {
  target := commitmentAId
  event := settlement1000Id
  effect := settlement1000Effect
  quantity := Quantity.ofQuanta 700
}

private def shared300 : SettlementEffectCorrespondence := {
  target := commitmentBId
  event := settlement1000Id
  effect := settlement1000Effect
  quantity := Quantity.ofQuanta 300
}

theorem one_physical_effect_can_exactly_cover_two_commitments :
    (do
      let memory ← events?
      pure (
        correspondenceSetAdmissible
          memory [commitmentA700, commitmentB300] [shared700, shared300],
        outstanding?
          memory [commitmentA700, commitmentB300]
          [shared700, shared300] commitmentAId,
        outstanding?
          memory [commitmentA700, commitmentB300]
          [shared700, shared300] commitmentBId)) =
      some (true, some 0, some 0) := by
  native_decide

/-!
## Falsification — bare Effect correspondence does not determine the split
-/

private def split700_300 : List SettlementEffectCorrespondence := [
  { shared700 with quantity := Quantity.ofQuanta 700 },
  { shared300 with quantity := Quantity.ofQuanta 300 }
]

private def split600_400 : List SettlementEffectCorrespondence := [
  { shared700 with quantity := Quantity.ofQuanta 600 },
  { shared300 with quantity := Quantity.ofQuanta 400 }
]

private def bareShared :
    List BareSettlementEffectCorrespondence :=
  split700_300.map eraseQuantity

theorem two_distinct_exact_splits_have_identical_bare_correspondence :
    split600_400.map eraseQuantity = bareShared ∧
    split700_300 ≠ split600_400 := by
  native_decide

theorem identical_bare_correspondence_can_hide_different_outstanding :
    (do
      let memory ← events?
      pure (
        correspondenceSetAdmissible
          memory [commitmentA800, commitmentB800] split700_300,
        correspondenceSetAdmissible
          memory [commitmentA800, commitmentB800] split600_400,
        outstanding?
          memory [commitmentA800, commitmentB800]
          split700_300 commitmentAId,
        outstanding?
          memory [commitmentA800, commitmentB800]
          split600_400 commitmentAId,
        outstanding?
          memory [commitmentA800, commitmentB800]
          split700_300 commitmentBId,
        outstanding?
          memory [commitmentA800, commitmentB800]
          split600_400 commitmentBId)) =
      some (true, true, some 100, some 200, some 500, some 400) := by
  native_decide

/-!
## Aggregate safety — local validity is not enough
-/

private def overEffect700 : SettlementEffectCorrespondence := {
  target := commitmentAId
  event := settlement1000Id
  effect := settlement1000Effect
  quantity := Quantity.ofQuanta 700
}

private def overEffect400 : SettlementEffectCorrespondence := {
  target := commitmentBId
  event := settlement1000Id
  effect := settlement1000Effect
  quantity := Quantity.ofQuanta 400
}

theorem aggregate_effect_coverage_rejects_double_use :
    (do
      let memory ← events?
      pure (
        oneCorrespondenceLocallyAdmissible
          memory [commitmentA800, commitmentB800] overEffect700,
        oneCorrespondenceLocallyAdmissible
          memory [commitmentA800, commitmentB800] overEffect400,
        correspondenceSetAdmissible
          memory [commitmentA800, commitmentB800]
          [overEffect700, overEffect400])) =
      some (true, true, false) := by
  native_decide

private def overTarget900 : SettlementEffectCorrespondence := {
  target := commitmentAId
  event := settlement1000Id
  effect := settlement1000Effect
  quantity := Quantity.ofQuanta 900
}

theorem target_bound_rejects_over_settlement :
    (do
      let memory ← events?
      pure (
        correspondenceSetAdmissible
          memory [commitmentA800] [overTarget900])) =
      some false := by
  native_decide

/-!
## Finding

The exact settled Quantity is independently observable on the settlement
correspondence.

A bare:

    target commitment
    + later Event
    + later EffectKey

is sufficient only under the stronger assumption that one physical Effect is
consumed wholly by one target commitment.

Observation 361 falsifies that assumption.

The same physical -1000 JPY Effect and the same two bare target correspondences
can support:

    A 700 / B 300

or:

    A 600 / B 400

with different outstanding answers.

Therefore the minimum candidate becomes:

    SettlementEffectCorrespondence
      target commitment
      later Event
      later EffectKey
      exact positive settled Quantity

with two independent aggregate conservation laws:

    sum(quantity for one target)
      <= commitment quantity

    sum(quantity for one physical Event/Effect)
      <= |physical Effect quantity|

These are dual bounds.

The first prevents over-settling one semantic commitment.

The second prevents counting the same physical movement twice across several
commitments.

This reproduces the exact-quantity pressure that previously earned
RelationDischarge.quantity, but at the stronger Effect-level physical boundary.

No new quantity-slice identity is yet required.

For the selected questions, one normalized row per:

    target commitment
    + later Event
    + later EffectKey

can retain the exact aggregate quantity attributed along that edge.

A future correction operation that must target one individual piece inside such
an aggregate could reopen correspondence identity pressure.

## Architectural consequence

The settlement family is converging toward:

    SettlementCommitment
      source provenance
      settlement Measure
      exact commitment Quantity

    SettlementEffectCorrespondence
      target commitment
      later Event
      later EffectKey
      exact settled Quantity

    derived outstanding
      commitment quantity
        - admitted correspondence total

This remains additive beside OpenRelation rather than broadening it.

Repeated pressure now exists across:

- foreign-card settlement;
- delayed security settlement;
- partial multi-Event settlement;
- one-Effect-to-many-commitment allocation.

That is substantially stronger evidence for a reusable settlement family than
Observation 359 alone.

Still not earned:

- production persistence;
- a generic Settlement entity;
- SettlementCorrespondenceId;
- correction/reversal semantics;
- automatic matching;
- temporal ordering law;
- FX semantics;
- fee capitalization;
- settlement netting across external parties;
- signed commitment quantities.

The next pressure should test correction / reversal of a settlement
correspondence.

If a 700/300 attribution is later corrected to 600/400 while the physical
-1000 JPY Event remains unchanged, can generic ReplacementFrontier mechanics
again carry the semantic revision without introducing settlement-specific
mutation?
-/

end Loam.Observation361
