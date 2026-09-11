module experiments/observation_245_capacity_recovery_ambiguity

// Static companion to the temporal topology model.
//
// After a split Capacity publication crashes between effective evidence and
// movement authority, the retained orphan evidence contains only a movement
// identity and effective coordinate. This model asks whether that observation
// can uniquely determine the missing movement payload.

sig Purpose {}
one sig Food, Rent extends Purpose {}

sig MoveId {}
one sig Capacity1 extends MoveId {}

sig Day {}
one sig D1 extends Day {}

sig CandidateMovement {
  id: one MoveId,
  destination: one Purpose
}
one sig FoodMove, RentMove extends CandidateMovement {}

sig CompletedWorld {
  movement: one CandidateMovement
}
one sig FoodWorld, RentWorld extends CompletedWorld {}

one sig OrphanEffective {
  movementId: one MoveId,
  effectiveOn: one Day
}

one sig RecoveryChoice {
  destination: one Purpose
}

fact SameObservedOrphanDifferentPossibleCompletions {
  OrphanEffective.movementId = Capacity1
  OrphanEffective.effectiveOn = D1

  FoodMove.id = Capacity1
  RentMove.id = Capacity1
  FoodMove.destination = Food
  RentMove.destination = Rent

  FoodWorld.movement = FoodMove
  RentWorld.movement = RentMove
}

pred ambiguousMissingMovement {
  FoodWorld.movement.id = OrphanEffective.movementId
  RentWorld.movement.id = OrphanEffective.movementId
  FoodWorld.movement.destination != RentWorld.movement.destination
}

// A recovery choice based only on the shared orphan observation is one value.
// If two possible completed worlds share that observation but require different
// movement payloads, no such choice can be correct for both worlds.
assert OrphanEffectiveDeterminesOneSafeDestination {
  all w: CompletedWorld |
    w.movement.id = OrphanEffective.movementId implies
      RecoveryChoice.destination = w.movement.destination
}

// The missing movement payload would be recoverable from orphan evidence only
// if all possible completed worlds agreeing on its movement id agreed on the
// destination. The concrete Food/Rent pair should refute that.
assert SameOrphanImpliesSameCompletion {
  all disj left, right: CompletedWorld |
    left.movement.id = OrphanEffective.movementId and
    right.movement.id = OrphanEffective.movementId implies
      left.movement.destination = right.movement.destination
}

run ambiguousMissingMovement for exactly 2 Purpose, exactly 1 MoveId, exactly 1 Day,
  exactly 2 CandidateMovement, exactly 2 CompletedWorld

check OrphanEffectiveDeterminesOneSafeDestination for exactly 2 Purpose, exactly 1 MoveId,
  exactly 1 Day, exactly 2 CandidateMovement, exactly 2 CompletedWorld

check SameOrphanImpliesSameCompletion for exactly 2 Purpose, exactly 1 MoveId, exactly 1 Day,
  exactly 2 CandidateMovement, exactly 2 CompletedWorld
