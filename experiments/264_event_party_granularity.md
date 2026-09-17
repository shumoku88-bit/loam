# Observation 264 — event party granularity

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
main: 0e6621a105e881773c61cef88299c434366410d6
stacked on Observation 263 branch head: dd288b985ede2f10d6101b3de915b10c3f1ea8c5
```

Exact pre-qualification branch head:

```text
33e829ea3c9b0740098312ac6895529d26f3fb75
```

GitHub Actions qualification:

```text
workflow: Observation 264
run:      35172464436
job:      105046855455
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
```

Observed matrix:

```text
currentAndArrearsShareCreditor                 SAT
onePaymentDischargesCurrentAndArrears          SAT
onePaymentDischargesRentAndRenewal             SAT
landlordAndCollectionRecipientDiffer           SAT
oneEventHasTwoRelevantExternalParties          SAT
selfTransferNeedsNoExternalParty               SAT
simplePaymentFitsLoneCounterparty              SAT
CreditorDeterminesObligationIdentity           SAT counterexample
SelectedCounterpartyDeterminesCreditor         SAT counterexample
LoneCounterpartyCoversAllRelevantParties       SAT counterexample
SelectedEventCounterpartyIsLone                UNSAT counterexample
```

## Trigger

Observation 263 qualified a narrow identity result:

```text
one role-free external identity space
can be shared by
  open-relation endpoint use
  Event-level selected counterparty use

identity != role != Locus
```

It deliberately did **not** decide how Party-like identity should attach to an
Event. The next pressure comes from ordinary household cases where "who was this
with?" and "what did this payment settle?" are not the same question.

Representative witnesses:

```text
health insurance
  current premium
  overdue premium
  one payment may settle both
  same insurer, distinct obligations

housing
  monthly rent
  renewal fee
  one payment may settle both
  landlord may be creditor
  management/collection company may receive payment

self transfer
  SMBC -> PayPay
  multiple Loci
  no external household counterparty required
```

These cases ask whether a canonical:

```text
Event -> lone Party
```

is semantic authority, merely a convenient recognition projection, or already
too coarse.

## Existing production boundary

LOAM already has the more specific open-relation semantics:

```text
RelationUnit
  source Event + Effect
  debtor endpoint
  creditor endpoint
  exact quantity

RelationDischarge
  later Event
  target RelationUnit
  exact quantity
```

The important existing rule is that relation identity is independent from the
endpoint pair. Two obligations may therefore involve the same external identity
without becoming the same relation.

This observation preserves that boundary rather than replacing it with Party.

## Observation-local vocabulary

The Alloy model introduces only enough extra vocabulary to make the household
pressure explicit.

```text
Party
  Household
  ExternalParty

Obligation
  debtor
  creditor
  kind

Discharge
  Event -> Obligation

PaymentRecipientFact
  Event -> ExternalParty

World.counterparty
  Event -> lone ExternalParty
```

`ObligationKind` has four observation-local witness atoms:

```text
InsuranceCurrent
InsuranceArrears
Rent
RenewalFee
```

They are not proposed production enums. They exist only to prove that two
obligations involving the same parties can remain semantically distinct.

`PaymentRecipientFact` is also observation-local. It represents the narrower
question "who directly received this payment?" so it can be compared with the
creditor carried by an obligation.

## Qualified boundaries

### O264-1 — Party identity does not identify the obligation

Both insurance and housing witnesses are SAT:

```text
same insurer
  current premium
  overdue premium

same landlord
  rent
  renewal fee
```

A single payment may discharge either pair. `CreditorDeterminesObligationIdentity`
has a counterexample, so the Party at one endpoint cannot replace retained
obligation / RelationUnit identity.

### O264-2 — creditor and direct payment recipient are independent

`landlordAndCollectionRecipientDiffer` is SAT and
`SelectedCounterpartyDeterminesCreditor` has a counterexample.

Therefore the household can owe one Party while directly paying another Party.
A selected Event counterparty cannot be treated as canonical creditor authority.

### O264-3 — one Event may expose several relevant external identities

`oneEventHasTwoRelevantExternalParties` is SAT and
`LoneCounterpartyCoversAllRelevantParties` has a counterexample.

So a `lone` selected counterparty may remain useful as a recognition projection,
but it cannot losslessly replace every Party-bearing semantic relation around an
Event.

This result does **not** automatically earn `Event -> set Party`. The two
identities in the witness are already owned by different specific relations:
creditor through the obligation, direct recipient through payment-recipient
evidence.

### O264-4 — some Events need no external Party

`selfTransferNeedsNoExternalParty` is SAT. A household self-transfer can touch
multiple Loci while requiring no outside actor relation at all.

This protects the current Locus boundary: provider/account names need not be
promoted into Party merely because a transfer crosses those Loci.

### O264-5 — cheap lone recognition remains possible

`simplePaymentFitsLoneCounterparty` is SAT and the positive-control assertion
`SelectedEventCounterpartyIsLone` has no counterexample in the bounded model.

So the observation rejects `lone counterparty` as a universal semantic authority,
not as a useful optional projection for common merchant-like recognition.

## Finding

The qualified result is deliberately asymmetric.

A role-free external identity remains useful:

```text
Party identity
  answers: which outside actor is this?
```

But obligation semantics remain more specific:

```text
RelationUnit / Obligation identity
  answers: what exactly is owed?

Discharge
  answers: which obligation did this Event settle?
```

And payment-recipient semantics can differ again:

```text
creditor != direct payment recipient
```

Therefore the bounded evidence rejects this compression:

```text
all household Who semantics
  -> Event -> lone Party
```

without rejecting a lightweight selected-counterparty projection for recognition
or common merchant queries.

The qualified shape is closer to:

```text
shared external Party identity

specific semantic relations
  RelationUnit.debtor / creditor
  RelationDischarge.target
  payment-recipient evidence, if real pressure earns it

optional convenience projection
  Event -> lone selected counterparty
```

Discovering two relevant Parties around one Event does not automatically earn a
generic:

```text
Event -> set Party
```

or:

```text
Event x Role -> Party
```

Those structures would duplicate information already owned by specific
relations unless a new query requires generic participation independently.

## Why this matters for Locus

Self-transfer is the important negative control.

```text
SMBC -> PayPay
```

is naturally represented by Locus/Effect structure and need not invent an
external Party merely because the real-world providers have names. Conversely,
a merchant or landlord Party cannot be derived from the payment Locus used.

So the desired boundary remains:

```text
Locus
  where quantity is observed

Party identity
  which outside actor is referenced by a semantic relation
```

No provider/account/merchant ontology is folded into either identity.

## Stop condition

Do not add production `Party`, `EventParty`, `PaymentRecipient`, or role enums
from Observation 264 alone.

The next decision should be practical rather than ontological:

- identify the first concrete household query that cannot be answered today;
- determine the smallest independent relation needed for that query;
- only then choose whether production should widen `ExternalEndpointId`, add a
  selected Event counterparty relation, or retain merchant recognition in
  description until stronger pressure exists.
