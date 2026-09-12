module experiments/normalized_actual_effect_promotion

sig Event {}
sig Coordinate {}
sig EffectKey {}

sig EffectOccurrence {
  owner: one Event,
  coordinate: one Coordinate
}

sig Relation {
  source: one EffectOccurrence
}

sig ActualGeneration {
  effects: set EffectOccurrence,
  keyOf: EffectOccurrence -> lone EffectKey,
  relations: set Relation
}

pred closed[g: ActualGeneration] {
  g.relations.source in g.effects
  all relation: g.relations |
    one g.keyOf[relation.source]
  all ownerEvent: Event, key: EffectKey |
    lone { effect: g.effects |
      effect.owner = ownerEvent and key in g.keyOf[effect]
    }
}

fact EveryGenerationClosed {
  all generation: ActualGeneration | closed[generation]
}

// Locator is command-local capability, not canonical identity.
sig Locator {
  generation: one ActualGeneration,
  effect: one EffectOccurrence
}

pred resolves[l: Locator, selected: ActualGeneration] {
  selected = l.generation
  l.effect in selected.effects
}

assert StaleLocatorCannotResolve {
  all l: Locator, selected: ActualGeneration |
    selected != l.generation implies not resolves[l, selected]
}

pred promoteForRelation[
    old, new: ActualGeneration,
    locator: Locator,
    key: EffectKey,
    relation: Relation] {
  locator.generation = old
  locator.effect in old.effects
  no old.keyOf[locator.effect]
  relation not in old.relations
  relation.source = locator.effect

  new.effects = old.effects
  new.relations = old.relations + relation
  new.keyOf = old.keyOf + locator.effect->key
}

// Duplicate same-coordinate effects remain distinguishable for one command
// without assigning eager durable keys to both.
pred duplicateCoordinatePromotion {
  some disj chosen, twin: EffectOccurrence,
       old, new: ActualGeneration,
       locator: Locator,
       key: EffectKey,
       relation: Relation | {
    chosen in old.effects
    twin in old.effects
    chosen.owner = twin.owner
    chosen.coordinate = twin.coordinate
    locator.generation = old
    locator.effect = chosen
    no old.keyOf[chosen]
    no old.keyOf[twin]
    promoteForRelation[old, new, locator, key, relation]
  }
}

pred staleLocatorWitness {
  some locator: Locator, selected: ActualGeneration | {
    locator.effect in locator.generation.effects
    selected != locator.generation
    not resolves[locator, selected]
  }
}

assert PromotionChangesOnlyChosenIdentity {
  all old, new: ActualGeneration,
      locator: Locator,
      key: EffectKey,
      relation: Relation |
    promoteForRelation[old, new, locator, key, relation] implies {
      new.keyOf[locator.effect] = key
      all other: old.effects - locator.effect |
        new.keyOf[other] = old.keyOf[other]
    }
}

assert RelationSourceStableAfterPromotion {
  all old, new: ActualGeneration,
      locator: Locator,
      key: EffectKey,
      relation: Relation |
    promoteForRelation[old, new, locator, key, relation] implies {
      relation in new.relations
      relation.source = locator.effect
      key in new.keyOf[relation.source]
    }
}

run duplicateCoordinatePromotion for 5 but exactly 1 Event, exactly 1 Coordinate, exactly 1 EffectKey, exactly 2 EffectOccurrence, exactly 1 Relation, exactly 2 ActualGeneration, exactly 1 Locator
run staleLocatorWitness for 5 but exactly 1 Event, exactly 1 Coordinate, exactly 0 EffectKey, exactly 1 EffectOccurrence, exactly 0 Relation, exactly 2 ActualGeneration, exactly 1 Locator

check StaleLocatorCannotResolve for 5 but exactly 1 Event, exactly 1 Coordinate, exactly 1 EffectKey, exactly 2 EffectOccurrence, exactly 1 Relation, exactly 2 ActualGeneration, exactly 1 Locator
check PromotionChangesOnlyChosenIdentity for 5 but exactly 1 Event, exactly 1 Coordinate, exactly 1 EffectKey, exactly 2 EffectOccurrence, exactly 1 Relation, exactly 2 ActualGeneration, exactly 1 Locator
check RelationSourceStableAfterPromotion for 5 but exactly 1 Event, exactly 1 Coordinate, exactly 1 EffectKey, exactly 2 EffectOccurrence, exactly 1 Relation, exactly 2 ActualGeneration, exactly 1 Locator
