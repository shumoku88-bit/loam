# Observation 153: What is the minimum routing subject for Scheduled Commitment?

Status: bounded Alloy pressure before Practical Slice B

## Why this observation exists

Observation 108 already established that Envelope-style Commitment does not need a retained Commitment fact. The selected answer is a projection of:

```text
open Scheduled quantity claims
+ historical Purpose routing
+ query horizon
```

Observation 113 then showed that Capacity, Actual, and open Scheduled evidence can compose into Remaining and Headroom without retained reservation state.

One implementation choice was deliberately left open by Observation 108:

> What should historical Scheduled routing attach to?

The practical Scheduled shape now exists:

```text
ScheduledOccurrence
  ScheduledId
  scheduled coordinate
  BalancedMovement LocusId
```

A single Scheduled occurrence may contain several quantity-bearing Locus coordinates. `BalancedMovement.quantityAt` already aggregates repeated changes at the same coordinate.

The next question is therefore a pruning question, not a request for another household object graph:

> Is `ScheduledId` enough, is bare `LocusId` enough, does the pair `ScheduledId × LocusId` preserve the needed distinction, or does Commitment already require a fresh canonical Claim identity?

## Bounded candidate vocabulary

The model calls the aggregated `Scheduled × Locus` coordinate a `CoordinateClaim`. This is an observation scaffold, not proposed canonical identity.

It compares four routing subjects:

```text
Scheduled
Locus
Scheduled × Locus
fresh ClaimId -> Scheduled × Locus
```

The fresh `ClaimId` candidate is constrained to a bijection with the coordinate claim. Under that assumption it carries no information beyond the pair; the model asks whether adding the new name changes the selected Commitment answer.

This observation isolates subject granularity. Observation 108 remains the authority for lifecycle visibility, historical route selection, managed/unmanaged/unrouted partitioning, overdue-open behavior, and period end-exclusive horizon semantics.

## Pressure 1: Scheduled-only routing

A split Scheduled movement can contain two distinct Locus claims whose intended Purposes differ.

If routing attaches only to `ScheduledId`, every quantity claim in that occurrence receives the same route. The model asks for a witness where two claims of one Scheduled occurrence route to different Purposes under the finer coordinate view.

Expected:

```text
splitWithinScheduledWitness
    SAT

ScheduledOnlyCannotMatchSplitCoordinateView
    UNSAT counterexample
```

The witness ensures the law is not vacuous.

## Pressure 2: bare-Locus routing

Reusing the Actual-side Locus subject for Scheduled routing would be attractive mechanically, but it may erase intentional identity.

Two different Scheduled occurrences can carry the same Locus while their commitment intent differs. This mirrors HRA reality pressure: expense routing can be Account-based while non-expense fulfillment routing uses stable Plan identity rather than treating the destination coordinate as sufficient intent.

Expected:

```text
crossScheduledSameLocusWitness
    SAT

LocusOnlyCannotMatchCrossScheduledCoordinateView
    UNSAT counterexample
```

So sharing `RoutingHistory` mechanics does not imply sharing the routing subject.

## Pressure 3: fresh Claim identity

A fresh Claim identity may eventually be necessary if the household needs two independently routable claims that have the same Scheduled and Locus coordinates.

That distinction is not currently retained by the selected practical query. The existing `BalancedMovement.quantityAt` aggregates duplicate changes at one coordinate, so this model first tests the smaller candidate where a fresh ClaimId is merely a one-to-one label for `Scheduled × Locus`.

Expected:

```text
claimIdentityMirrorWitness
    SAT

MirroredClaimIdentityAddsNoCommitmentAnswer
    UNSAT counterexample
```

If the check holds, an independently stored Claim identity is not earned for this bounded Commitment question merely to name a coordinate that is already unique.

## Intended interpretation

If the expected result set is qualified, the surviving candidate is:

```text
shared historical-routing mechanics
    yes

Scheduled-only subject
    too coarse for split purpose intent

bare Locus subject
    too coarse across distinct Scheduled intent

Scheduled × Locus subject
    sufficient for the selected bounded view

fresh Claim identity
    not yet earned when it is only a bijective wrapper
```

A Practical Slice B could then attempt a typed or tuple-like routing subject equivalent to:

```text
ScheduledId × LocusId
```

without adding a new canonical Claim registry or mutable Commitment state.

## Stop condition

This observation does **not** claim that Claim identity can never be needed.

It should be reopened if an ordinary operation must independently address two claims that agree on both:

```text
ScheduledId
LocusId
```

but require different retained routing, lifecycle, correction, provenance, or realization answers.

At that point the bijection assumption in this observation would be too small, and a stable sub-occurrence identity could become independently observable.

## Boundaries

This observation does not establish:

- production Scheduled routing persistence;
- a routing writer or editor;
- the final textual encoding of a routing subject;
- a Claim object or Claim registry;
- explicit unmanaged/unrouted mechanics beyond Observation 108;
- lifecycle semantics beyond the already-qualified Scheduled boundary;
- recurrence or Series;
- partial completion;
- Backing;
- multi-Measure Scheduled Commitment;
- current-cycle selection or Daily pacing policy;
- that private HRA routing data can be migrated without a separate admission step.

The goal is only to remove one representation fork before Practical Slice B is implemented.
