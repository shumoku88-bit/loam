# G2-021 — Locus-admission writer closure obligation DAG

Status: **Generation-2 audit evidence — KEEP QUALIFIED**

Primary instruments: **DRAKONview + production-publisher inventory + source reachability + prior qualification evidence**.

## Question

G2-020 found that `CurrentQuantityAnchor` had been added after Observation 212 and initially bypassed the explicit current `LocusAdmissionVocabulary`.

That raises a broader closure question:

> After the G2-020 repair, does any reachable production entrance still create new Locus-bound quantity evidence without consuming the current new-write admission policy?

This audit treats the set of writers at one semantic scale rather than inspecting only one publisher.

## Qualified policy boundary

Observation 212 established the distinction:

```text
historically referenced Loci
!=
Loci approved for new quantity publication
```

Current admission is therefore a **write policy**, not a read filter. Historical Actual, Scheduled, and current-anchor evidence may remain readable even if a Locus is no longer eligible for new publication.

The selected closure property is narrower:

```text
new production write introduces Locus-bound quantity evidence
    -> every newly written Locus must be currently admitted
```

## Production writer inventory

### W1 — ordinary Movement recording

`MovementAdmission.admit?` canonicalizes and validates the draft, then requires:

```text
world.locusAdmission.admitsEffects draft.effects
```

The `MovementPublisher` constructs that world from normalized Actual plus the current Locus policy.

**Result: guarded.**

### W2 — Actual correction replacement

`CorrectionPublisher.admit?` receives `LocusAdmissionVocabulary` and requires:

```text
locusAdmission.admitsEffects effects
```

before constructing the replacement Event.

**Result: guarded.**

### W3 — Actual reversal

`ActualReversalPublisher` derives exact inverse Effects from the selected target, but the result is still a newly published Actual Event. It therefore also requires:

```text
locusAdmission.admitsEffects effects
```

This check is not derivable merely from historical readability because current admission is independent of retained history.

**Result: guarded.**

### W4 — Scheduled creation

`ScheduledCreationPublisher` checks every `BalancedMovement` change coordinate against:

```text
locusAdmission.allows change.coordinate
```

before appending the new Scheduled occurrence.

**Result: guarded.**

### W5 — Scheduled replacement

`ScheduledReplacementPublisher` applies the same current admission rule to every replacement movement coordinate before publishing the new Scheduled occurrence and replacement relation.

**Result: guarded.**

### W6 — Scheduled completion Actual

Completion accepts a practical Actual movement draft and publishes a new Actual Event. `ScheduledTerminalPublisher.appendCompletionActual?` requires:

```text
world.locusAdmission.admitsEffects draft.effects
```

before Event construction.

Cancellation creates no quantity Event and is outside this obligation.

**Result: guarded.**

### W7 — CurrentQuantityAnchor observation

G2-020 added the missing publication gate. `CurrentQuantityAnchorPublisher.propose?` now requires every assertion Locus to be present in the current `LocusAdmissionVocabulary`, while retained old anchor evidence remains readable independently of current policy.

**Result: guarded after #950.**

## Why other production publishers are not missing guards

The remaining publisher families do not introduce new Locus-bound quantities:

```text
ActualValidityPublisher      occurrence-date evidence only
ActualRoutingPublisher       routing evidence over retained Actual subjects
ScheduledRoutingPublisher    routing evidence over retained Scheduled subjects
AccountingRolePublisher      role assignment, no quantity write
AttentionPublisher           attention evidence, no Locus quantity
LocusAdmissionPublisher      the policy itself
Scheduled cancellation       terminal lifecycle evidence only
```

`CapacityPublisher` does publish JPY quantities, but its coordinate domain is `CapacityCoordinate` (`PurposeId` / `unallocated`), not `LocusId`. Pulling it under `LocusAdmissionVocabulary` would conflate two independently earned vocabularies.

## Write/read asymmetry is intentional

The closure law applies only at publication time:

```text
new Locus-bound quantity write
       |
       v
current admission required

retained historical evidence
       |
       v
readable without current admission
```

This is why the audit does **not** add Locus-admission filtering to:

- Actual reconstruction;
- Scheduled review;
- RoleBalance coordinate discovery;
- CurrentQuantityAnchor read-side inspection;
- historical display metadata.

Applying current admission to reads would erase the Observation-212 distinction between historical identity and present write permission.

## Why no generic quantity-writer framework is added

The seven guarded entrances do not share one useful production orchestration boundary.

Their candidate quantity shapes differ:

```text
Movement / Correction / Reversal / Completion
    List Effect

Scheduled Creation / Replacement
    BalancedMovement LocusId

CurrentQuantityAnchor
    List Assertion
```

The smallest reusable policy primitives already exist in Core:

```text
LocusAdmissionVocabulary.allows
LocusAdmissionVocabulary.admitsEffect
LocusAdmissionVocabulary.admitsEffects
```

Adding `GenericQuantityWriter`, `LocusGuardedWrite`, or a new wrapper merely to make every call site look syntactically identical would move operation-specific orchestration into an abstraction that owns no new invariant.

## Ownership note

Current production Locus-policy mutation remains add-only through `LocusAdmissionPublisher.publishAdmission`.

Writers re-read the policy during their publication interval but do not acquire a Locus-policy lock. With add-only mutation, a concurrent policy change can make a read conservatively stale only in the refusal direction:

```text
writer reads before concurrent add
    -> may refuse
    -> retry may succeed
```

There is no currently reachable production revocation that can turn an observed permission into a later invalid success.

If revocation or whole-vocabulary replacement becomes a production operation, this ownership conclusion must be reopened across all seven entrances, not only CurrentQuantityAnchor.

## Obligation DAG

```text
                       production publisher
                              |
                              v
             does it introduce Locus-bound quantity?
                    /                       \
                  NO                         YES
                  |                           |
                  v                           v
       no Locus gate required         current policy re-read
                                              |
                                              v
                                  all proposed Loci admitted?
                                       /             \
                                     NO               YES
                                     |                 |
                                     v                 v
                                  refuse        operation-local laws
                                                        |
                                                        v
                                                   publish evidence

read retained evidence
        |
        +--------------------> no current-admission filter
```

## Stop point

G2-021 does **not** add:

- a generic quantity publisher;
- a second Locus vocabulary;
- Locus admission inside retained evidence types;
- read-side admission filtering;
- a Locus-policy lock while policy mutation remains add-only;
- a common wrapper around unrelated publisher orchestration;
- Locus policy for Capacity/Purpose coordinates.

## Verdict

**G2-021: KEEP QUALIFIED — after G2-020, every reachable production entrance that introduces new Locus-bound quantity evidence consumes the current Locus-admission policy; retain operation-local admission placement and do not add a generic quantity-writer layer.**
