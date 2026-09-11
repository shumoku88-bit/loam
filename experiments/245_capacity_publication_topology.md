# Experiment 245: Capacity publication topology

Status: **research only; no production topology migration authorized**

Baseline: production PR #698 introduced one local `CapacityAuthority` handle while deliberately retaining the current two-file backing representation.

## Question

Hold the retained Capacity meaning fixed:

```text
CapacityMovement
CapacityEffective
```

Then compare only the publication topology for one fresh Capacity operation:

```text
A. current split backing
   effective image -> movement image

B. one typed atomic Capacity image
   { movements, effective }
```

The question is not whether `CapacityEffective` can be deleted. Observations 112 and 158 already earned that information independently. The question is narrower:

> What additional crash/recovery state is created solely by publishing these two meanings through two separately replaced physical images?

## Why this is not Observation 055, 060, or 240 again

Observation 055 already established that logical fact topology does not determine atomic publication topology. Dependency ordering or fail-closed admission can preserve semantic closure over split storage.

Observation 060 then modeled an Event/Correction split protocol whose first step is explicitly retryable after restart. The same publication request can be replayed from its first idempotent step and eventually complete.

Observation 240 proposes the representation-free evidence-before-activation safety law. It remains separately gated by the repository's replacement-dividend rule.

Capacity has a different current production pressure:

```text
load complete Capacity image
  -> publish effective evidence
  -> publish activating movement
```

If the second publication fails, production reports that already-published effective evidence is inert and requires explicit recovery. On a subsequent ordinary `publish` call, the publisher first checks bidirectional completeness and refuses the incomplete image before allocating or replaying the movement.

Therefore the interesting question is no longer only **safety**. It is **availability and ordinary-retry recoverability**.

## Production correspondence

`CapacityAuthority.Image` exposes the two retained families behind one topology-neutral handle:

```text
movements : CapacityMemory
effective : CapacityEffectiveMemory String
```

The current publisher retains these rules:

1. acquire Capacity writer ownership;
2. load both families;
3. reject incomplete evidence;
4. construct one fresh movement/effective pair;
5. save effective evidence first;
6. save the movement image second.

The current completeness predicate is bidirectional:

```text
every movement has effective evidence
and
every effective entry names a movement
```

So an effective-only crash residue is not merely ignored by Current Coverage. It makes the complete Capacity projection unavailable and blocks another ordinary Capacity publication until some separate recovery action repairs the authority.

The existing Capacity publisher regression deliberately seeds an orphan effective entry and requires later publication to fail closed. This experiment treats that as the current contract, not as an accidental implementation bug.

## Model

`Observation245CapacityPublicationTopology.tla` uses one fresh operation and two booleans:

```text
effectiveNew
movementNew
```

They represent whether the operation's two retained meanings are durable in the current physical image(s).

### Split protocol

The modeled writer is:

```text
admit complete image
-> publish effective
-> publish movement
```

A crash can occur before completion. Restart re-enters the ordinary publication admission boundary.

If the crash happened after effective publication, restart observes:

```text
effectiveNew = TRUE
movementNew  = FALSE
```

and the ordinary completeness check moves the writer to `blocked` rather than replaying the second half.

### Atomic-image candidate

The comparison candidate retains both semantic fields but replaces them as one image:

```text
admit complete image
-> atomic commit { effectiveNew = TRUE, movementNew = TRUE }
```

A crash before the replacement leaves the previous complete image intact. Ordinary restart can re-admit and try the atomic replacement again.

This assumes the one-image replacement primitive itself is atomic at the same abstraction level as today's individual sibling-stage + rename operations. It does not model power-loss durability beyond that assumption.

## Properties

### Split activation safety

```text
movementNew => effectiveNew
```

The current effective-before-movement ordering should preserve this invariant.

### Split coverage availability

```text
effectiveNew = movementNew
```

This is deliberately **not** expected to be invariant. The model must find the crash prefix where effective evidence is durable but movement authority is not.

### Split ordinary-retry recovery

The model must also find the longer path:

```text
admit
-> effective
-> crash
-> restart
-> ordinary admission
-> blocked
```

This distinguishes current Capacity behavior from Observation 060's explicitly idempotent retry protocol.

### Atomic completeness

The atomic-image candidate should preserve:

```text
effectiveNew = movementNew
```

across every modeled crash/restart step.

### Atomic ordinary retry

The model must find a path where a pre-commit crash is followed by ordinary restart and eventual complete publication.

## Expected checker results

The temporary CI should establish:

1. `SplitIndInv` starts true: PASS.
2. one `SplitNext` step preserves `SplitIndInv`: PASS.
3. `SplitIndInv` implies activation safety: PASS.
4. split crash can make complete Capacity coverage unavailable: counterexample required.
5. restart after that crash can reach ordinary-publication `blocked`: counterexample required.
6. `AtomicIndInv` starts true: PASS.
7. one `AtomicNext` step preserves `AtomicIndInv`: PASS.
8. atomic topology preserves complete paired evidence: PASS.
9. crash before atomic commit can still recover through ordinary restart: counterexample to `NoAtomicRecoveredCompletion` required.

## What a positive result would mean

It would **not** prove that one file is globally better.

It would establish a narrower result:

> The current split topology buys no additional semantic distinction for this operation, while it does introduce a reachable complete-authority availability loss that the current ordinary publisher cannot repair by retrying the same entrance.

That makes the split topology pay an operational rent. To keep it, LOAM should be able to point to compensating value such as materially lower write amplification, corruption localization, human recovery, or another measured property.

## Not modeled

- concurrent Capacity writers beyond the existing ownership assumption;
- partial/corrupt bytes inside one staged file replacement;
- fsync or power-loss durability;
- write amplification;
- corruption blast radius;
- human inspectability;
- automatic repair policy;
- deletion/rollback of an orphan effective row;
- multiple pending Capacity operations;
- any change to Capacity, Purpose, Entitlement, or effective-time semantics.

## Stop rule

This branch is a research lab. Do not merge the TLA+ model or its dedicated workflow merely because the checker is green.

After qualification:

- if the result only restates an already-owned law, retire the lab;
- if it exposes a Capacity-specific production decision, retain the conclusion in the smallest durable place and choose the next production experiment separately;
- do not turn this into a generic transaction/repository framework.
