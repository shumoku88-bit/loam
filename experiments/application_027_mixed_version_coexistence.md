# Application 027 — Mixed-version coexistence boundary

## Question

Application 026 qualified an explicit one-time authority cut from practical sidecars to generation-manifest authority and found a bounded selector-only rollback window while both physical representations still name the same verified generation.

This application asks the deployment question left open there:

> Can a sidecar-only LOAM binary safely coexist with a manifest-aware LOAM binary after authority cutover, or does the smallest safe migration require a quiescent single-version boundary?

The question is deliberately about **version coexistence**, not another persistence redesign.

## Freshness and stack

The observation starts from Application 026 / PR #404 head `9de4f66284e34b5c7de1da5080e257a5b80ad237`.

At start, actual `main` is `4f60ea18f3b1e69cb52c94511e796d53a5d16cf2`.

Application 026 is open and mergeable, with exact-head push and pull-request workflows successful.

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

Application 027 keeps every writer operation atomic in the model. If a mixed-version failure exists even with completely serialized operations, stronger intra-operation locking is not the missing mechanism.

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

A legacy write advances only `sidecarGen`.
A manifest-aware write advances only `manifestGen`.

The old reader always returns `sidecarGen`; the aware reader follows the selected authority.

### Quiescent mode

Cutover changes authority to `MANIFEST` and simultaneously establishes the deployment condition:

```text
legacyEnabled = FALSE
```

This does not propose an on-disk domain fact. It models the operational rule that no old binary remains able to present or mutate the household authority after the version epoch changes.

## Properties under qualification

The coexist model intentionally searches for four counterexamples:

1. an equivalent post-cutover coexistence window is reachable;
2. stable reader agreement is not invariant;
3. a later legacy-only write can put sidecars ahead of selected manifest authority;
4. a later manifest-only write can put manifest authority ahead of legacy readers.

The quiescent model checks:

```text
cutoverDone -> not legacyEnabled
```

and that a post-cutover legacy-ahead state is unreachable, while separately proving by expected counterexample that manifest-native progress remains reachable after the cut.

## Practical fixture

The executable fixture uses the ordinary production `loamMovement` binary as the already-installed legacy binary.

It first creates the same two practical Movements used by Application 025 and publishes a byte-identical five-family manifest generation. It then writes an explicit scratch migration selector:

```text
AUTHORITY = MANIFEST
```

After that selector exists, it invokes the unchanged sidecar-only `loamMovement` again on the old EventMemory path.

The important observation is not concurrent racing. The invocation happens later, after cutover, and is allowed to acquire and release the ordinary writer lock normally.

If that old invocation succeeds, then:

```text
legacy sidecar contains record-3
selected manifest does not contain record-3
AUTHORITY still says MANIFEST
```

This is a split authority view produced by fully serialized operations.

## Interpretation boundary

A short mixed-version interval is not automatically unsafe while both representations still name exactly the same generation. That is the same bounded equivalence window already observed for rollback in Application 026.

The question is whether such coexistence is **stable under ordinary future use**. If either old or new version may write, equality can end immediately.

A successful old write after manifest cutover is especially dangerous because the old process may report success while the selected authority never receives that evidence.

Conversely, once manifest authority advances, an old sidecar-only reader can continue returning a plausible but stale household answer.

Therefore permanent dual-version coexistence would require an additional compatibility mechanism such as dual publication, a version fence understood by every executable, or a permanent mediator. None is introduced here merely to preserve old binaries.

## Smallest candidate deployment rule

If qualification confirms the model and fixture, the smallest safe migration shape is expected to be:

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

Preserved sidecars may remain inert rollback/archive material during the bounded pre-divergence window. Their existence must not mean old binaries remain live authority participants.

## Boundary

No production source, canonical persistence path, writer lock, CLI behavior, identity rule, migration contract, dual-write mechanism, package/deployment system, or household data changes.

This application only qualifies the mixed-version deployment boundary. Production migration remains deferred until the result is known.
