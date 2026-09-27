# Observation 379 — source-backed settlement obligation versus prior promise

Status: **BOUNDED QUESTION — distinguishability probe; no production vocabulary change**

Baseline:

```text
#1447  friendly repair for earlier non-payment settlement reductions
main   807c0376ecf1be66a5ce2e6ae8409d82229168ce
```

## Trigger

Observations 359–378 earned a production settlement family whose commitment row
is always anchored to an already retained source Event / Effect:

```text
SettlementCommitment
  sourceEvent
  sourceEffect
  debtor
  creditor
  settlement Measure
  exact Quantity
```

That shape is sufficient for the settlement questions qualified so far:

- delayed card and securities settlement;
- direct and net settlement;
- partial attribution;
- correction / retraction;
- non-settlement extinguishment;
- current and historically placed outstanding quantity.

An external REA-family vocabulary such as Valueflows draws another distinction:

```text
future promise before occurrence
    versus
obligation / claim arising from an occurrence
```

This observation does **not** import that ontology.

It asks the smaller LOAM question:

> Can two worlds have exactly the same current source-backed settlement evidence
> and outstanding quantity while differing on whether the obligation was already
> promised before the source Event occurred?

If yes, prior promise is independently observable information. That still does
not mean LOAM should retain it.

## Why Alloy

This is a bounded distinguishability question.

No production transition, retry behavior, arithmetic theorem, or implementation
change is under test. Alloy is the smallest current instrument that can answer:

```text
same retained settlement image
+
different prior-promise answer
possible?
```

## Neutral observation vocabulary

The model deliberately avoids naming either world `Commitment` or `Claim`.

```text
SourceBackedObligation
  source Event
  debtor
  creditor
  Measure
  Quantity

PriorPromise
  target SourceBackedObligation
  promisedAt
```

A retained `PriorPromise` must precede the source Event.

The selected current settlement answer is:

```text
currentOutstanding
  = obligation quantity - admitted settled quantity
```

Prior-promise evidence does not participate in that arithmetic.

## Selected worlds

### World A — prior promise existed

```text
t0  promise to owe/pay 10
t1  source Event occurs
    source-backed settlement obligation = 10

current settled     = 0
current outstanding = 10
```

### World B — obligation arises without retained prior promise

```text
t0  no retained prior promise
t1  same source Event occurs
    same source-backed settlement obligation = 10

current settled     = 0
current outstanding = 10
```

The worlds intentionally share:

```text
Event evidence
SourceBackedObligation evidence
debtor / creditor
Measure
Quantity
settled quantity
current outstanding
```

They differ only in the answer to:

```text
Was this obligation already promised before the source Event?
```

## Expected Alloy results

### sameSettlementImageDifferentPriorPromiseWitness

Expected: **SAT**.

This is the central witness. The current settlement image can remain identical
while the prior-promise answer differs.

### eventTriggeredObligationWithoutPriorPromiseWitness

Expected: **SAT**.

A source-backed settlement obligation does not logically require retained
pre-source promise evidence.

### SettlementImageDeterminesPriorPromise

Deliberately too strong.

Expected: **SAT counterexample**.

The current settlement image forgets prior-promise history.

### PriorPromiseDoesNotAffectCurrentOutstanding

Expected: **UNSAT counterexample**.

When the already-admitted settlement evidence is held fixed, adding or removing
prior-promise evidence does not alter the current outstanding arithmetic.

### EverySourceBackedObligationHasPriorPromise

Deliberately too strong.

Expected: **SAT counterexample**.

The current source-backed family must remain capable of representing obligations
for which no prior promise is retained.

### RetainedPriorPromisePrecedesSourceEvent

Positive sanity law.

Expected: **UNSAT counterexample**.

## Interpretation if the matrix qualifies

The narrow result would be:

```text
SettlementCommitment evidence
    does not determine
pre-source promise history
```

and simultaneously:

```text
pre-source promise history
    is not required
for the already-qualified current outstanding answer
```

That means a Valueflows-like Commitment / Claim distinction is **observable in
principle**, but it has **not yet earned production storage in LOAM**.

The current production name `SettlementCommitment` should therefore not be
renamed merely from ontology analogy. A rename to `Claim`, or a new
`PriorCommitment` family, would require a concrete household query that needs
the distinction.

## Existing LOAM neighbor

LOAM already retains a separate future-intent surface:

```text
Scheduled occurrence
+ lifecycle
+ routing
    -> projected household Commitment
```

Observation 108 showed that this practical future Commitment can remain a
projection rather than separately retained commitment state.

That does not prove Scheduled is the representation of contractual prior
promise. It only means LOAM already has an intentional future-evidence plane, so
a new canonical prior-promise primitive must demonstrate information not
recoverable from the existing Scheduled/lifecycle/routing evidence.

## Production gate

Do **not** change `Loam/Core/Settlement.lean` from this observation alone.

A production follow-up is earned only by a concrete household question such as:

- an obligation exists before the source Event and must be queryable then;
- cancellation before occurrence has meaning different from Scheduled
  retirement;
- a contract creates a durable debt independent of any one later Event;
- one prior promise is fulfilled by several later source Events, or vice versa;
- historical reports must distinguish promised-before-occurrence from
  event-triggered obligation.

Until such pressure exists, the smaller production system remains:

```text
future expectation      -> Scheduled evidence / projection
occurred fact            -> Actual Event
source-backed obligation -> SettlementCommitment
later reduction          -> settlement or extinguishment evidence
```

## Stop condition

If the expected matrix qualifies:

1. record that prior promise is information erased by the current settlement
   image;
2. keep `SettlementCommitment` unchanged;
3. do not introduce Valueflows `Claim` or `Commitment` as Core nouns;
4. wait for a real household query that requires the distinction;
5. if such pressure appears, compare it first against existing Scheduled intent
   before adding new canonical evidence.
