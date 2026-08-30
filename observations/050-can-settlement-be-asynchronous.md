# Observation 050: Can Settlement Be Asynchronous?

## Question

Observation 048 separated physical holding from allocation eligibility.
Observation 049 separated physical location from accounting role.

The next boundary appears when quantity moves between loci:

> Does initiating a movement mean that the physical movement has already settled?

The pressure is:

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

This observation does not model failure, cancellation, reversal, reconciliation evidence, or institution-specific payment rails.

## Why TLA+

This is a transition-order question rather than static relational independence.

The state path under pressure is:

```text
not initiated
    -> initiated but unsettled
    -> later settled
```

TLA+ is useful here because the questions are about reachable intermediate states and ordering:

- can a pending state exist;
- can time pass while it remains pending;
- can settlement occur later;
- do physical holdings change only at settlement;
- can settlement ever precede initiation.

No J, Lean 4, miniKanren, or Alloy is needed for this observation.

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

with finite time horizon `0..2`.

## Transitions

### Initiate

`Initiate` records `initiatedAt` but does not change physical holdings:

```text
before:
sourceHeld      = 1
destinationHeld = 0

initiate

pending:
sourceHeld      = 1
destinationHeld = 0
```

Initiation is semantic history, not proof that physical settlement already happened.

### Advance

After initiation, time may advance while holdings remain unchanged.

This makes the intermediate state genuinely temporal rather than two labels on one instant.

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

- `TypeOK`
- `KnownTimesAreNotFuture`
- `SettlementRequiresInitiation`
- `SettlementIsLater`
- `QuantityConserved`
- `PhysicalStateFollowsSettlement`
- `PendingLeavesPhysicalHoldingsUnchanged`

In particular, whenever settlement exists:

```text
initiatedAt < settledAt
```

and while pending:

```text
sourceHeld      = 1
destinationHeld = 0
```

## Reachability boundaries

TLC explores all reachable states. Three deliberately over-strong invariants are checked separately.

### Boundary 1: NoPendingState

Hypothesis:

```text
there is never an initiated-but-unsettled state
```

Observed: **invariant violation**.

Pending is reachable.

### Boundary 2: NoSettledState

Hypothesis:

```text
settlement is never reachable
```

Observed: **invariant violation**.

Combined with `SettlementIsLater`, a reachable settlement occurs strictly after initiation.

### Boundary 3: UnmovedPhysicalStateMeansNotInitiated

Hypothesis:

```text
if physical holdings have not moved,
then initiation has not happened
```

Observed: **invariant violation**.

The pre-initiation state and the pending state have the same physical holdings but different initiation vocabulary.

Therefore physical holdings alone cannot answer:

```text
is there a movement currently pending?
```

## Observed result

TLA+ tools 1.7.4 / TLC on pull-request head `53781cc4df2012cc7c956fde1ac1f8cd03e5e077`:

```text
positive safety model                              PASS
NoPendingState                                     VIOLATED
NoSettledState                                     VIOLATED
UnmovedPhysicalStateMeansNotInitiated              VIOLATED
```

The Observation 050 workflow passed all four checks, and the same exact head passed Observation 001 through 050, 50/50 SUCCESS.

## Interpretation

The bounded result is:

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

At minimum, that vocabulary must retain an initiation/settlement distinction, represented in this witness by:

```text
initiatedAt
settledAt
```

These exact fields are not claimed as the final LOAM representation. They are only a small witness that one collapsed physical state is insufficient.

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

The model does not assert eventual settlement. TLC establishes reachable states and the safety laws above, not a liveness promise.

## CI note

An earlier PR-head batch exposed an unrelated pre-existing TLC metadata-directory collision in Observation 018 when two TLC invocations started within the same second. Observation 050 therefore gives each of its four TLC invocations a distinct `-metadir`. No Observation 018 model or workflow was changed in this observation.

## Next question

If initiation and settlement are distinct, a practical system must eventually answer:

> What evidence lets us say that the world and our recorded state agree?

That is Observation 051: reconciliation evidence.

The default tool returns to Alloy because the first pressure is relational: recorded claims, observed evidence, and the relation that says what evidence supports which claim. TLA+ should be added only if ordering of reconciliation observations changes the answer.
