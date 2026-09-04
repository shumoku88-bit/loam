# Observation 161: Does recurring shared-cost settlement require a Reimbursement concept, or a more general burden boundary?

Status: bounded Alloy observation prompted by recurring private-household transport-cost sharing. The household repeatedly pays a real transport cost, another person agrees to bear part of that cost, and a later PayPay receipt settles that agreed share.

## Question

The existing canonical household history can represent the settled cash shape compactly:

```text
payment account increases
transport expense decreases
```

That is a useful final net-expense projection. But the same movement shape can also arise from a merchant refund, and before the other person's share is received the current net-expense view cannot say how much of the gross cost is ultimately the household's burden and how much remains externally owed.

This observation asks:

> Is `Reimbursement` itself the missing primitive, or is the reusable structure smaller and more general: allocate economic burden independently from physical payment, then record settlement independently from that allocation?

A second question is deliberately kept separate:

> Does LOAM need stable counterparty identity immediately, or only when the household asks per-person outstanding questions?

## Real household pressure

The private canonical history already contains repeated transport-cost settlements of this shape, including a current occurrence. This is not a speculative edge case.

The existing negative-transport-expense representation is not declared wrong. Once a shared amount has been fully received, it gives the desired net household expense. The pressure appears when LOAM must answer questions such as:

- what was the household's own share of this cost before settlement?
- how much is still expected from someone else?
- was this offset a merchant refund or settlement of another person's agreed share?
- how much is outstanding from one particular person?

Those questions may require information that final movement totals cannot reconstruct.

## Observation-local abstraction

The Alloy model uses unit-count quantities. It intentionally ignores LOAM's exact Quantity algebra and does not propose a production `Cost`, `Bearer`, or `Receivable` type.

Each paid `Unit` belongs to one abstract `Cost` and is allocated to exactly one observation-local `Bearer`:

```text
Household
Outside
```

An offset of a paid unit has one of two meanings:

```text
MerchantRefund
SharedSettlement
```

A merchant refund applies to a household-borne unit. A shared settlement applies to an outside-borne unit and marks that unit settled.

The model derives three quantities:

```text
net expense
household burden
aoutside outstanding
```

where the intended decomposition is:

```text
net expense = household burden + outside outstanding
```

The spelling `Bearer` is observation-local. The production vocabulary is deliberately undecided.

## Probes

### 1. The same net movement can have different meaning

Two worlds have the same gross paid units, the same one-unit offset, the same final net expense, and the same final household burden.

In one world the offset is a merchant refund. In the other it is settlement of an outside-borne share.

Expected: **SAT**.

Therefore a negative expense plus payment-account inflow does not by itself reconstruct why the offset occurred. A dedicated `Reimbursement` tag would distinguish this case, but the later probes ask whether a more general allocation relation explains more.

### 2. Before settlement, identical payment state can imply different household burden

Two worlds contain the same two paid units and no offset yet.

In one world the household bears both units. In the other, the household bears one and an outside party bears one.

The ordinary net expense is two in both worlds, but household burden is two versus one and outside outstanding is zero versus one.

Expected: **SAT**.

This is the central pressure. Physical payment alone cannot answer an agreed cost-share question before settlement.

### 3. Settlement changes outstanding without changing burden allocation

Two worlds agree on the original payment and on who bears each unit. One world has not yet received the outside share; the other has received it.

Household burden remains one in both worlds. Outside outstanding falls from one to zero, while net expense falls from two to one.

Expected: **SAT**.

So allocation and settlement are independently observable. Receiving money does not retroactively decide who was supposed to bear the cost.

### 4. Counterparty identity has conditional pressure

Two worlds have the same paid units, the same total outside-borne set, and the same aggregate outside outstanding. Only assignment among two outside bearers differs.

The aggregate outstanding remains three, but one named bearer's outstanding differs two versus one.

Expected: **SAT**.

Stable counterparty identity is therefore observable for per-person questions. It is not automatically earned merely to compute the household's aggregate outside share.

### 5. Net expense decomposes into household burden plus outside outstanding

For every well-formed bounded world:

```text
net expense = household burden + outside outstanding
```

Expected check: **UNSAT counterexample**.

This explains why the current negative-expense representation looks completely right after full settlement but temporarily mixes two meanings before settlement.

### 6. Settlement cannot change household burden when allocation and refunds agree

If two worlds agree on paid units, burden allocation, and merchant refunds, changing only shared settlement evidence cannot change household burden.

Expected check: **UNSAT counterexample**.

### 7. Aggregate outside outstanding does not require outside identity

If two worlds agree on which units are externally borne and which units are settled, merely redistributing those units among outside identities cannot change aggregate outside outstanding.

Expected check: **UNSAT counterexample**.

This is the stop condition against eagerly adding a household-wide Party registry.

## Candidate finding

If the expected matrix holds, the recurring household case does not primarily earn a special `Reimbursement` entity.

The stronger general shape is:

```text
physical payment evidence
+ burden allocation evidence
+ settlement evidence
-> derived household burden / outside outstanding / net expense
```

`Reimbursement`, `split cost`, `advance`, or `expense sharing` can then be presentations or policy interpretations of this smaller structure where appropriate.

This shape is plausibly reusable for:

- shared transport;
- shared meals or group purchases;
- family or household cost sharing;
- purchases initially paid by one person but economically borne by another;
- employer or organization reimbursement where policy assigns part of a cost outside the household.

A merchant refund remains different: it reduces a household-borne cost rather than settling another bearer's allocated share.

## What this does not earn

This observation does **not** yet earn:

- a production type named `Reimbursement`;
- a production type named `Receivable`;
- a stored outstanding amount;
- a retained `Cost` entity;
- a global `Party` / `Person` registry;
- automatic mutation of historical negative-expense events;
- a rule that every refund-like inflow must have allocation evidence;
- double-entry vocabulary in the neutral Event core.

Outstanding should remain a projection if allocation and settlement evidence are eventually retained.

The exact production anchor also remains open. A future representation might relate allocation to existing Event identity, to a more local purpose/effect identity, or to another structure earned by later observations. This Alloy `Cost` atom is only a bounded grouping device.

## Historical consequence

The repeated canonical `payment account + / transport expense -` events may remain valid movement evidence. Observation 161 does not authorize rewriting them.

Historical burden allocation should be backfilled only where source evidence establishes the shared-cost agreement strongly enough. A correct final net number is not, by itself, proof of who bore the original cost.

## Stop condition

Do not add `Reimbursement` merely because bookkeeping software commonly names such transactions.

Retain burden-allocation evidence only when a real household question cannot be reconstructed from movement evidence alone, such as pre-settlement own burden or outstanding external share.

Retain stable outside-bearer identity only when per-counterparty distinctions matter. If the household needs only aggregate external burden, an anonymous outside boundary is sufficient.
