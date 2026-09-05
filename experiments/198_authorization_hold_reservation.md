# Observation 198 — Does an authorization hold require reservation evidence beyond pending movement?

Status: **F001 active falsification observation**

## Question

F001 asks about a familiar payment state:

```text
payment authorized
funds temporarily held
but
no capture / settlement yet
```

Current external payment documentation still exhibits this shape. Stripe documents manual capture as authorizing a payment and placing a hold on funds for later capture; if authorization expires before capture, the funds are released rather than captured.

Current source check, 2026-09-06:

- https://docs.stripe.com/payments/place-a-hold-on-a-payment-method

The LOAM question is deliberately smaller than card-network state machines:

> If physical held quantity and Observation-050-style initiated/unsettled evidence are held fixed, can two worlds still differ in temporarily reserved quantity and therefore in currently available quantity?

## Relation to Observation 050

Observation 050 already qualified:

```text
movement initiation
    !=
physical settlement
```

and showed that a pending movement may exist while physical holdings remain unchanged.

But Observation 050 stores only initiation/settlement timing plus physical holdings. Its documented boundary explicitly leaves failure, cancellation, reversal, partial settlement and institution-specific rails outside scope. It does not carry a quantitative reservation against still-held resources.

Observation 198 therefore holds **both physical quantity and initiated/settled lifecycle evidence equal** in its central two-world witness. If only pending-vs-settled changed, this would merely repeat Observation 050.

## Candidate compression under attack

A too-small candidate says:

```text
physical held quantity
+ initiated / settled movement state
    ->
currently available quantity
```

F001 asks whether temporary reservation can make that implication false.

## Why Alloy

The selected question is static information independence at one bounded snapshot:

1. hold physical held quantity equal;
2. hold initiated and settled identities equal;
3. vary only temporary reservation quantity;
4. ask whether currently available quantity differs.

The release/capture transition is a later temporal question. TLA+ would be appropriate for F002/F005/F006-style lifecycle mechanics, but is unnecessary to establish the first information gap.

## Observation-local vocabulary

```text
Authorization
World
held
initiated
settled
reserved
```

For the selected view:

```text
available = held - totalReserved
```

`reserved` is experiment-local evidence only. It is not a production proposal for `CardAuthorization`, `Hold`, `PendingBalance`, a mutable account balance, or a generic payment-state framework.

## Selected probes

### Representative held authorization

Can one authorization be initiated but unsettled while 30 of 100 held units are reserved, leaving 70 currently available?

Expected: **SAT**.

### Same physical and lifecycle evidence, different reservation

Can Left and Right have the same held quantity, the same initiated set, and the same settled set while reservation differs and therefore availability differs?

Expected: **SAT**.

This is the central F001 witness.

## Deliberately too-strong check

### Physical and lifecycle evidence determine availability

```text
same held quantity
+ same initiated set
+ same settled set
    ->
same available quantity
```

Expected: **SAT counterexample**.

If so, Observation-050-style pending evidence is still too small for an availability query that sees authorization holds.

## Positive sufficiency checks

### Explicit reservation determines selected availability

If held quantity and reservation evidence are equal, selected availability must be equal.

Expected counterexample: **UNSAT**.

### Settled authorization has no reservation

Inside this bounded snapshot, settled authorization cannot simultaneously retain a temporary hold.

Expected counterexample: **UNSAT**.

This is only a local well-formedness condition. It does not model release or capture transitions.

## Candidate interpretation if the matrix holds

The bounded result would be:

```text
pending movement evidence
    !=
temporary reservation evidence
```

and more specifically:

```text
physical quantity + initiated/settled state
    -/->
currently available quantity
```

That would earn independently observable reservation information for the selected availability query, not a production representation.

Possible later information-equivalent representations could include reservation facts, provider observations, policy-derived encumbrance, or a smaller relation not yet considered.

## Deliberate boundaries

Observation 198 does **not** establish:

- a production card/payment object;
- a mutable available-balance field;
- authorization expiry or release (F002);
- incremental authorization (F003);
- partial authorization (F004);
- multicapture (F005);
- partial capture + release (F006);
- overcapture (F007);
- pending-entry identity replacement (F008);
- whether reservation affects household Capacity, Backing, Remaining, or Commitment;
- how institution-reported available balance reconciles with reconstructed history;
- persistence, CLI, TUI, or household-data changes.

If the result is a counterexample, runtime remains `RESEARCH_ONLY`. Production implementation still waits for real dogfood pressure.

## Falsification status

Until the exact model executes successfully, F001 remains:

```text
Work     = OBSERVING
Finding  = UNTESTED
Runtime  = RESEARCH_ONLY
```
