# Observation 267 — merchant vocabulary / coverage boundary

Status: **TERMINOLOGY REVIEW — no new formal model required**

Baseline:

```text
shumoku88-bit/loam
main observed before review: a3191d8bde5182a28c270a7c62a9c19ae90422a0
stacked on Observation 266 branch head: 7c6424cf3e8857ffc7c9486d36ea4f4b2b778dc0
```

## Trigger

Observations 263–266 qualified the structural boundary before choosing production
vocabulary.

The narrow query shape earned by Observation 266 is:

```text
query-specific external identity
  + existing Event Effects
  + explicit AccountingRole(expense)
  -> exact signed cross-Event Expense quantity
```

with the current smallest relation shape:

```text
EventId -> lone shared external identity
```

The unresolved question is now lexical and semantic:

> What should the relation be called, and which household Events should it cover?

This is not a question Alloy can settle. The candidate names encode human and
standards expectations rather than a finite structural invariant. O267 therefore
uses a terminology/coverage matrix instead of introducing another logical model.

## Existing LOAM boundaries remain fixed

O267 does not reopen these results:

```text
external identity != Locus
external identity != EventDescription
merchant-like relation != creditor
merchant-like relation != payment recipient
merchant-like relation != generic selected counterparty
merchant-like relation != stored amount
```

The identity space may eventually be shared with current `ExternalEndpointId`, but
the relation name must state the meaning of this particular Event/identity edge.

## Candidate vocabulary

### Merchant

Useful meaning for LOAM:

```text
an external commercial party from whom the household acquires goods or services
in this Event
```

The relation is about the commercial source of the acquired good/service. It is
**not** defined by the payment rail and is **not** the payment recipient.

Strengths:

- natural for supermarkets, convenience stores, retailers, restaurants, online
  shops, SaaS subscriptions, and ordinary commercial service providers;
- narrower than `Counterparty`;
- does not inherently mean creditor, payee, acquirer, processor, or account
  provider;
- ISO 20022 card terminology explicitly distinguishes a Merchant providing goods
  and services from the card Acceptor, Acquirer, Issuer, and intermediary roles;
- preserves O266's concrete household question: "how much did I spend with this
  commercial provider?"

Risk:

- payments standards often use Merchant inside card-payment contexts, so an
  implementation must explicitly state that LOAM's relation is payment-rail
  independent;
- `merchant of record` in commerce/payment systems can differ from the service
  brand/provider a household wishes to aggregate by. LOAM must not silently import
  that legal/payment-industry meaning.

### Seller

Strengths:

- strongly role-specific;
- OASIS UBL keeps Seller separate from Accounting Supplier and Payee, which is
  structurally close to the boundary O264 discovered.

Weaknesses for the current household surface:

- reads naturally for goods but less naturally for recurring services such as
  software subscriptions or telecom;
- can invite a legal-contract interpretation when the household query may instead
  want the recognizable commercial provider;
- marketplace / merchant-of-record arrangements can still make legal seller and
  service provider differ.

### Supplier

Strengths:

- broad enough for goods and services;
- established in procurement/accounting systems.

Weaknesses:

- UBL uses Supplier Party as a broader structural family containing distinct roles
  such as Seller and Accounting Supplier, while Payee remains separately
  representable;
- therefore `Supplier` is too easy to read as a family that includes billing,
  creditor, or settlement meaning;
- enterprise/procurement vocabulary is less natural for everyday retail household
  records.

### Vendor

Strengths:

- common accounting/ERP word for a commercial seller/provider;
- covers goods and services in ordinary business language.

Weaknesses:

- often functions as an accounts-payable master identity, which can blur seller,
  invoice issuer, creditor, and payee;
- no advantage over `Merchant` is strong enough to justify importing that wider
  enterprise implication into the first household relation.

### Provider

Strengths:

- comfortable for SaaS, telecom, utilities, and other services.

Weaknesses:

- unnatural for many ordinary retail purchases;
- too broad: landlords, insurers, public bodies, information providers, and
  intermediaries can all be called providers in some context;
- therefore it does not protect the O264 distinction as well as `Merchant`.

### Counterparty

Rejected for this relation.

It describes an opposing/external party to a transaction or relationship but does
not explain *why* that identity matters here. A landlord/creditor, collection
company, friend, merchant, insurer, or employer can all be counterparties.

Using it here would recreate the generic `Who` bag that Observation 264 rejected.

### Payee

Rejected for this semantic relation.

Household/plain-text accounting tools commonly use Payee as a convenient
transaction label, and that is useful UX. But Payee answers a payment/transaction
surface question, not necessarily "who supplied the acquired good or service?".

Actual Budget also represents account transfers through its Payee abstraction,
which is good application ergonomics but intentionally broader than the LOAM
semantic boundary sought here.

UBL likewise keeps Payee distinct from Seller and Accounting Supplier.

## Coverage matrix

The candidate `Merchant` relation should be tested by *meaning*, not by whether a
company name appears in a description or receives money.

| Household shape | Merchant? | Reason |
| --- | --- | --- |
| supermarket / convenience-store purchase | yes | ordinary commercial goods provider |
| clothing / outdoor retail purchase | yes | ordinary commercial goods provider |
| restaurant / cafe | yes | ordinary commercial goods/service provider |
| direct SaaS subscription | yes | commercial service provider |
| direct cloud/storage subscription | yes | commercial service provider |
| telecom mobile plan | yes, when modeled as ordinary commercial service acquisition | commercial service provider |
| ordinary utility bought from a commercial provider | potentially yes | same commercial-provider question, if household actually wants aggregation |
| merchant refund / purchase reversal | yes, when it reverses or adjusts the same commercial relationship | signed Expense query can derive the monetary effect |
| rent payment to landlord | no | landlord/creditor relation is different pressure |
| rent sent to management/collection company | no | payment-recipient relation is different pressure |
| public health-insurance premium | no | obligation/insurer or public-body relationship, not ordinary commerce query |
| overdue health-insurance payment | no | obligation/discharge identity remains primary |
| tax payment | no | tax authority / obligation relation |
| repayment to friend | no | relation endpoint / creditor-debtor semantics |
| friend reimbursement received | no | relation endpoint / discharge semantics |
| salary / pension received | no | income-source/employer/payer relation is a different query |
| SMBC -> PayPay self transfer | no | Locus-to-Locus movement; no external commercial provider required |
| payment processor/acquirer only | no | payment infrastructure is not the commercial provider |

This matrix is intentionally asymmetric. O267 does **not** attempt to give every
external party a single Event role.

## OpenAI / app-store / marketplace pressure

A useful counterexample is a service brand whose payment path contains another
company.

Possible real-world shape:

```text
household acquires service from Provider A
payment is collected / legally sold / processed by Platform B
funds travel through Processor C
```

The O266 query should not force all three into one identity.

For the proposed LOAM `Merchant` relation, the intended identity is the household's
retained commercial provider for the acquired good/service **when that is the
question the household wishes to aggregate**.

If future pressure requires legal seller / merchant-of-record / payment recipient
identity, those must be separate relations rather than alternate interpretations
of one `Merchant` fact.

This is the same discipline already qualified for landlord vs collection recipient.

## Identity granularity

The relation does not answer whether identity is:

```text
brand
legal company
franchisee
physical branch
merchant-of-record account
```

That distinction remains query-driven.

For the current household query, the smallest useful rule is:

> Two Events share a Merchant identity exactly when the household intends the
> merchant-spending query to aggregate them as the same commercial provider.

This mirrors `LocusId`: identity is opaque, while legal/accounting meaning is not
encoded into the token itself.

A later branch/location query may add another orthogonal relation rather than
splitting Merchant identity prematurely.

## Relationship to user-facing `Payee`

A future UI or AI layer may still say "payee" colloquially because that term is
familiar in household accounting tools.

But the semantic API should not return one ambiguous field pretending to answer
all of these:

```text
merchant/provider
payment recipient
creditor
relation endpoint
income payer
transfer account
```

If a convenience projection is eventually exposed, it must be typed/labeled as a
recognition view rather than canonical authority, preserving Observation 264.

## Decision

For the **first exact cross-Event commercial-spending query**, retain `Merchant` as
the leading production relation name.

Proposed meaning:

```text
EventMerchant
  EventId -> lone shared external identity

meaning:
  the retained external commercial provider from whom the household regards this
  Event as acquiring goods or services
```

Explicit non-meanings:

```text
Merchant != generic counterparty
Merchant != payee / direct recipient
Merchant != creditor
Merchant != payment processor/acquirer
Merchant != account provider / Locus
Merchant != legal merchant-of-record unless explicitly the retained identity
```

This makes `Merchant` narrower than the identity type. The shared identity type may
later receive another name, but this Event edge keeps its own query-specific
semantics.

## Why not promote immediately?

O267 resolves the naming/coverage question strongly enough for a production
candidate, but it still does not prove that the household currently needs a
persisted Merchant relation enough to justify migration and UI surface.

The promotion criterion remains:

```text
The household wants exact cross-Event commercial-provider aggregation,
and Description/AI inference is not acceptable as canonical authority.
```

If that requirement is accepted, the next step should be a small production seam:

```text
opaque shared external identity
EventMerchant : EventId -> lone identity
persistence for explicit Merchant evidence
read projection joining EventMerchant + existing Effects + AccountingRole
```

Do not add a Party registry, PartyRole enum, generic EventParty relation, merchant
amount field, or Effect-level seller attribution at the same time.

## External terminology references

- OASIS UBL 2.5, Party Roles and Invoice/Order models:
  https://docs.oasis-open.org/ubl/UBL-2.5.html
  https://docs.oasis-open.org/ubl/cs01-UBL-2.5/mod/summary/reports/UBL-Invoice-2.5.html
- ISO 20022 card/retail terminology, where Merchant is distinct from Acceptor,
  Acquirer, Issuer, and intermediary roles:
  https://www.iso20022.org/cards-and-related-retail-financial-services-standards-evaluation-group
- Actual Budget Payee semantics and transfers:
  https://actualbudget.org/docs/transactions/payees/
  https://actualbudget.org/docs/transactions/transfers/
- Ledger payee query surface:
  https://ledger-cli.org/doc/ledger3.html

## Stop condition

Do not broaden `Merchant` merely to make every external identity fit one field.

If a future query asks "how much did I pay this recipient?", "how much debt did I
discharge to this creditor?", or "how much income came from this payer?", earn the
smallest relation for that question separately.
