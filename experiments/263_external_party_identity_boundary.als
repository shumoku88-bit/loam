module experiments/observation_263_external_party_identity_boundary

-- Observation 263 asks whether LOAM's existing opaque ExternalEndpoint identity
-- can safely widen into one role-free external-party identity shared by
-- open-relation endpoints and event-level counterparty evidence.
--
-- This model deliberately does not add Person, Merchant, Bank, Payee, Debtor,
-- Creditor, ownership, account-provider, or contact ontology. Those remain roles
-- or presentation outside identity.

sig Event {}
sig Locus {}

sig Effect {
  event: one Event,
  locus: one Locus
}

fact EveryEventHasObservedEffect {
  all e: Event | some eff: Effect | eff.event = e
}

abstract sig Party {}
one sig Household extends Party {}
sig ExternalParty extends Party {}

-- Household open-relation use of the shared identity space.
sig RelationUnit {
  sourceEffect: one Effect,
  debtor: one Party,
  creditor: one Party
}

fact HouseholdOpenRelationBoundary {
  all r: RelationUnit | {
    r.debtor != r.creditor
    (r.debtor = Household and r.creditor in ExternalParty) or
    (r.creditor = Household and r.debtor in ExternalParty)
  }
}

-- Candidate event-level overlay. This is intentionally only one selected
-- external counterparty per Event, not a universal participation ontology.
abstract sig World {
  counterparty: Event -> lone ExternalParty
}
one sig Left, Right extends World {}

-- One stable identity can be reused when the same outside actor appears both as
-- an Event counterparty and as an open-relation endpoint.
pred sameExternalIdentityAcrossEventAndRelation {
  some e: Event, r: RelationUnit, p: ExternalParty | {
    e.(Left.counterparty) = p
    p = r.debtor or p = r.creditor
  }
}

-- A merchant-like Event counterparty need not participate in any open relation.
-- Widening endpoint identity must not imply that every external Party becomes an
-- obligation endpoint.
pred eventOnlyPartyNeedsNoOpenRelation {
  some e: Event, p: ExternalParty | {
    e.(Left.counterparty) = p
    no r: RelationUnit | p = r.debtor or p = r.creditor
  }
}

-- Conversely an open-relation endpoint can exist without being selected as an
-- Event counterparty anywhere. The two semantic axes remain independent even
-- when they share identity vocabulary.
pred relationOnlyPartyNeedsNoEventCounterparty {
  some r: RelationUnit, p: ExternalParty | {
    p = r.debtor or p = r.creditor
    no e: Event | e.(Left.counterparty) = p
  }
}

-- Debtor / creditor direction is relation-local role, not Party identity.
pred samePartyCanAppearInBothRelationDirections {
  some p: ExternalParty, disj first, second: RelationUnit | {
    first.debtor = p
    first.creditor = Household
    second.debtor = Household
    second.creditor = p
  }
}

-- Locus and Party are orthogonal coordinates. The same external Party can be
-- encountered through Events whose effects touch different Loci.
pred samePartyAcrossDifferentLoci {
  some p: ExternalParty, disj firstEvent, secondEvent: Event,
       disj firstLocus, secondLocus: Locus | {
    firstEvent.(Left.counterparty) = p
    secondEvent.(Left.counterparty) = p
    some firstEffect: Effect | {
      firstEffect.event = firstEvent
      firstEffect.locus = firstLocus
    }
    some secondEffect: Effect | {
      secondEffect.event = secondEvent
      secondEffect.locus = secondLocus
    }
  }
}

-- The same Locus can participate in Events with different external Parties.
-- Payment location / wallet / account identity therefore cannot determine who
-- the Event was with.
pred sameLocusAcrossDifferentParties {
  some disj firstParty, secondParty: ExternalParty,
       disj firstEvent, secondEvent: Event,
       sharedLocus: Locus | {
    firstEvent.(Left.counterparty) = firstParty
    secondEvent.(Left.counterparty) = secondParty
    some firstEffect: Effect | {
      firstEffect.event = firstEvent
      firstEffect.locus = sharedLocus
    }
    some secondEffect: Effect | {
      secondEffect.event = secondEvent
      secondEffect.locus = sharedLocus
    }
  }
}

-- Deliberately too strong: retained Event / Effect / Locus evidence determines
-- the selected external counterparty. Left and Right share all neutral LOAM
-- evidence, so a counterexample means Party evidence is genuinely independent.
assert NeutralLoamEvidenceDeterminesCounterparty {
  all e: Event |
    (one e.(Left.counterparty) and one e.(Right.counterparty)) implies
      e.(Left.counterparty) = e.(Right.counterparty)
}

-- Deliberately too strong: if an Event anchors an open relation, that relation's
-- external endpoint must be the Event's selected counterparty. A shared identity
-- type must not collapse these two relations: e.g. a merchant can be the Event
-- counterparty while a friend is the debtor for one effect of that Event.
assert OpenRelationEndpointDeterminesEventCounterparty {
  all r: RelationUnit |
    let e = r.sourceEffect.event,
        outside = (r.debtor + r.creditor) - Household |
      one e.(Left.counterparty) implies e.(Left.counterparty) = outside
}

-- Positive control: the candidate overlay itself retains at most one selected
-- counterparty per Event in each World. This is a property of this candidate
-- query surface only, not a claim that real economic participation is globally
-- one-party.
assert SelectedEventCounterpartyIsLone {
  all w: World, e: Event | lone e.(w.counterparty)
}

run sameExternalIdentityAcrossEventAndRelation for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
run eventOnlyPartyNeedsNoOpenRelation for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
run relationOnlyPartyNeedsNoEventCounterparty for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
run samePartyCanAppearInBothRelationDirections for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
run samePartyAcrossDifferentLoci for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
run sameLocusAcrossDifferentParties for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit

check NeutralLoamEvidenceDeterminesCounterparty for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
check OpenRelationEndpointDeterminesEventCounterparty for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
check SelectedEventCounterpartyIsLone for exactly 2 World, exactly 4 Event, exactly 4 Locus, exactly 6 Effect, exactly 4 ExternalParty, exactly 5 RelationUnit
