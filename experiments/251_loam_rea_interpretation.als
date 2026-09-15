module experiments/observation_251_loam_rea_interpretation

-- Observation 251 asks a deliberately narrow connection question:
--
--   does current neutral LOAM evidence uniquely determine selected
--   Resource-Event-Agent (REA) interpretation?
--
-- This is not a complete REA ontology. `Resource`, `Agent`, and selected
-- Event duality are observation-local shadow vocabulary used only to test
-- derivability from one fixed LOAM evidence shape.

abstract sig Locus {}
one sig CashLocus, GoodsLocus extends Locus {}

abstract sig Measure {}
one sig JPY extends Measure {}

abstract sig SignedQuantity {}
one sig Minus100, Plus100 extends SignedQuantity {}

abstract sig Event {}
one sig Payment, DeliveryA, DeliveryB extends Event {}

abstract sig Effect {
  event: one Event,
  locus: one Locus,
  measure: one Measure,
  quantity: one SignedQuantity
}
one sig CashEffect, GoodsEffect extends Effect {}

-- Fixed LOAM evidence shared by every candidate interpretation.
-- No Account, debit/credit, Resource, Agent, ownership, exchange, or duality
-- meaning is encoded in these identities or quantities.
fact StableLoamEvidence {
  CashEffect.event = Payment
  CashEffect.locus = CashLocus
  CashEffect.measure = JPY
  CashEffect.quantity = Minus100

  GoodsEffect.event = Payment
  GoodsEffect.locus = GoodsLocus
  GoodsEffect.measure = JPY
  GoodsEffect.quantity = Plus100
}

-- Observation-local fragments of an REA interpretation.
abstract sig Resource {}
one sig MoneyResource, GoodsResource, AlternativeResource extends Resource {}

abstract sig Agent {}
one sig HouseholdAgent, MerchantAgent extends Agent {}

abstract sig World {
  -- Interpretation of a neutral LOAM Locus as an REA Resource.
  resourceOf: Locus -> lone Resource,

  -- Agents selected as participating in a LOAM Event when viewed as an
  -- economic event.
  participant: Event -> set Agent,

  -- Selected duality partner for an Event. This is intentionally only the
  -- queried edge needed for the distinguishability probe, not a complete REA
  -- exchange graph.
  duality: Event -> lone Event
}
one sig Left, Right extends World {}

-- Minimal well-formedness for the selected REA questions. Every observed LOAM
-- Locus receives one Resource interpretation, Payment has at least one Agent,
-- and Payment has exactly one distinct duality partner.
pred reaCandidate[w: World] {
  all l: Effect.locus | one l.(w.resourceOf)
  some Payment.(w.participant)
  one Payment.(w.duality)
  Payment not in Payment.(w.duality)
}

pred reaInterpretationExists {
  reaCandidate[Left]
}

-- Hold Resource and duality interpretation fixed while varying Agent
-- participation. If SAT, physical/event evidence does not determine Agent.
pred sameLoamEvidenceDifferentAgent {
  reaCandidate[Left]
  reaCandidate[Right]
  Left.resourceOf = Right.resourceOf
  Left.duality = Right.duality
  Payment.(Left.participant) != Payment.(Right.participant)
}

-- Hold Agent and duality interpretation fixed while varying the Resource
-- assigned to one observed Locus. If SAT, Locus identity does not determine
-- REA Resource identity.
pred sameLoamEvidenceDifferentResource {
  reaCandidate[Left]
  reaCandidate[Right]
  Left.participant = Right.participant
  Left.duality = Right.duality
  CashLocus.(Left.resourceOf) != CashLocus.(Right.resourceOf)
}

-- Hold Resource and Agent interpretation fixed while varying the selected
-- duality partner. If SAT, Event/effect evidence does not determine which
-- economic event is the reciprocal side of an exchange.
pred sameLoamEvidenceDifferentDuality {
  reaCandidate[Left]
  reaCandidate[Right]
  Left.resourceOf = Right.resourceOf
  Left.participant = Right.participant
  Payment.(Left.duality) != Payment.(Right.duality)
}

-- Deliberately too strong: fixed neutral LOAM evidence alone determines all
-- three selected REA interpretation planes.
assert LoamEvidenceDeterminesREAInterpretation {
  (reaCandidate[Left] and reaCandidate[Right]) implies
    (Left.resourceOf = Right.resourceOf and
     Left.participant = Right.participant and
     Left.duality = Right.duality)
}

-- Even explicit Resource interpretation need not determine Agent participation.
assert LoamPlusResourceDeterminesAgent {
  (reaCandidate[Left] and reaCandidate[Right] and
   Left.resourceOf = Right.resourceOf) implies
    Left.participant = Right.participant
}

-- Resource + Agent interpretation still need not determine exchange duality.
assert LoamPlusResourceAndAgentDeterminesDuality {
  (reaCandidate[Left] and reaCandidate[Right] and
   Left.resourceOf = Right.resourceOf and
   Left.participant = Right.participant) implies
    Left.duality = Right.duality
}

-- Positive control: once all selected interpretation evidence is explicit,
-- the selected Resource, Agent, and duality queries agree.
assert FullExplicitOverlayDeterminesSelectedQueries {
  (Left.resourceOf = Right.resourceOf and
   Left.participant = Right.participant and
   Left.duality = Right.duality) implies
    (CashLocus.(Left.resourceOf) = CashLocus.(Right.resourceOf) and
     Payment.(Left.participant) = Payment.(Right.participant) and
     Payment.(Left.duality) = Payment.(Right.duality))
}

run reaInterpretationExists for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
run sameLoamEvidenceDifferentAgent for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
run sameLoamEvidenceDifferentResource for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
run sameLoamEvidenceDifferentDuality for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
check LoamEvidenceDeterminesREAInterpretation for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
check LoamPlusResourceDeterminesAgent for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
check LoamPlusResourceAndAgentDeterminesDuality for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
check FullExplicitOverlayDeterminesSelectedQueries for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 SignedQuantity, exactly 3 Event, exactly 2 Effect, exactly 3 Resource, exactly 2 Agent
