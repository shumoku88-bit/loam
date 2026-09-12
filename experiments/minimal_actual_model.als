module experiments/minimal_actual_model

sig Date {}
sig Description {}
sig Payload {}
sig EffectKey {}
sig Endpoint {}
sig Quantity {}

sig Event {}

sig Effect {
  event: one Event,
  payload: one Payload
}

abstract sig ValidityRef {
  owner: one Event
}

sig RootRef extends ValidityRef {}

sig Revision extends ValidityRef {
  validOn: one Date
}

sig Relation {
  debtor: one Endpoint,
  creditor: one Endpoint,
  quantity: one Quantity
}

// One semantic household world. These relations deliberately model retained
// meaning rather than today's physical file families.
sig World {
  baseDate: Event -> one Date,
  description: Event -> lone Description,

  // Current semantic direction: target -> replacement / reversal.
  correction: Event -> lone Event,
  reversal: Event -> lone Event,

  // Date-correction semantic direction: target ref -> replacement revision.
  validityCorrection: ValidityRef -> lone Revision,

  // Stable Effect identity is optional until an exact Effect is independently
  // referenced. Relation atoms themselves stand for RelationUnit identity.
  keyOf: Effect -> lone EffectKey,
  relationSource: Relation -> lone Effect,

  // RelationDischarge has no independent ID in production. Its structural key
  // is the later Event + target Relation pair.
  discharge: Event -> Relation -> lone Quantity
}

// One structural base validity reference per Event. The base reference itself
// therefore needs no separately allocated identity.
fact OneRootPerEvent {
  all e: Event | one r: RootRef | r.owner = e
}

// Production Event correction admits only disjoint paths: one successor per
// target (already expressed by -> lone Event) and one predecessor per replacement.
fact EventCorrectionNoMerge {
  all w: World, replacement: Event |
    lone { target: Event | target->replacement in w.correction }
}

// Actual reversal is functional in both directions.
fact ReversalFunctionalBothWays {
  all w: World, reversalEvent: Event |
    lone { target: Event | target->reversalEvent in w.reversal }
}

// Date correction has the same partial-injective shape at the admitted boundary.
fact ValidityCorrectionNoMerge {
  all w: World, replacement: Revision |
    lone { target: ValidityRef | target->replacement in w.validityCorrection }
}

fact ValidityCorrectionPreservesEvent {
  all w: World, target: ValidityRef, replacement: Revision |
    target->replacement in w.validityCorrection implies
      target.owner = replacement.owner
}

// Durable EffectKey is unique only inside one Event, matching present LOAM
// semantics while allowing ordinary keyless Effects.
fact ScopedEffectKeys {
  all w: World, e: Event, k: EffectKey |
    lone { effect: Effect |
      effect.event = e and k in w.keyOf[effect]
    }
}

// Every retained Relation source must have stable Effect identity. Unreferenced
// ordinary Effects need not.
fact RelationSourceIsKeyed {
  all w: World, r: Relation |
    some w.relationSource[r] implies
      some w.keyOf[w.relationSource[r]]
}

// Compact orientation: put REPLACES on the replacement transaction.
fun compactCorrection[w: World]: Event -> Event {
  ~(w.correction)
}

// Compact orientation: put REVERSAL-OF on the reversal transaction.
fun compactReversal[w: World]: Event -> Event {
  ~(w.reversal)
}

// Compact orientation: put REPLACES on the identified date revision.
fun compactValidityCorrection[w: World]: Revision -> ValidityRef {
  ~(w.validityCorrection)
}

fun relationEvent[w: World, r: Relation]: lone Event {
  (w.relationSource[r]).event
}

fun relationKey[w: World, r: Relation]: lone EffectKey {
  w.keyOf[w.relationSource[r]]
}

fun resolvedEffect[w: World, e: Event, k: EffectKey]: set Effect {
  { effect: Effect |
    effect.event = e and k in w.keyOf[effect]
  }
}

// --- Positive pressure: distinctions that remain semantic even when physically
// co-located in one transaction record. ---

pred samePhysicalPayloadDifferentRecognition {
  some w: World, disj left, right: Event,
       leftEffect, rightEffect: Effect,
       disj leftDate, rightDate: Date,
       disj leftDesc, rightDesc: Description | {
    leftEffect.event = left
    rightEffect.event = right
    leftEffect.payload = rightEffect.payload
    w.baseDate[left] = leftDate
    w.baseDate[right] = rightDate
    w.description[left] = leftDesc
    w.description[right] = rightDesc
  }
}

pred samePhysicalWorldDifferentCorrectionMeaning {
  some disj left, right: World,
       disj original, replacement: Event | {
    left.baseDate = right.baseDate
    left.description = right.description
    left.keyOf = right.keyOf
    left.relationSource = right.relationSource
    left.discharge = right.discharge
    left.reversal = right.reversal
    left.validityCorrection = right.validityCorrection

    no left.correction
    right.correction = original->replacement
  }
}

pred samePhysicalWorldDifferentReversalMeaning {
  some disj left, right: World,
       disj original, reversalEvent: Event | {
    left.baseDate = right.baseDate
    left.description = right.description
    left.keyOf = right.keyOf
    left.relationSource = right.relationSource
    left.discharge = right.discharge
    left.correction = right.correction
    left.validityCorrection = right.validityCorrection

    no left.reversal
    right.reversal = original->reversalEvent
  }
}

pred sameRevisionDifferentCorrectionMeaning {
  some disj left, right: World,
       target: ValidityRef,
       replacement: Revision | {
    target.owner = replacement.owner
    left.baseDate = right.baseDate
    left.description = right.description
    left.keyOf = right.keyOf
    left.relationSource = right.relationSource
    left.discharge = right.discharge
    left.correction = right.correction
    left.reversal = right.reversal

    no left.validityCorrection
    right.validityCorrection = target->replacement
  }
}

pred unreferencedEffectCanRemainKeyless {
  some w: World, effect: Effect | {
    no w.keyOf[effect]
    no r: Relation | w.relationSource[r] = effect
  }
}

// Two otherwise-equal relation units can remain distinct because discharge can
// refer to one Relation identity without referring to the other.
pred equalRelationPayloadStillNeedsRelationIdentity {
  some w: World,
       disj left, right: Relation,
       source: Effect,
       later: Event,
       q: Quantity | {
    left.debtor = right.debtor
    left.creditor = right.creditor
    left.quantity = right.quantity
    w.relationSource[left] = source
    w.relationSource[right] = source
    some w.keyOf[source]
    later->left->q in w.discharge
    no later->right->q & w.discharge
  }
}

// --- Losslessness checks for the white-sheet compact orientation. ---

assert CorrectionCanBeStoredOnReplacement {
  all w: World | {
    all replacement: Event | lone replacement.(compactCorrection[w])
    ~(compactCorrection[w]) = w.correction
  }
}

assert ReversalCanBeStoredOnReversalEvent {
  all w: World | {
    all reversalEvent: Event | lone reversalEvent.(compactReversal[w])
    ~(compactReversal[w]) = w.reversal
  }
}

assert ValidityCorrectionCanBeStoredOnRevision {
  all w: World | {
    all replacement: Revision | lone replacement.(compactValidityCorrection[w])
    ~(compactValidityCorrection[w]) = w.validityCorrection
  }
}

assert RelationSourceEventIsDerivable {
  all w: World, r: Relation |
    some w.relationSource[r] implies
      relationEvent[w, r] = w.relationSource[r].event
}

assert EventAndSparseKeyIdentifyAtMostOneEffect {
  all w: World, e: Event, k: EffectKey |
    lone resolvedEffect[w, e, k]
}

// Because discharge is structurally keyed by (later Event, Relation), a separate
// discharge identity is not required to distinguish two quantities for that pair.
assert DischargePairDeterminesAtMostOneQuantity {
  all w: World, e: Event, r: Relation |
    lone w.discharge[e][r]
}

run samePhysicalPayloadDifferentRecognition for 8 but exactly 2 Event, 2 Effect, 2 Payload, 2 Date, 2 Description, 1 World
run samePhysicalWorldDifferentCorrectionMeaning for 8 but exactly 2 Event, 2 World
run samePhysicalWorldDifferentReversalMeaning for 8 but exactly 2 Event, 2 World
run sameRevisionDifferentCorrectionMeaning for 8 but exactly 1 Event, 1 RootRef, 1 Revision, 2 World
run unreferencedEffectCanRemainKeyless for 8 but exactly 1 Event, 1 Effect, 1 World
run equalRelationPayloadStillNeedsRelationIdentity for 10 but exactly 2 Event, 1 Effect, 2 Relation, 1 World

check CorrectionCanBeStoredOnReplacement for 10
check ReversalCanBeStoredOnReversalEvent for 10
check ValidityCorrectionCanBeStoredOnRevision for 10
check RelationSourceEventIsDerivable for 10
check EventAndSparseKeyIdentifyAtMostOneEffect for 10
check DischargePairDeterminesAtMostOneQuantity for 10
