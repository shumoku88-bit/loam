# Observation 263 — external party identity boundary

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
main: 0e6621a105e881773c61cef88299c434366410d6
latest retained Observation: 262
```

Exact pre-qualification branch head:

```text
85842f67a89e263e9758ddeec7feb3b8ee9c1e53
```

GitHub Actions qualification:

```text
workflow: Observation 263
run:      35171498406
job:      105043941595
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
```

Observed matrix:

```text
sameExternalIdentityAcrossEventAndRelation             SAT
eventOnlyPartyNeedsNoOpenRelation                      SAT
relationOnlyPartyNeedsNoEventCounterparty              SAT
samePartyCanAppearInBothRelationDirections             SAT
samePartyAcrossDifferentLoci                           SAT
sameLocusAcrossDifferentParties                        SAT
NeutralLoamEvidenceDeterminesCounterparty              SAT counterexample
OpenRelationEndpointDeterminesEventCounterparty        SAT counterexample
SelectedEventCounterpartyIsLone                        UNSAT counterexample
```

## Trigger

LOAM now has two independent pressures involving the identity of an outside
actor.

Existing production open-relation vocabulary already has:

```text
ExternalEndpointId
RelationEndpoint = household | external ExternalEndpointId
```

`ExternalEndpointId` is intentionally opaque. It carries no built-in person,
merchant, institution, account, debtor, creditor, or other role meaning.
Observation 172 earned that minimum because recurring open relations with the
same friend need stable identity across occurrences.

A new household query creates a second pressure:

```text
which outside company/person was this Event with?
how much was spent with the same merchant across Events?
```

Today merchant-like recognition is often embedded in `EventDescription`, while
payment stores remain ordinary Loci. Canonical household data makes the
orthogonality concrete:

```text
paypay : LocusId, AccountingRole = ASSET
smbc   : LocusId

Event e0193:
  paypay +1000
  smbc   -1000
  description "smbc→paypay"

Event e0201:
  food +341
  description "三和"

Event record-42:
  paypay -11891
  description contains "モンベル"
```

Therefore a provider/wallet/account label cannot simply be promoted from Locus
to Party, while merchant identity cannot be recovered from quantity placement.

## Terminology survey

The candidate noun is deliberately `Party`, not `Counterparty`, `Payee`,
`Merchant`, or `Agent`.

OASIS UBL 2.5 keeps Party identity separate from business roles such as Seller,
Accounting Supplier, and Payee, and explicitly permits those roles to be held by
different parties. This is evidence that `Payee` and `Seller` are too narrow as
identity nouns.

Reference:

```text
https://docs.oasis-open.org/ubl/UBL-2.5.pdf
```

ISO 20022 payment models similarly distinguish party identification from
role-specific Debtor/Creditor concepts and from the corresponding accounts.
This supports keeping Party identity separate from LOAM Locus identity.

Reference:

```text
https://www.iso20022.org/message/mdr/12666/download/111
```

REA `Agent` remains useful as an interpretation vocabulary, but Observation 251
already established that Agent participation is independent interpretation
evidence rather than something forced by current neutral LOAM Event/Effect data.
`Agent` is therefore not adopted here as a production noun.

## Question

When the same outside actor must be recognized both:

1. as an endpoint of a household open relation; and
2. as selected counterparty evidence for an Event,

is there any semantic reason to maintain two unrelated identity namespaces?

The narrow candidate is:

```text
ExternalParty identity
  shared by
    open-relation endpoint use
    event-counterparty use
```

with every role kept outside identity.

This does **not** yet propose a production rename from `ExternalEndpointId`, a
Party registry, an EventParty persistence stream, or a universal participation
ontology.

## Observation-local model

The Alloy model keeps ordinary LOAM-shaped evidence independent:

```text
Event
Effect -> Event + Locus
```

and introduces one role-free identity space:

```text
Party
  Household
  ExternalParty
```

Open relations use that identity as debtor/creditor endpoints:

```text
RelationUnit
  sourceEffect
  debtor
  creditor
```

A separate candidate Event overlay uses it as:

```text
World.counterparty : Event -> lone ExternalParty
```

`lone` belongs only to this selected-counterparty probe. It is **not** a claim
that an economic Event can have only one real-world participant. Event
participation cardinality and role granularity remain a later question.

## Qualified findings

### O263-1 — one external identity space can serve both uses

`sameExternalIdentityAcrossEventAndRelation` is SAT.

So a role-free external identity can be reused when the same outside actor is
both an Event counterparty and an open-relation endpoint. The bounded model
finds no semantic collision that requires two unrelated identity namespaces.

### O263-2 — identity reuse does not merge the semantic axes

Both of these are SAT:

```text
eventOnlyPartyNeedsNoOpenRelation
relationOnlyPartyNeedsNoEventCounterparty
```

So widening the identity vocabulary does not imply that every merchant-like
Party becomes an obligation endpoint, nor that every relation endpoint must be
selected as Event counterparty.

### O263-3 — debtor / creditor are roles, not identity

`samePartyCanAppearInBothRelationDirections` is SAT.

The same external identity can owe the household in one relation and be owed by
the household in another. Direction remains relation-local semantics.

### O263-4 — Party and Locus are orthogonal

Both directions are witnessed:

```text
samePartyAcrossDifferentLoci      SAT
sameLocusAcrossDifferentParties   SAT
```

Therefore neither payment/account Locus nor external Party determines the other.
This preserves the current strong `LocusId` boundary.

### O263-5 — counterparty evidence is independent retained evidence

`NeutralLoamEvidenceDeterminesCounterparty` has a counterexample.

The same neutral Event / Effect / Locus evidence can admit different selected
counterparty assignments. Party evidence therefore cannot be derived from
quantity placement alone.

### O263-6 — open-relation endpoint does not determine Event counterparty

`OpenRelationEndpointDeterminesEventCounterparty` has a counterexample.

This is important for mixed household cases: one Event may be with a merchant
while one of its effects creates a relation with a friend. Sharing identity type
does not collapse the two relations.

### O263-7 — `lone` is only an observation-local selected view

`SelectedEventCounterpartyIsLone` has no counterexample because the candidate
World relation is explicitly typed `Event -> lone ExternalParty`.

This is only a positive control for the current probe. Observation 263 does not
establish that real economic participation is globally one-party.

## Finding

The qualified boundary is:

```text
External identity
  can be shared across semantic uses

identity
  != open-relation role
  != Event counterparty relation
  != Locus
  != display name
```

The important result is **identity reuse**, not a new ontology.

This removes one reason for introducing a second independent `PartyId` beside
`ExternalEndpointId`: if both refer to the same outside actor, separate opaque
IDs would require an additional crosswalk merely to recover that sameness.

However qualification still does **not** decide the production noun. Two names
remain plausible:

```text
ExternalPartyId    -- semantic widening is explicit
ExternalEndpointId -- retain the earned narrow name until another production use exists
```

Nor does it decide whether Event evidence should be:

```text
Event -> lone Party
Event -> set Party
Event × Role -> Party
```

That cardinality/role question deserves a separate observation because UBL/ISO
show that Seller, Payee, payment intermediary, debtor, and creditor can diverge,
while the current household query often needs only one merchant-like external
identity.

## Stop condition

Do not modify production `OpenRelation`, rename `ExternalEndpointId`, add a Party
catalog, or add Event-party persistence from Observation 263 alone.

The next research step is a separate Event attachment probe over real household
witnesses:

```text
merchant purchase
refund
income/employer
friend reimbursement
self-transfer through financial Loci
seller != payee / intermediary cases
```

That next probe should decide relation vocabulary and granularity without
weakening the existing Locus/Event/Effect boundaries.
