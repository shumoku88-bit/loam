# Observation 162: Do shared-cost settlement and deferred card payment share a smaller obligation / settlement boundary?

Status: bounded Alloy observation prompted by two recurring household patterns that look different at the UI level but both separate an economic meaning from later settlement.

- In shared-cost transport, the household may physically pay the whole cost while another person is economically responsible for part of it, leaving an amount expected back later.
- In a credit-card purchase, the household economically incurs the cost now while bank cash may not move until a later card settlement.

Observation 161 remains an independent open observation. This model is intentionally based directly on `main` and does not assume Observation 161's candidate vocabulary is already accepted.

## Question

The two patterns point in opposite directions:

```text
shared cost
outside party -> household

credit card
household -> card issuer
```

Yet both appear to have the shape:

```text
an obligation-like relation exists
then a later event settles part or all of it
```

This observation asks:

> Is there a useful common boundary below `advance`, `reimbursement`, `credit-card payment`, and `receivable/payable`: a directional obligation plus later settlement, kept independent from economic burden and physical cash movement?

It also asks what must *not* be collapsed into that boundary.

## Observation-local abstraction

The model uses unit-count quantities. It deliberately does not reuse or propose a production `Account`, `Liability`, `Receivable`, `Payable`, `Card`, or `Party` type.

A `World` records four distinct observation-local facts:

```text
incurred units
household burden units
open directional claims
physical cash in / out
```

Each claim has:

```text
debtor -> creditor
```

and may later become `settled`.

For household-relative queries, a claim can therefore be projected as either:

```text
household payable
household receivable
```

without storing a payable or receivable amount separately.

The terms `claim`, `debtor`, and `creditor` are observation vocabulary only. The production vocabulary remains undecided.

## Scenario A: shared cost

For a two-unit transport cost paid fully by the household:

```text
incurred          2
cash out          2
household burden  1
friend share      1
```

The friend share is represented observation-locally by a directional open relation:

```text
Friend -> Household
```

Before settlement:

```text
household receivable outstanding = 1
```

Later PayPay receipt settles that unit. The household burden remains one unit. Only the outstanding relation and physical cash state change.

## Scenario B: credit-card purchase

For a two-unit card purchase:

```text
incurred          2
household burden  2
bank cash out     0 at purchase time
```

The card-financed amount is represented observation-locally by:

```text
Household -> CardIssuer
```

Before card settlement:

```text
household payable outstanding = 2
```

A later bank debit settles some or all of that relation. It changes cash and outstanding obligation, but it must not create the household expense again.

## Probes

### 1. A shared-cost open relation is representable

The household may pay two units physically, bear only one unit economically, and have one unsettled `Friend -> Household` relation.

Expected: **SAT**.

This is the recurring cost-sharing / advance shape.

### 2. A card purchase open relation is representable

The household may incur and bear two units, move no bank cash yet, and have two unsettled `Household -> CardIssuer` relations.

Expected: **SAT**.

This captures the important separation between purchase-time burden and later bank debit.

### 3. The same settlement core supports opposite directions

One pair of worlds settles a household receivable and another pair settles a household payable.

The common transition is:

```text
same incurred meaning
same burden allocation
same directional relation
+ one relation unit becomes settled
```

The physical cash direction differs:

```text
receivable settlement -> cash in
payable settlement    -> cash out
```

Expected: **SAT**.

Therefore `Settlement` alone is too weak, but a settlement of a prior directional relation is plausibly common to both patterns.

### 4. Card settlement changes cash without changing household burden

A one-unit card purchase is already household burden before bank debit. Settling the card relation moves one cash-out unit and reduces payable outstanding from one to zero while household burden stays unchanged.

Expected: **SAT**.

This is the anti-double-counting witness: later card debit is not a second expense.

### 5. Direct purchase does not require an obligation

A household-borne cost may be paid immediately with cash out and no open relation at all.

Expected: **SAT**.

This is a stop condition against making every cost create a liability-like object merely because some costs do.

### 6. Incurred obligation decomposes into settled plus outstanding

For both household payables and household receivables:

```text
total directional relation
=
settled relation
+
outstanding relation
```

Expected check: **UNSAT counterexample**.

Outstanding is therefore naturally a projection rather than stored state in this bounded model.

### 7. Settlement cannot alter burden through the common settlement core

If incurred units, burden allocation, and the directional relation are held fixed, settling one unit cannot alter household burden.

Expected check: **UNSAT counterexample**.

### 8. One settlement discharges exactly one previously outstanding relation unit

The common settlement core removes exactly the settled unit from the outstanding set and does not silently rewrite the remaining relation.

Expected check: **UNSAT counterexample**.

## Candidate finding

If the expected matrix holds, shared-cost settlement and deferred card payment appear to share a real but narrow foundation:

```text
directional open relation
+ later settlement / discharge
-> derived outstanding
```

That foundation does **not** replace burden allocation or physical movement.

A useful semantic picture is therefore closer to orthogonal axes:

```text
physical movement
burden
open obligation-like relation
settlement
```

rather than one large transaction-kind hierarchy.

The direction matters:

```text
outside -> household   can project as receivable-like
household -> outside   can project as payable-like
```

but `receivable` and `payable` need not be canonical stored balances if they can be derived from directional relation evidence and settlement evidence.

## Why this is more general than credit cards

If later observations preserve the boundary, the same shape may cover:

- credit cards;
- post-pay services;
- invoices and bills incurred before payment;
- a friend owing the household after a shared purchase;
- the household owing someone who paid on its behalf;
- employer or organization reimbursement claims;
- partial settlement over multiple later payments.

The human-facing words can remain different while sharing one semantic substrate.

## What remains distinct

The observation does **not** say that all of these are the same economic event.

In particular:

- burden answers who economically bears the cost;
- a directional obligation-like relation answers who still owes whom;
- physical movement answers where money actually moved;
- settlement answers which prior open relation has been discharged.

A credit-card purchase can be household burden while still unpaid. A friend's shared-cost unit can be outside burden even though the household already physically paid it.

That distinction is the point of the model.

## What this does not earn

This observation does **not** yet earn:

- a production `Obligation` entity;
- a production `Claim`, `Receivable`, `Payable`, or `Liability` type;
- a `CreditCardTransaction` transaction kind;
- stored outstanding balances;
- a global Party / Person registry;
- automatic monthly card-statement machinery;
- a second accounting database;
- double-entry vocabulary in the neutral Event core;
- a requirement that every purchase create an obligation relation;
- rewriting historical card or reimbursement records.

The eventual production anchor is deliberately open. A directional relation might reference existing Event identity, a later effect identity, or another structure earned by further observations.

## Stop condition

Do not introduce a generic obligation subsystem merely because credit cards and advances can be described with one.

The concept becomes implementation pressure only when LOAM must answer a real question that movement + burden evidence cannot answer, for example:

```text
how much card obligation is still unpaid?
how much is still expected back from outside?
which later payment settled which prior obligation?
```

Until then, keep this as an observed semantic boundary rather than a new household ontology.
