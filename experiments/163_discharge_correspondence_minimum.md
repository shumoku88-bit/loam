# Observation 163: Can settlement state collapse to an Event-to-relation discharge correspondence?

Status: bounded Alloy observation following independent Observations 161 and 162.

Observation 161 found recurring pressure to keep economic burden separate from physical payment and later shared-cost settlement. Observation 162 independently found a narrow common substrate under shared-cost receivables and deferred card payables: a directional open relation plus later discharge.

This observation asks whether that vocabulary can be reduced further before anything reaches the Practical Core.

## Question

Observation 162 used an observation-local `settled` set. A production design could easily turn that into new ontology:

```text
Settlement
SettlementId
SettlementStatus
Receivable
Payable
OutstandingBalance
```

But the household already has retained Event identity for actual occurrences.

The smaller possibility is:

```text
open directional relation unit
+
explicit correspondence from a later Event to the relation unit it discharges
```

Then:

```text
settled      = has a discharge Event
outstanding  = has no discharge Event
payable      = direction is Household -> Outside
receivable   = direction is Outside -> Household
```

This observation tests whether that smaller shape still handles the important cases, including batching and partial settlement.

## Observation-local abstraction

The model deliberately has no `Settlement` signature, no settlement identity, and no stored settled/outstanding status.

It retains only:

```text
Event
Unit
Party boundary
incurred / burden evidence
open directional claim units
debtor / creditor direction
origin Event for each incurred unit
physical cash movement by Event
Event -> claim-unit discharge correspondence
```

`Claim`, `debtor`, and `creditor` remain observation vocabulary only. This does not propose a generic Practical Core `Relation` superclass.

The model derives:

```text
discharged
outstanding
household payable outstanding
household receivable outstanding
outstanding by origin Event
```

No amount among these is stored as state.

## Probe 1: one later Event may discharge claims from multiple origins

A normal card statement can contain purchases from more than one earlier occurrence, while one later bank debit settles all of them.

The model therefore asks for two claim units with different origin Events and one later Event whose discharge correspondence covers both.

Expected: **SAT**.

This rejects an eager one-settlement-object-per-origin assumption.

## Probe 2: one origin may be discharged across multiple later Events

An obligation can be settled partially. Two units from one origin Event may be discharged by two distinct later Events.

Expected: **SAT**.

This rejects an eager one-origin-to-one-settlement assumption.

Together with Probe 1, the useful shape is many-to-many at the quantity-unit boundary even when human UI presents one bill or one repayment.

## Probe 3: physical movement does not reconstruct discharge provenance

Two worlds retain exactly the same:

```text
Events
incurred units
burden
claim units
debtor / creditor direction
origin correspondence
cash-in / cash-out movement
```

Only the mapping from the later payment Event to the claim unit it discharges differs.

Total outstanding is the same, but outstanding by origin differs.

Expected: **SAT**.

Therefore the discharge correspondence carries independent information. It cannot be inferred safely merely by equal quantities, dates, counterparty direction, or one plausible candidate.

This is analogous to earlier LOAM relation-family observations: endpoint content does not reconstruct selected correspondence.

## Probe 4: payable and receivable names can remain projections

One world contains both directions:

```text
Household -> Outside
Outside   -> Household
```

without distinct stored payable or receivable kinds.

The household-relative projections identify one of each.

Expected: **SAT**.

This supports keeping `Payable` and `Receivable` as presentation/query vocabulary unless stronger pressure later earns separate semantics.

## Probe 5: ordinary immediate movement needs no open relation

A directly paid household expense can have Event movement and burden but no directional claim and no discharge correspondence.

Expected: **SAT**.

This is the stop condition against routing every payment through an obligation subsystem.

## Checks

### Claim relation partitions into discharged and outstanding

Every retained claim unit is exactly one of:

```text
discharged
outstanding
```

Expected check: **UNSAT counterexample**.

### Claim + discharge correspondence determines outstanding

If two worlds have the same claim units, retained Events, and discharge correspondence, changes to unrelated physical movement presentation cannot change which claim units remain outstanding.

Expected check: **UNSAT counterexample**.

### One claim unit cannot be discharged twice

Within this bounded current-view model, a unit can be linked to at most one discharge Event.

Expected check: **UNSAT counterexample**.

This is a bounded identity law, not yet a production correction policy. Reversal, correction, supersession, and contested settlement remain outside this observation.

## Candidate finding

If the expected matrix holds, Observations 161-163 support a smaller semantic picture than a transaction-kind hierarchy:

```text
existing Event / movement evidence

burden allocation evidence          (independent axis)

directional open-relation evidence (independent axis)

typed discharge correspondence:
  later Event -> open relation quantity

projections:
  settled
  outstanding
  payable
  receivable
  reimbursement / advance / card-payment presentation
```

The important reduction is:

```text
Settlement entity / status
```

is not needed merely to answer the bounded questions tested here. Existing Event identity can identify the later physical occurrence; explicit discharge correspondence says what that occurrence settled.

## Why the discharge correspondence must still be explicit

Removing a `Settlement` object does **not** mean inferring settlement from movement.

Probe 3 deliberately shows:

```text
same movement facts
-/->
same discharge provenance
```

So the reduction is from a first-class settlement object to a typed relation-shaped fact, not from explicit meaning to heuristics.

This also respects the earlier relation-family audit. LOAM should share the mechanical shape only where a law survives domain-name removal, while preserving typed semantics at the application boundary.

## What remains distinct

This observation does not collapse:

```text
movement
burden
open obligation-like relation
discharge provenance
```

In particular, claim direction does not replace burden allocation. Observation 163 only asks whether settlement *state/object vocabulary* can be removed.

## What this does not earn

This observation does **not** yet earn:

- a production `Claim` or `Obligation` type;
- a universal `Relation` type;
- a `Settlement` type or `SettlementId`;
- stored `settled`, `outstanding`, `payable`, or `receivable` balances;
- a Party / Person registry;
- statement or billing-cycle machinery;
- automatic matching by quantity/date;
- correction or reversal semantics for discharge correspondence;
- historical backfill without source evidence;
- Practical Core, persistence, CLI, or wire-format changes.

## Implementation threshold

Retain a practical discharge correspondence only when a real operation needs an answer such as:

```text
which earlier obligation did this PayPay receipt settle?
which card purchases remain unpaid after this debit?
how much of this shared cost is still expected back?
```

At that point, prefer the smallest typed evidence that preserves the correspondence. Do not first build a generic accounts-receivable / accounts-payable subsystem.

## Stop condition

If current household questions can still be answered from existing movement evidence, keep Observation 163 as an observed boundary.

If implementation pressure arrives, first attempt:

```text
existing Event identity
+ narrowly typed directional relation evidence
+ narrowly typed Event-to-relation discharge evidence
```

before introducing any first-class Settlement ontology.
