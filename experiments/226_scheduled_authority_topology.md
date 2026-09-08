# Observation 226 — Can Scheduled retire optional sidecars without merging meanings?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J at exact head `5eb02bfcfdcf01f17d50018ce99b0c16bb68596e`; candidate D selected for production cutover**

## Pressure

Production Scheduled currently retains several distinct fact families:

```text
ScheduledOccurrence
ScheduledCompletion
ScheduledRetirement
ScheduledReplacement
ScheduledRouting
```

The first four are read together to determine the current lifecycle view. Routing is a separate historical relation over `ScheduledId × LocusId` and Purpose.

The current physical topology nevertheless gives several lifecycle families optional suffix-sidecar storage:

```text
scheduled.loam
scheduled.loam.completions
scheduled.loam.retirements
scheduled.loam.replacements
```

and practical Scheduled routing similarly treats a missing routing file as an empty history at its CLI admission boundary.

This creates a stronger question than file naming aesthetics:

> Can LOAM distinguish an explicitly empty retained fact family from a fact family whose storage has disappeared?

For the current optional sidecars, the answer is no. A missing completion / retirement / replacement file is admitted as the corresponding empty memory. If retained evidence had existed and the sidecar disappeared, the reader-visible world can collapse onto the same representation as a genuinely empty history.

LOAM already has a project direction of avoiding permanent sidecars by default, but Observations 149, 155, and 157 also showed that fewer files do not automatically imply a smaller authority design. In particular:

- one complete image can give one atomic authority transition;
- one authority per family preserves strict rewrite locality;
- those properties can compete;
- physical grouping must not merge distinct semantic families merely to reduce file count.

Observation 226 therefore asks for the smallest Scheduled-specific authority topology that removes missing-as-empty ambiguity while preserving the already-earned semantic distinctions.

## Destructive-cut assumption

The current household does not depend on long-lived mixed-version compatibility for Scheduled persistence. A production cut may therefore be destructive after explicit canonical migration.

This observation does **not** use that freedom to weaken fail-closed behavior. It uses it only to avoid compatibility shims, dual readers, fallback discovery, or indefinite legacy sidecar support if a smaller authority topology survives.

## Compared topologies

The bounded model separates two physical coordinates:

```text
commit boundary
    which fact families become authoritative together

rewrite boundary
    which fact families' bytes must be rewritten when one family changes
```

That distinction is necessary to represent a content-addressed manifest honestly: a new manifest may atomically select a complete generation while reusing unchanged family objects.

### A. Current optional sidecars

```text
Occurrence      own commit / rewrite unit
Completion      own commit / rewrite unit, missing => empty
Retirement      own commit / rewrite unit, missing => empty
Replacement     own commit / rewrite unit, missing => empty
Routing         own commit / rewrite unit, missing => empty at practical admission
```

Advantages:

- strict single-family rewrite locality;
- Routing changes do not couple lifecycle writes.

Costs:

- no one lifecycle commit boundary;
- missing Completion / Retirement / Replacement can be interpreted as empty evidence;
- relation-first replacement recovery is required because source-closing relation and replacement occurrence publish through different files.

### B. One Scheduled monolith

```text
scheduled.loam
    Occurrence
    Completion
    Retirement
    Replacement
    Routing
```

All five families share one commit and rewrite unit.

Advantages:

- explicit complete image;
- missing storage can fail closed;
- one complete lifecycle transition can be staged and atomically exposed.

Cost:

- Routing-only changes unnecessarily join the lifecycle commit and rewrite domain.

### C. One manifest-selected Scheduled generation

```text
CURRENT
  -> Occurrence object
  -> Completion object
  -> Retirement object
  -> Replacement object
  -> Routing object
```

All five families share one authority selection boundary, but each family can retain its own immutable rewrite object.

Advantages:

- explicit complete selected generation;
- missing referenced objects can fail closed;
- Routing-only changes may reuse all unchanged family objects.

Cost:

- Routing is still coupled to the whole Scheduled authority transition even though no current requirement needs Routing and lifecycle to become authoritative atomically;
- content addressing, digest verification, object preparation, generation selection, and CURRENT publication machinery would be added to Scheduled merely to recover properties that may be obtainable with a smaller partition.

The bounded model deliberately represents this as shared commit boundary plus separate rewrite units.

### D. Complete lifecycle image + independent Routing authority

```text
scheduled.loam
    Occurrence
    Completion
    Retirement
    Replacement

scheduled-routing.loam
    Routing
```

The four lifecycle families share one commit/rewrite image. Routing remains a separate explicit authority.

After cutover, both authorities are explicit: an empty relation family is represented by a valid empty image, while missing configured authority is an error rather than an implicit empty history.

Advantages:

- missing versus explicit empty remains distinguishable;
- the lifecycle can move old-complete -> new-complete through one authority replacement;
- Replacement no longer requires a reader-visible incomplete lifecycle publication phase;
- Routing-only changes preserve an independent commit boundary and rewrite locality;
- semantic fact types remain distinct;
- no general manifest framework is required.

Cost:

- lifecycle families intentionally give up strict per-family rewrite locality.

At current household scale this is not a byte-cost argument. The candidate is justified only if one complete lifecycle commit boundary is the smaller operational law.

## Bounded model

`226_scheduled_authority_topology.als` names exactly five Scheduled fact families and four candidate topologies.

The selected properties are:

```text
explicitMissingDistinction
lifecycleAtomic
routingCommitIndependent
routingRewriteLocal
```

They mean:

1. no retained family silently treats missing storage as explicit empty;
2. Occurrence / Completion / Retirement / Replacement share one lifecycle authority transition;
3. Routing does not have to join that lifecycle authority transition;
4. a Routing-only mutation does not require rewriting lifecycle bytes.

The model also contains an explicit storage witness:

```text
with completion
    Completion file present
    Completion evidence present

without completion storage
    Completion file absent
    no visible Completion evidence

explicit empty world
    Completion file present
    no Completion evidence
```

Under the current sidecar policy, both `without completion storage` and `explicit empty world` are readable and decode to the same visible evidence set.

That witness does not claim accidental deletion is the only corruption mode. It demonstrates the narrower information-loss property needed here: missing storage and explicit empty are not distinguished by the current admission law.

## Observed Alloy receipt

Exact head:

```text
5eb02bfcfdcf01f17d50018ce99b0c16bb68596e
```

Workflow: `Observation 226`, run 4, Alloy 6.2.0 / SAT4J.

The machine receipt produced exactly:

```text
completionDeletionBecomesEmptyWorld             SAT
lifecycleSplitWitness                            SAT

SidecarsDistinguishMissingFromEmpty              SAT counterexample
SidecarsRefuseDeletedCompletion                  SAT counterexample
SidecarsHaveLifecycleAtomicity                   SAT counterexample
MonolithKeepsRoutingCommitIndependent            SAT counterexample
MonolithKeepsRoutingRewriteLocal                  SAT counterexample
ManifestKeepsRoutingCommitIndependent            SAT counterexample
ManifestKeepsRoutingRewriteLocal                  UNSAT counterexample
LifecycleSplitRefusesDeletedCompletion            UNSAT counterexample
LifecycleSplitMeetsSelectedProperties             UNSAT counterexample
OnlyLifecycleSplitMeetsSelectedProperties         UNSAT counterexample
```

For Alloy `check`, `UNSAT counterexample` means no counterexample was found in the bounded scope.

The important discrimination is not merely that candidate D has a witness. The bounded comparison rejects the stronger alternatives for different reasons:

- current sidecars cannot distinguish missing retained storage from explicit empty and do not provide one lifecycle commit boundary;
- the monolith couples Routing to both lifecycle commit and rewrite scope;
- the manifest-all shape preserves Routing rewrite locality but still couples Routing to the whole Scheduled authority transition;
- lifecycle split is the only modeled candidate satisfying all four selected properties simultaneously.

## Existing temporal evidence reused

Observation 226 does not duplicate Observation 155's TLA+ work.

Observation 155 already qualified the temporal publication property:

```text
complete sibling image
+ one same-filesystem authority replace
=> readers observe old complete or new complete, not partial content
```

Candidate D can reuse that already-qualified publication pattern for the lifecycle image rather than introducing a second TLA+ model merely to prove the same filesystem transition again.

## Completion remains cross-authority

A complete Scheduled lifecycle image does **not** make Scheduled completion and Movement Actual one authority.

The already-qualified rule remains:

```text
publish ScheduledCompletion relation
then publish Movement Actual endpoint
```

A completion whose Actual endpoint is not yet present remains inert to current Scheduled readers and can be retried. The lifecycle-image candidate changes only how Scheduled-side lifecycle evidence is physically committed.

No household-wide transaction is introduced.

## Replacement becomes simpler

Replacement is different because both pieces are Scheduled-side lifecycle evidence:

```text
source -> replacement relation
replacement Scheduled occurrence
```

Current separate streams require relation-first publication and recovery if the replacement occurrence write is interrupted.

Under a complete lifecycle image, both can be constructed in the new image before authority changes:

```text
old complete lifecycle
-> construct new complete lifecycle off-authority
-> atomic authority replace
-> new complete lifecycle
```

Production replacement should therefore be simplified rather than faithfully preserving a multi-file intermediate state that the selected authority topology removes.

## Routing boundary

ScheduledRouting remains independent semantic evidence:

```text
ScheduledId × LocusId
+ effective date
+ Purpose?
```

It is not Commitment, Remaining, Headroom, Envelope identity, or lifecycle state.

No current observation requires Routing changes to become authoritative atomically with lifecycle changes. Therefore joining Routing to the lifecycle commit boundary would be stronger coupling than current evidence earns.

## Qualified decision

The smallest supported production direction is:

```text
RETIRE
  optional suffix lifecycle sidecars
  missing-as-empty production fallback after cutover

GROUP PHYSICALLY
  ScheduledOccurrence
  ScheduledCompletion
  ScheduledRetirement
  ScheduledReplacement
  into one complete Scheduled lifecycle image

KEEP SEMANTICALLY DISTINCT
  all four lifecycle fact types

KEEP INDEPENDENT
  ScheduledRouting authority

KEEP CROSS-AUTHORITY RULE
  ScheduledCompletion relation -> Movement Actual endpoint

DO NOT ADD
  generic household authority
  generic manifest framework
  new Core lifecycle concept
  Commitment / Remaining / Headroom persistence
  compatibility fallback after destructive cutover
```

## Canonical cutover pressure

At qualification time, the current household canonical tree contains `scheduled.loam` but no completion, retirement, or replacement suffix sidecars and no Scheduled-routing authority. Therefore the household cut does not need to preserve retained lifecycle relation rows from legacy sidecars.

The destructive migration can convert the existing occurrence stream into the new complete lifecycle image with explicit empty Completion / Retirement / Replacement facets and create an explicit empty `scheduled-routing.loam` authority.

## Production gate

The structural gate is now satisfied. Production cutover still requires:

1. a concrete lifecycle codec that round-trips every existing lifecycle fact type;
2. replacement and completion interruption tests rewritten against the new authority boundary;
3. production TUI Scheduled create / complete / cancel / replace paths passing against the same shared publisher boundary;
4. the old optional-sidecar reader and writer paths deleted rather than retained as fallback compatibility code;
5. the canonical household `scheduled.loam` migrated to the complete lifecycle image and an explicit `scheduled-routing.loam` published;
6. a fresh post-cutover canonical read proving the household Scheduled surface remains readable.

Because the household is not yet relying on LOAM Scheduled persistence for daily operation, this cut is intentionally single-version and may be destructive. No dual reader or long-lived migration shim is required.
