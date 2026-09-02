# Observation 108: Does open Scheduled evidence already carry Envelope Commitment?

## Question

Earlier LOAM observations established an important boundary:

```text
physical history alone
    does not determine
commitment-bearing intention
```

Observation 014 then showed that active commitment can be projected from intentional history rather than stored as mutable commitment state.

The whole-household survey now exposes a concrete intentional source already needed for another capability:

```text
Scheduled occurrence
+ lifecycle evidence
+ historical Purpose routing
```

h-kernel currently defines Envelope Commitment from still-open Plan intent. Its routing is read as effective at the observation day, overdue Plans remain claims until lifecycle evidence closes them, and Plans outside the current period end-exclusive horizon do not contribute.

The new question is therefore narrower than Observation 013:

> Once Scheduled expectation, lifecycle evidence, and historical routing already survive, does the practical Envelope Commitment view require any additional canonical commitment fact?

## Model shape

The bounded model deliberately does not add a `Commitment` signature.

It retains:

```text
Scheduled
  due day

Claim
  owner Scheduled
  quantity Units

TerminalEvidence
  Scheduled
  knownOn

RoutingEvidence
  Claim
  effectiveOn
  Purpose?
```

`Claim` is an observation scaffold for quantity-bearing scheduled Effects. It allows one Scheduled occurrence to carry more than one independently routed claim without importing Account or transaction-role ontology.

The finite `Unit` atoms stand for exact quantity quanta so this observation can focus on information ownership rather than integer arithmetic.

## Open and horizon semantics

At a query day, a Scheduled occurrence is open when no terminal evidence is visible through that day.

A claim can contribute to current-period Commitment when:

```text
its Scheduled occurrence is open at the query day
and
Scheduled.due < period end-exclusive
```

There is deliberately no `due >= observedThrough` condition. An overdue occurrence remains a commitment until explicit lifecycle evidence closes it.

A terminal fact learned after the query day does not rewrite an earlier observation.

## Routing semantics

Routing uses the latest explicit route effective on or before the observation day, matching the current-intent pressure in h-kernel.

The commitment view preserves three outcomes:

```text
latest route has Purpose
    -> managed Commitment at that Purpose

latest route exists with no Purpose
    -> explicitly unmanaged Commitment

no route evidence visible
    -> unrouted Commitment
```

This matters because current household behavior distinguishes an explicit decision not to Envelope-manage a claim from a claim that has not yet been routed.

## Probes

The model asks for witnesses that exercise:

- managed, unmanaged, and unrouted open claims in one observation;
- an overdue open claim that still contributes;
- lifecycle evidence changing commitment while routing stays fixed;
- routing evidence changing commitment while lifecycle stays fixed;
- a later-known terminal fact not rewriting an earlier commitment view;
- a due date exactly at period end-exclusive being excluded.

All are expected **SAT**.

## Determinacy checks

Two deliberately-too-small candidates are tested first:

```text
Scheduled + lifecycle without routing
Scheduled + routing without lifecycle
```

Both are expected to have SAT counterexamples.

The full candidate is:

```text
Scheduled quantity-bearing claims
+ terminal/lifecycle history
+ historical routing
+ query day / period horizon
```

With those inputs equal, the model asks whether two worlds can disagree on any of:

```text
managed Commitment
explicitly unmanaged Commitment
unrouted Commitment
```

Expected: **UNSAT counterexample**.

The model also checks that the three commitment outcomes partition every open in-horizon claim and that the period end-exclusive boundary is respected.

## Expected compression boundary

If the checks hold, the useful result is not that commitment disappeared. Its intentional information is still real.

The result would instead be:

```text
physical Actual history determines Commitment
    no

Scheduled intent can carry the independent intention
    yes

lifecycle or routing may be erased
    no

additional canonical Commitment fact
    not required by the selected practical view
```

This preserves Observations 013-015. It identifies Scheduled evidence as a concrete owner of the intention that those observations proved must exist somewhere.

## Important boundaries

Observation 108 does not establish:

- a Practical Core Scheduled type;
- a Practical Core routing type;
- recurrence or Series generation;
- partial completion;
- priorities between commitments;
- oversubscription policy;
- Remaining or Headroom arithmetic;
- Backing;
- the final representation of quantity quanta;
- whether routing subjects should be Scheduled identity, an Effect-derived claim identity, or a source-specific coordinate;
- a universal commitment law outside the household Envelope question.

The `Claim` scaffold exists specifically to avoid deciding that last routing-subject question too early.

## Next pressure if this survives

If Scheduled + lifecycle + routing determines the selected Commitment view, the next whole-household seam is Attention / Issue:

> Can Issue realization, closure, and continuation reuse the same small lifecycle relation shape as Scheduled without collapsing Attention into Scheduled financial intent?

That is the last large semantic plane to inspect before choosing a compact practical vocabulary.
