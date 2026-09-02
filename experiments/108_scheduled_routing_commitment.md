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

## Executed result

Alloy 6.2.0 / Sat4j executed the exact PR #241 model on head `261853ea39780a19fc9bdf30dc7d79b81be7ea3e`.

The witnesses were:

```text
representativeCommitmentView                         SAT
lifecycleDifferenceChangesCommitment                 SAT
routingDifferenceChangesCommitment                   SAT
lateTerminalDoesNotRewriteEarlierCommitment          SAT
overdueOpenStillCommits                              SAT
endExclusiveHorizonExcludesScheduledClaim            SAT
```

The determinacy and partition checks were:

```text
ScheduledLifecycleWithoutRoutingDeterminesCommitment SAT counterexample
ScheduledRoutingWithoutLifecycleDeterminesCommitment SAT counterexample
ScheduledLifecycleAndRoutingDetermineCommitment      UNSAT counterexample
CommitmentPartitionsOpenHorizonClaims                UNSAT counterexample
PeriodEndExclusiveNeverCommits                       UNSAT counterexample
```

The GitHub Actions qualification required both Alloy execution and the explicit expected-result checker to succeed. Both steps completed successfully.

## Finding

The two deliberately smaller summaries both lose information:

```text
Scheduled + lifecycle without routing
    too small

Scheduled + routing without lifecycle
    too small
```

Within this bounded household vocabulary, the selected Commitment view is determined by:

```text
Scheduled quantity-bearing claims
+ terminal/lifecycle history
+ historical routing
+ query day / period horizon
```

No separately retained `Commitment` fact was required to distinguish the admitted managed, explicitly unmanaged, and unrouted answers.

The result does not say that commitment-bearing intention disappeared. Observation 013 remains intact: physical Actual history alone cannot determine intention. Here the already-independent Scheduled expectation is the concrete intentional evidence from which the selected commitment projection is read.

The bounded result also preserves practical temporal distinctions:

- overdue-but-open Scheduled claims still contribute;
- terminal evidence learned later does not rewrite an earlier observation;
- a claim due exactly at the period end-exclusive boundary does not contribute;
- managed, explicitly unmanaged, and unrouted outcomes partition the open in-horizon claims.

A compact reading is therefore:

```text
physical Actual history determines Commitment
    no

Scheduled intent can carry the independent intention
    yes

lifecycle or routing may be erased
    no

additional canonical Commitment fact
    not required by the selected bounded practical view
```

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

## Next pressure

The next whole-household seam is Attention / Issue:

> Can Issue realization, closure, and continuation reuse the same small lifecycle relation shape as Scheduled without collapsing Attention into Scheduled financial intent?

That is the last large semantic plane to inspect before choosing a compact practical vocabulary.
