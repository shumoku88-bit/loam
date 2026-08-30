# Observation 050 — Can Settlement Be Asynchronous?

## Question

Observation 048 separated physical holding from allocation eligibility.
Observation 049 then separated physical location from accounting role.

A different boundary now appears when quantity moves between loci:

> Does initiating a movement mean that the physical movement has already settled?

Real household movements can be asynchronous. A card payment can be initiated before final settlement. A bank transfer can be requested before the receiving side has actually settled it. If LOAM collapses these moments into one fact, an intermediate state becomes impossible to represent without lying about either physical holdings or pending activity.

The pressure for this observation is therefore:

```text
initiated
    ≠
settled
```

and, more specifically:

```text
pending movement
    may exist
while
physical holdings remain unchanged
```

This observation does not yet model failure, cancellation, reversal, reconciliation evidence, or institution-specific payment rails.

## Why TLA+

This is not a static relational-independence question.

The interesting object is an ordering of reachable states:

```text
not initiated
    -> initiated but unsettled
    -> later settled
```

Alloy could encode snapshots of these states, but the pressure here is whether transition order itself preserves the intended meaning. TLA+ therefore answers something new:

- whether a pending state is reachable;
- whether time can pass while it remains pending;
- whether settlement can occur later;
- whether physical quantity changes only at settlement;
- whether settlement can ever precede initiation.

No J, Lean 4, or miniKanren is needed for this observation.

## Minimal model

The model contains one unit of quantity and two neutral physical coordinates:

```text
source
    destination
```

It deliberately does not introduce Account, Asset, Liability, Envelope, BackingPool, institution, ownership, or payment-method objects.

The state is only:

```text
now
initiatedAt
settledAt
sourceHeld
destinationHeld
```

with a finite time horizon of 0..2.

## Transitions

### Initiate

`Initiate` records `initiatedAt`.

It does **not** change physical holdings.

```text
before:
sourceHeld      = 1
destinationHeld = 0

initiate

pending:
sourceHeld      = 1
destinationHeld = 0
```

This is the hypothesis under pressure: initiation is semantic history, not proof that physical settlement already happened.

### Advance

After initiation, time may advance while holdings remain unchanged.

This makes the intermediate state genuinely temporal rather than merely two labels on one instant.

### Settle

`Settle` is enabled only when:

```text
initiatedAt is known
settledAt is not yet known
now > initiatedAt
```

Settlement then moves the physical quantity:

```text
sourceHeld      = 0
destinationHeld = 1
```

No other transition changes physical holdings.

## Positive safety checks

The ordinary TLC configuration checks:

### TypeOK

All times and quantities remain inside the modeled domains.

### KnownTimesAreNotFuture

Neither initiation nor settlement can be recorded in the modeled future relative to `now`.

### SettlementRequiresInitiation

A settled state cannot exist without an initiation fact.

### SettlementIsLater

Whenever settlement exists:

```text
initiatedAt < settledAt
```

So the model cannot silently collapse later settlement back onto the initiation instant.

### QuantityConserved

The physical quantity is conserved across the two loci.

### PhysicalStateFollowsSettlement

Before settlement, the unit remains at the source.
After settlement, the unit is at the destination.

### PendingLeavesPhysicalHoldingsUnchanged

The pending state itself does not mutate physical holdings.

## Reachability boundaries

TLC explores all reachable states. Three deliberately over-strong invariants are checked separately and are expected to fail.

### Boundary 1 — NoPendingState

Hypothesis:

```text
there is never an initiated-but-unsettled state
```

Expected: **invariant violation**.

A counterexample would establish that pending is a reachable state in the model.

### Boundary 2 — NoSettledState

Hypothesis:

```text
settlement is never reachable
```

Expected: **invariant violation**.

Combined with the positive `SettlementIsLater` invariant, this shows that a reachable settlement can occur strictly after initiation.

### Boundary 3 — UnmovedPhysicalStateMeansNotInitiated

Hypothesis:

```text
if physical holdings have not moved,
then initiation has not happened
```

Expected: **invariant violation**.

The pre-initiation state and the pending state have the same physical holdings but different initiation vocabulary.

If this counterexample appears, then physical holdings alone cannot answer the future question:

```text
is there a movement currently pending?
```

## Expected result

TLA+ tools 1.7.4 / TLC:

```text
positive safety model                              PASS
NoPendingState                                     VIOLATED
NoSettledState                                     VIOLATED
UnmovedPhysicalStateMeansNotInitiated              VIOLATED
```

This section remains an expectation until CI executes the exact pull-request head.

## Interpretation if the expected result holds

The bounded result would be:

```text
movement initiation
    ≠
physical settlement
```

and:

```text
same physical holdings
    can correspond to
not initiated
or
initiated but pending
```

So a physical quantity projection is insufficient for a future vocabulary that asks about pending movements.

At minimum, that vocabulary needs some retained initiation/settlement distinction such as:

```text
initiatedAt
settledAt
```

The observation would **not** imply that these exact fields are the final LOAM representation. They are only a small witness that one collapsed physical state is not sufficient.

This extends the recurring LOAM separation pattern:

```text
exists
    ≠ selected

held
    ≠ allocatable

located
    ≠ accounting role

initiated
    ≠ settled
```

The larger theme remains vocabulary-relative memory:

> If the future may ask whether a movement is still pending, the present must retain enough history to distinguish initiation from settlement.

## Important boundaries

This observation does **not** establish:

- that every initiated movement eventually settles;
- a liveness guarantee;
- timeout semantics;
- failure or rejection;
- cancellation;
- reversal;
- partial settlement;
- multiple settlement legs;
- fees;
- exchange or valuation;
- ownership transfer rules;
- accounting recognition timing;
- legal finality;
- reconciliation evidence;
- institution-specific states;
- historical correction of settlement facts.

Those are intentionally outside this model.

In particular, the model does not assert eventual settlement. TLC only establishes which states and transitions are reachable while preserving the safety laws above.

## Next question

If initiation and settlement are distinct, a practical system must eventually answer a different question:

> What evidence lets us say that the world and our recorded state agree?

That is Observation 051: reconciliation evidence.

The default tool there returns to Alloy because the first pressure is relational: recorded claims, observed evidence, and the relation that says what evidence supports which claim. TLA+ should be added only if ordering of reconciliation observations turns out to change the answer.
