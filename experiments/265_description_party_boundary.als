module experiments/observation_265_description_party_boundary

-- Observation 265 asks whether EventDescription can serve as semantic authority
-- for stable external-party identity. The retained description relation is fixed;
-- two Worlds vary only an observation-local selected external-party overlay.

sig Description {}
sig ExternalParty {}

sig Event {
  description: one Description
}

abstract sig World {
  selectedParty: Event -> lone ExternalParty
}
one sig Left, Right extends World {}

-- Stable recognizer texts. Their names describe the real household pressure but
-- do not add parsing or ontology to production LOAM.
one sig ConvenienceText, SanwaText, MontbellText, MontbellDetailedText,
        TransferText, RentText extends Description {}

one sig ConvenienceA, ConvenienceB,
        SanwaA, SanwaB,
        MontbellA, MontbellB,
        SelfTransfer, RentPayment extends Event {}

one sig ConveniencePartyA, ConveniencePartyB,
        SanwaParty, MontbellParty,
        LandlordParty, AlternativeLandlordParty extends ExternalParty {}

fact StableDescriptions {
  ConvenienceA.description = ConvenienceText
  ConvenienceB.description = ConvenienceText

  SanwaA.description = SanwaText
  SanwaB.description = SanwaText

  MontbellA.description = MontbellText
  MontbellB.description = MontbellDetailedText

  SelfTransfer.description = TransferText
  RentPayment.description = RentText
}

-- One generic recognizer phrase can cover distinct outside identities. This is
-- the pressure represented by historical category/channel text such as
-- "コンビニ": equal human text is not stable Party identity.
pred sameDescriptionCanCoverDifferentParties {
  ConvenienceA.(Left.selectedParty) = ConveniencePartyA
  ConvenienceB.(Left.selectedParty) = ConveniencePartyB
}

-- A stable identity can survive description variation. This models the opposite
-- direction: one merchant can be recognized by a short name in one Event and by
-- a longer place/item phrase in another.
pred samePartyCanHaveDifferentDescriptions {
  MontbellA.(Left.selectedParty) = MontbellParty
  MontbellB.(Left.selectedParty) = MontbellParty
  MontbellA.description != MontbellB.description
}

-- Exact simple merchant text can still be useful recognition evidence without
-- making description equality an identity law.
pred exactMerchantTextCanAgreeWithStableParty {
  SanwaA.(Left.selectedParty) = SanwaParty
  SanwaB.(Left.selectedParty) = SanwaParty
  SanwaA.description = SanwaB.description
}

-- A description may name providers or locations while the Event requires no
-- external household Party at all. This is the SMBC -> PayPay self-transfer
-- negative control from Observation 264.
pred descriptionMayNameThingsWithoutSelectingParty {
  no SelfTransfer.(Left.selectedParty)
}

-- Purpose/obligation text such as "家賃" does not determine a landlord identity.
-- Two candidate Worlds can keep exactly the same retained description while
-- selecting different Party interpretations.
pred sameDescriptionAllowsDifferentPartyInterpretations {
  RentPayment.(Left.selectedParty) = LandlordParty
  RentPayment.(Right.selectedParty) = AlternativeLandlordParty
}

-- Deliberately too strong: equal EventDescription means equal selected Party.
assert EqualDescriptionDeterminesParty {
  all disj first, second: Event |
    first.description = second.description and
    one first.(Left.selectedParty) and
    one second.(Left.selectedParty) implies
      first.(Left.selectedParty) = second.(Left.selectedParty)
}

-- Deliberately too strong: one Party always has one retained description.
assert PartyDeterminesDescription {
  all disj first, second: Event |
    one first.(Left.selectedParty) and
    first.(Left.selectedParty) = second.(Left.selectedParty) implies
      first.description = second.description
}

-- Deliberately too strong: because description is retained, Party identity is
-- uniquely derivable from it across candidate interpretations.
assert DescriptionDeterminesPartyAcrossWorlds {
  all e: Event |
    one e.(Left.selectedParty) and one e.(Right.selectedParty) implies
      e.(Left.selectedParty) = e.(Right.selectedParty)
}

-- Deliberately too strong: every EventDescription implies an external Party.
assert DescriptionPresenceImpliesParty {
  all e: Event | one e.(Left.selectedParty)
}

-- Positive control: once the independent Party overlay itself is held equal,
-- Party queries agree. This does not claim the overlay is yet earned in production.
assert ExplicitPartyEvidenceDeterminesSelectedPartyQuery {
  Left.selectedParty = Right.selectedParty implies
    all e: Event | e.(Left.selectedParty) = e.(Right.selectedParty)
}

run sameDescriptionCanCoverDifferentParties for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
run samePartyCanHaveDifferentDescriptions for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
run exactMerchantTextCanAgreeWithStableParty for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
run descriptionMayNameThingsWithoutSelectingParty for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
run sameDescriptionAllowsDifferentPartyInterpretations for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty

check EqualDescriptionDeterminesParty for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
check PartyDeterminesDescription for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
check DescriptionDeterminesPartyAcrossWorlds for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
check DescriptionPresenceImpliesParty for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty
check ExplicitPartyEvidenceDeterminesSelectedPartyQuery for exactly 2 World, exactly 8 Event, exactly 6 Description, exactly 6 ExternalParty