# Observation 269 — merchant production promotion checkpoint

Status: **PROMOTION CHECKPOINT — implementation boundary selected**

Baseline:

```text
shumoku88-bit/loam
main: d9c483d1c7304657b73668b0826a44f9acea26d2
open PRs observed before branch: 0
```

## Trigger

Observations 263–268 established the smallest semantic boundary needed for an
exact cross-Event merchant-spending query.

The retained conclusions are:

```text
O263  one role-free external identity space can be shared across semantic uses
O264  shared identity does not collapse creditor / recipient / merchant relations
O265  EventDescription is recognition evidence, not stable external identity authority
O266  Merchant + Effects + AccountingRole determines merchant-associated Expense
O267  Merchant is the narrow commercial goods/services-provider relation
O268  positive Merchant evidence alone is not coverage-complete
```

O268 therefore leaves a concrete production candidate:

```text
EventMerchantEvidence
  merchant EventId ExternalPartyId
  nonmerchant EventId

absence
  = unresolved
```

No merchant amount is stored. Quantity remains derived from existing Event Effects
and AccountingRole evidence after coverage closes.

## Question

How much of the qualified boundary should enter production now, and where should
it attach without turning LOAM into a generic Party ontology?

This checkpoint inspects the current production seams rather than introducing a
new formal model.

## Current production seams

### Shared external identity

Production open relations currently retain:

```text
ExternalEndpointId
RelationEndpoint.external ExternalEndpointId
```

`ExternalEndpointId` is already an opaque stable identity with no built-in person,
merchant, institution, account, debtor, creditor, or display-name meaning.

Observation 263 qualified reuse of exactly that role-free identity space when the
same outside actor appears in another semantic relation. A second production use
now exists: EventMerchant evidence.

Therefore keeping two unrelated opaque namespaces would create an unnecessary
crosswalk merely to recover actor sameness.

### Actual evidence aggregate

`ActualEvidence` currently aggregates retained Actual-side families:

```text
events
validity
descriptions
corrections
reversals
relations
discharges
```

It is explicitly persistence-neutral and not a second semantic engine.
`EventMerchantEvidence` belongs naturally beside these Event-scoped retained
families.

### Normalized Actual persistence

`NormalizedActualPersistence` already validates, decodes, and encodes retained
Actual evidence per Event. Relation and discharge rows are attached inside each
`TX ... ENDTX` block while admission remains delegated to existing semantic
boundaries.

Merchant disposition can use the same generation without becoming Movement
semantics.

### Movement admission

`MovementAdmission.Draft` currently contains the evidence needed to admit one new
Movement:

```text
validOn
description
effects
relations
discharges
total
```

Merchant classification is not required for Event existence, balancing, Locus
admission, open-relation publication, or discharge publication. O268 also requires
incremental classification of already-retained Events.

Therefore Merchant must not become a required Movement draft field.

A future convenience entrance may publish Merchant evidence immediately after a
Movement is created, but the semantic publisher must remain independently usable.

## Production decision

### 1. Widen the shared identity noun

Promote the existing role-free coordinate from:

```text
ExternalEndpointId
```

to:

```text
ExternalPartyId
```

and keep:

```text
structure ExternalPartyId where
  token : String
```

The rename expresses the already-qualified widening of use. It does not introduce
a Party registry or any role semantics.

`RelationEndpoint.external` continues to reference the same opaque identity type.
No relation behavior changes.

### 2. Add only query-specific Merchant disposition

The minimum Core vocabulary is conceptually:

```text
inductive MerchantDisposition where
  | merchant (party : ExternalPartyId)
  | nonmerchant

structure EventMerchantEvidence where
  event : EventId
  disposition : MerchantDisposition
```

There is at most one retained disposition per Event.

There is deliberately no `unresolved` constructor:

```text
missing evidence = unresolved
```

This preserves the O268 distinction between unknown and explicitly outside the
Merchant relation.

### 3. Keep Merchant as an independent evidence family

The first production writer should be an EventMerchant-specific publisher with an
explicit read / admit / publish protocol.

It must support classification of an already-retained Event and refuse:

```text
missing Event target
duplicate disposition for one Event
malformed ExternalPartyId token
```

Replacement, deletion, aliases, Merchant merging, and identity renaming are not
qualified and must not be smuggled into the first publisher.

### 4. Persist Merchant in Actual authority

`ActualEvidence` should gain one Merchant evidence memory/list, and normalized
Actual wire should encode one optional disposition per Event.

The wire distinction must remain explicit:

```text
no merchant row       -> unresolved
merchant row + party  -> retained Merchant
nonmerchant row       -> explicitly outside EventMerchant
```

The decoder must reject more than one disposition for the same Event and reject
Merchant evidence whose Event is absent.

### 5. Query exactness remains separate from storage

A merchant-spending query may derive signed Expense from:

```text
EventMerchantEvidence
+ Event Effects
+ AccountingRole(expense)
```

but may call the result exact only when every relevant Event in the requested
window has one retained Merchant disposition.

Storage therefore owns evidence, not a stored merchant amount and not an
`isComplete` flag. Coverage completeness is derived from the requested Event
window plus retained dispositions.

## Explicit non-goals

Do not add any of the following in this promotion:

```text
Party registry
Party display-name table
PartyRole enum
generic EventParty
Event -> set Party
Event x Role -> Party
Payee
PaymentRecipient
IncomePayer
Merchant amount
Effect-level seller attribution
merchant-of-record ontology
legal-company / branch / franchise hierarchy
alias / merge history
AI-inferred Merchant as canonical authority
```

AI or text parsing may propose a Merchant disposition, but canonical authority
starts only after the explicit Merchant publisher admits and retains it.

## Implementation slicing

The promotion should be staged so each change has one independent reason.

### Slice A — shared identity widening

```text
ExternalEndpointId -> ExternalPartyId
RelationEndpoint.external uses ExternalPartyId
all existing open-relation behavior unchanged
```

This slice is mechanical semantic widening and should contain no Merchant
persistence.

### Slice B — raw Merchant evidence + memory/admission

```text
MerchantDisposition
EventMerchantEvidence
unique Event disposition memory
Event reference closure
```

No UI and no aggregate query yet.

### Slice C — normalized Actual persistence + authority preservation

Add Merchant evidence to `ActualEvidence`, normalized Actual encode/decode/admit,
and every Actual publisher that reconstructs/preserves the aggregate.

This slice must prove that unrelated Actual mutations preserve Merchant evidence.

### Slice D — independent Merchant publisher

Add one narrow production write path for classifying an existing Event as either:

```text
merchant ExternalPartyId
nonmerchant
```

No replacement semantics in this slice.

### Slice E — read projection / exact merchant query

Only after retained evidence is writable, add the query that joins Merchant,
Effects, and AccountingRole and surfaces incomplete coverage rather than silently
returning a partial total as exact.

## Why Merchant is not inserted into Movement first

Making Merchant part of `MovementAdmission.Draft` would couple Event creation to a
classification that:

1. is not required for Movement semantic validity;
2. must also be applicable to historical Events;
3. may remain unresolved legitimately;
4. has its own future change pressure independent of Movement effects.

That would place the dependency in the wrong direction.

The preferred direction is:

```text
Movement publication -> Event exists
Merchant publisher    -> optionally classifies that Event later
```

A UI/AI entrance may eventually compose those operations for convenience without
merging their semantic authorities.

## Stop condition

Production promotion stops after the first exact merchant-query seam exists.

Do not generalize from one earned relation into a universal Party framework.
Future creditor, payment-recipient, income-payer, insurer, tax-authority, or other
external-actor queries must earn their own specific relation while reusing the
shared `ExternalPartyId` coordinate when actor identity is genuinely the same.
