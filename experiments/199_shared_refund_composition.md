# Observation 199 — Does a full refund of a shared expense require new second-order evidence?

Status: **F076 active falsification observation**

## Question

F076 asks about a shared expense that is later fully refunded by the merchant.

The first intuition is that refunding a shared expense may require a new second-order concept that says how the returned value should flow back through the original burden split.

But LOAM has already earned three independent evidence boundaries:

```text
Observation 065
  reverse movement != refund source provenance

Observation 163
  physical payment != economic burden allocation

Observation 165
  burden/open relation != later discharge state
```

So the sharper question is:

> Once refund source provenance, burden allocation, and prior discharge evidence are all fixed, is any additional independent information still required to answer the selected full-refund consequence?

This is intentionally a composition test, not a search for a new noun.

## Selected scenario

A two-unit group expense contains:

```text
one household-borne unit
one outside-borne unit
```

The merchant later fully refunds the source cost.

Two cases matter for the outside-borne unit.

### Outside share already settled

The other participant already paid their share before the merchant refund.

Then the later refund does not merely erase an open receivable. The household has already received that participant's share, so the returned merchant value corresponding to that unit is now owed outward.

### Outside share still unsettled

The other participant had not yet paid their share.

Then the merchant refund extinguishes the still-open outside amount rather than creating a reverse payment obligation.

The distinction is therefore not merely:

```text
refund happened
```

but the composition of:

```text
which source was refunded
who bore each source unit
which outside units had already been discharged
```

## Observation-local vocabulary

```text
Cost
Unit
Participant
Refund

bearer
settledOutside
refundOf
```

Selected derived views are:

```text
householdRefundShare
reverseObligationUnits
extinguishedReceivableUnits
refundOwedTo participant
```

These names are experiment-local. They do not propose production `Cost`, `Participant`, `Refund`, or reverse-obligation objects.

## Probes

### 1. Representative settled shared refund

Can a full refund of a two-unit shared cost leave one unit as the household's own refund share while the already-settled outside unit becomes value owed back to the outside participant?

Expected: **SAT**.

### 2. Same physical refund amount and burden graph, different source provenance

Two equal-size shared costs exist. One is shared with OutsideA and the other with OutsideB. The same physical full-refund amount can refer to either source.

If only `refundOf` changes, the outside beneficiary changes.

Expected: **SAT**.

This should recover Observation 065's provenance pressure inside a shared-burden graph rather than earn a new kind of source relation.

### 3. Same source and burden, different prior discharge

Hold the refund source and burden allocation fixed. Let the outside unit be already settled in one world but still open in the other.

The same merchant refund then has different consequences:

```text
already settled
  -> reverse obligation outward

not yet settled
  -> extinguish open receivable
```

Expected: **SAT**.

This should recover Observation 165's discharge distinction rather than earn a new settlement primitive.

## Deliberately too-small checks

### Burden + discharge without refund provenance

If burden allocation and discharge state are the same, do they determine refund consequences without saying which source was refunded?

Expected: **SAT counterexample**.

### Refund source + burden without discharge

If source provenance and burden allocation are fixed, do they determine whether the outside share is extinguished or reverses direction without prior discharge evidence?

Expected: **SAT counterexample**.

## Composition sufficiency check

### Existing evidence determines selected refund consequences

Fix all three already-earned evidence families:

```text
burden allocation
refund source provenance
prior outside discharge state
```

Then ask whether the selected refund consequences can still differ.

Expected counterexample: **UNSAT**.

If this holds, F076 does not expose a fourth independent evidence family at this bounded frontier. It is absorbed by composition of distinctions LOAM already earned separately.

## Candidate interpretation if the matrix holds

The result would be:

```text
physical refund alone
    is too small

burden allocation + refund provenance
    is still too small if prior settlement is unknown

but

burden allocation
+ refund source provenance
+ prior discharge evidence
    -> selected full-refund consequence
```

That would close F076 as:

```text
Work     DONE
Finding  ABSORBED
Runtime  RESEARCH_ONLY
```

This would be an important kind of success for the falsification program: not every adversarial specimen should force the vocabulary to grow.

## Boundaries

Observation 199 does **not** establish:

- partial merchant refunds;
- several refunds against one source;
- one refund spanning several sources;
- disputes or chargebacks;
- refund lifecycle or failed refunds;
- automatic creation of a reverse production relation;
- legal entitlement rules among participants;
- tax or recognition treatment;
- production participant identity;
- persistence, CLI, TUI, or household-data changes.

F077, which asks about explicit redistribution to participants, may still contain additional pressure if a query requires information beyond the selected composition here.

Runtime remains `RESEARCH_ONLY` regardless of the result.
