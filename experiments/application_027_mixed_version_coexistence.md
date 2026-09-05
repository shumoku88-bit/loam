# Application 027 — Mixed-version coexistence boundary

## Question

Application 026 qualified an explicit one-time authority cut from practical sidecars to generation-manifest authority and found a bounded selector-only rollback window while both physical representations still name the same verified generation.

This application asks:

> Can a sidecar-only LOAM binary safely coexist with a manifest-aware LOAM binary after authority cutover, or does the smallest safe migration require a quiescent single-version boundary?

The question is deliberately about **version coexistence**, not another persistence redesign.

## Freshness and stack

The observation starts from Application 026 / PR #404 head `9de4f66284e34b5c7de1da5080e257a5b80ad237`.

At start, actual `main` is `4f60ea18f3b1e69cb52c94511e796d53a5d16cf2`.

Application 026 was open and mergeable, with exact-head push and pull-request workflows successful.

## Existing writer boundary

`Loam.WriterOwnership.withOwnership` is an OS-managed exclusive lock around one complete writer operation. It intentionally gives the lock file no semantic meaning, and `finally` releases the OS lock after the action.

Therefore it solves:

```text
writer A and writer B must not publish stale replacements concurrently
```

but it does not by itself solve:

```text
an older executable must never write the old physical authority after a topology epoch change
```

Application 027 keeps every writer operation atomic in the model. The mixed-version failure below therefore exists even with completely serialized operations; stronger intra-operation locking is not the missing mechanism.

## TLA+ model

The bounded model retains only the deployment-relevant state:

```text
authority      SIDECAR | MANIFEST
sidecarGen     generation number
manifestGen    generation number
legacyEnabled  whether an old sidecar-only binary may still act
cutoverDone    whether manifest authority has been selected
```

Two modes are compared.

### Coexist mode

Cutover changes authority to `MANIFEST` but leaves `legacyEnabled = TRUE`.

A legacy write advances only `sidecarGen`. A manifest-aware write advances only `manifestGen`.

The old reader always returns `sidecarGen`; the aware reader follows the selected authority.

### Quiescent mode

Cutover changes authority to `MANIFEST` and simultaneously establishes the deployment condition:

```text
legacyEnabled = FALSE
```

This is not an on-disk household fact. It models the operational rule that no old binary remains able to present or mutate household authority after the version epoch changes.

## Qualified TLA+ result

The dedicated workflow qualified every intended boundary.

In coexist mode, TLC found all four expected counterexamples:

```text
equivalent post-cutover coexistence window   reachable
stable mixed-version reader agreement         false
legacy-only post-cutover divergence           reachable
manifest-only post-cutover divergence         reachable
```

The shortest split-view trace is only three states:

```text
SIDECAR G0 / MANIFEST G0
        ↓ cutover
MANIFEST selected, both still G0
        ↓ legacy write
SIDECAR G1 / selected MANIFEST G0
```

TLC therefore falsifies stable mixed-version coexistence without requiring any concurrent write interleaving.

In quiescent mode, TLC exhaustively checked the bounded state graph with no error for:

```text
cutoverDone -> not legacyEnabled
no post-cutover state with sidecar generation ahead of manifest
```

The separate expected-counterexample check also reached a manifest-native write after cutover, proving that quiescence does not freeze the new epoch:

```text
SIDECAR G0 / MANIFEST G0
        ↓ quiescent cutover
legacy disabled, MANIFEST G0 selected
        ↓ manifest write
MANIFEST G1
```

## Practical production-binary fixture

The executable fixture uses the ordinary production `loamMovement` binary as an already-installed legacy binary.

It creates the same two practical Movements used by Application 025 and publishes their typed five-family manifest generation. It then installs the scratch selector:

```text
AUTHORITY = MANIFEST
```

After cutover, the unchanged sidecar-only `loamMovement` is invoked later on the old EventMemory path. The call succeeds normally and reports `record-3`.

Observed result:

```text
Application 027 practical mixed-version probe PASS
equivalent_coexistence_window=1
legacy_writer_post_cutover_succeeded=1
legacy_sidecar_record3=1
selected_manifest_record3=0
selected_authority_remained_manifest=1
writer_lock_prevented_epoch_stale_write=0
```

The selected `CURRENT` bytes and selected Event object remain unchanged while the legacy sidecar gains `record-3`.

So an old binary can successfully perform a fully writer-locked operation after manifest cutover while writing only non-selected legacy state. This is not corruption of manifest authority; it is worse from the user's perspective in a different way: the old process can report a successful household mutation that the selected authority does not contain.

## Main finding

There **is** a safe mixed-version moment, but there is no stable mixed-version operating regime under the current mechanisms.

The safe moment is exactly the Application 026 rollback window:

```text
sidecar generation == selected manifest generation
```

As soon as either version writes independently, the two views can diverge.

- A legacy write can create acknowledged evidence that manifest authority never receives.
- A manifest write can leave an old sidecar-only reader returning a plausible stale answer.
- Existing `WriterOwnership` serializes operations but does not fence executable epochs after the lock is released.

Therefore a persistent mixed-version regime would need extra machinery such as permanent dual publication, an epoch fence understood by every executable, or a mediator. Application 027 does not earn any of those merely to preserve old binaries.

## Smallest earned deployment rule

The smaller boundary is a quiescent single-version cut:

```text
stop/quiesce old LOAM authority consumers
        ↓
hold WriterOwnership
        ↓
prepare + verify equivalent manifest generation
        ↓
atomically select MANIFEST authority
        ↓
activate only manifest-aware binaries
        ↓
release into the new single-version epoch
```

This applies to old writers and to old readers that would present their sidecar answer as current household authority.

Preserved sidecars may remain inert rollback/archive material during the bounded pre-divergence window. Their physical existence does **not** grant old binaries continuing authority participation.

The first manifest-native write closes the cheap rollback window exactly as Application 026 observed.

## What this does not earn

This result does not yet authorize production migration. A real cut still needs an explicit deployment/cutover implementation and a later retirement decision for preserved sidecars and manifest objects.

It also does not require:

```text
permanent dual writes
permanent legacy fallback
permanent compatibility daemon
new household semantic facts
```

## Boundary

No production source, canonical persistence path, writer lock, CLI behavior, identity rule, migration contract, dual-write mechanism, package/deployment system, or household data changes.

Application 027 qualifies the deployment epoch boundary only.
