module experiments/observation_264_event_party_granularity

-- Observation 264 asks whether one Event-scoped `lone Party` is sufficient
-- semantic authority for household "who" questions once obligations, arrears,
-- collection intermediaries, and self-transfers are considered.
--
-- `Party` remains observation-local shared identity from Observation 263.
-- The model deliberately prefers existing/specific relations over a generic
-- participation ontology: obligations carry debtor/creditor, discharge names an
-- obligation, and payment-recipient evidence names the party actually paid.

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

-- Observation-local witness vocabulary only. These names make the household
-- pressure readable; they are not proposed production enums.
abstract sig ObligationKind {}
one sig InsuranceCurrent, InsuranceArrears, Rent, RenewalFee extends ObligationKind {}

-- REA/open-relation-shaped obligation identity. Distinct obligations may share
-- both parties and still remain distinct because period/kind/history matters.
sig Obligation {
  debtor: one Party,
  creditor: one Party,
  kind: one ObligationKind
}

fact HouseholdObligationBoundary {
  all o: Obligation | {
    o.debtor = Household
    o.creditor in ExternalParty
  }
}

-- One payment Event may discharge several distinct obligations.
sig Discharge {
  event: one Event,
  obligation: one Obligation
}

fact DischargePairUnique {
  all e: Event, o: Obligation |
    lone { d: Discharge | d.event = e and d.obligation = o }
}

-- Specific evidence for the external party that directly received a payment.
-- This is intentionally not called Seller, Merchant, Creditor, or Counterparty.
sig PaymentRecipientFact {
  event: one Event,
  party: one ExternalParty
}

fact OneDirectRecipientPerEventForThisProbe {
  all e: Event | lone { f: PaymentRecipientFact | f.event = e }
}

-- Candidate convenience/recognition overlay inherited from Observation 263.
-- `lone` is what this observation is trying to bound, not a theorem about all
-- real-world participation.
abstract sig World {
  counterparty: Event -> lone ExternalParty
}
one sig Left, Right extends World {}

fun dischargedObligations[e: Event]: set Obligation {
  { o: Obligation | some d: Discharge | d.event = e and d.obligation = o }
}

fun creditorsOf[e: Event]: set ExternalParty {
  dischargedObligations[e].creditor & ExternalParty
}

fun recipientsOf[e: Event]: set ExternalParty {
  { p: ExternalParty | some f: PaymentRecipientFact | f.event = e and f.party = p }
}

fun relevantExternalParties[e: Event]: set ExternalParty {
  creditorsOf[e] + recipientsOf[e]
}

-- Normal insurance and an overdue installment may be owed to the same insurer
-- while remaining distinct obligations.
pred currentAndArrearsShareCreditor {
  some insurer: ExternalParty,
       disj current, arrears: Obligation | {
    current.kind = InsuranceCurrent
    arrears.kind = InsuranceArrears
    current.creditor = insurer
    arrears.creditor = insurer
  }
}

-- One actual payment can settle both current and overdue insurance obligations.
-- Party identity alone cannot tell which obligation(s) this payment discharged.
pred onePaymentDischargesCurrentAndArrears {
  some payment: Event,
       insurer: ExternalParty,
       disj current, arrears: Obligation,
       disj dCurrent, dArrears: Discharge | {
    current.kind = InsuranceCurrent
    arrears.kind = InsuranceArrears
    current.creditor = insurer
    arrears.creditor = insurer
    dCurrent.event = payment
    dCurrent.obligation = current
    dArrears.event = payment
    dArrears.obligation = arrears
  }
}

-- Rent and a renewal fee can be distinct obligations even when owed to the same
-- external party and paid in one Event.
pred onePaymentDischargesRentAndRenewal {
  some payment: Event,
       landlord: ExternalParty,
       disj rent, renewal: Obligation,
       disj dRent, dRenewal: Discharge | {
    rent.kind = Rent
    renewal.kind = RenewalFee
    rent.creditor = landlord
    renewal.creditor = landlord
    dRent.event = payment
    dRent.obligation = rent
    dRenewal.event = payment
    dRenewal.obligation = renewal
  }
}

-- The legal/economic creditor and the party that actually receives payment may
-- differ, e.g. landlord versus management/collection company.
pred landlordAndCollectionRecipientDiffer {
  some payment: Event,
       disj landlord, collector: ExternalParty,
       rent: Obligation,
       discharge: Discharge,
       recipient: PaymentRecipientFact | {
    rent.kind = Rent
    rent.creditor = landlord
    discharge.event = payment
    discharge.obligation = rent
    recipient.event = payment
    recipient.party = collector
  }
}

-- The previous witness creates two independently meaningful external identities
-- around one Event without requiring a generic Event->set Party authority.
pred oneEventHasTwoRelevantExternalParties {
  some e: Event | #relevantExternalParties[e] >= 2
}

-- A pure household self-transfer can touch several Loci while requiring no
-- external party evidence at all.
pred selfTransferNeedsNoExternalParty {
  some e: Event, disj firstLocus, secondLocus: Locus | {
    some firstEffect: Effect | firstEffect.event = e and firstEffect.locus = firstLocus
    some secondEffect: Effect | secondEffect.event = e and secondEffect.locus = secondLocus
    no d: Discharge | d.event = e
    no f: PaymentRecipientFact | f.event = e
    no e.(Left.counterparty)
  }
}

-- The common simple purchase still fits the cheap projection: one direct
-- recipient can also be the selected recognition counterparty.
pred simplePaymentFitsLoneCounterparty {
  some e: Event, p: ExternalParty, f: PaymentRecipientFact | {
    f.event = e
    f.party = p
    e.(Left.counterparty) = p
    no d: Discharge | d.event = e
  }
}

-- Deliberately too strong: one creditor identity identifies one obligation.
-- Current versus arrears and rent versus renewal should falsify this.
assert CreditorDeterminesObligationIdentity {
  all first, second: Obligation |
    first.creditor = second.creditor implies first = second
}

-- Deliberately too strong: if a selected Event counterparty and one discharged
-- creditor both exist, they must be the same Party.
assert SelectedCounterpartyDeterminesCreditor {
  all e: Event |
    (one e.(Left.counterparty) and one creditorsOf[e]) implies
      e.(Left.counterparty) = creditorsOf[e]
}

-- Deliberately too strong: a single selected counterparty contains every
-- externally relevant party for the Event. Landlord != collection recipient is
-- the intended counterexample.
assert LoneCounterpartyCoversAllRelevantParties {
  all e: Event |
    (one e.(Left.counterparty) and some relevantExternalParties[e]) implies
      e.(Left.counterparty) = relevantExternalParties[e]
}

-- Positive control for the candidate overlay only.
assert SelectedEventCounterpartyIsLone {
  all w: World, e: Event | lone e.(w.counterparty)
}

run currentAndArrearsShareCreditor for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run onePaymentDischargesCurrentAndArrears for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run onePaymentDischargesRentAndRenewal for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run landlordAndCollectionRecipientDiffer for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run oneEventHasTwoRelevantExternalParties for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run selfTransferNeedsNoExternalParty for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
run simplePaymentFitsLoneCounterparty for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact

check CreditorDeterminesObligationIdentity for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
check SelectedCounterpartyDeterminesCreditor for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
check LoneCounterpartyCoversAllRelevantParties for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
check SelectedEventCounterpartyIsLone for exactly 2 World, exactly 6 Event, exactly 5 Locus, exactly 8 Effect, exactly 5 ExternalParty, exactly 6 Obligation, exactly 6 Discharge, exactly 4 PaymentRecipientFact
