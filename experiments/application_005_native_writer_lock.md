# Application 005: native writer lock

## Question

Application 004 established the required physical ownership scope:

```text
observe -> prepare -> admit -> publish
```

No second writer may enter that scope until the first writer has completed publication.

The next question is concrete:

> Does the Lean runtime already provide a cross-process ownership primitive suitable for this scope, without inventing a stale lock-directory protocol or pretending rename is CAS?

## Candidate

LOAM currently uses Lean 4.33.1. That release exposes:

```text
IO.FS.Handle.lock
IO.FS.Handle.tryLock
IO.FS.Handle.unlock
```

The runtime implementation maps these to an OS-managed file lock:

- POSIX platforms: `flock`
- Windows: `LockFileEx`

This experiment does not add a C shim or shell-level `flock` dependency.

The candidate physical shape is deliberately small:

```text
persistent empty lock file
    +
open Handle
    +
exclusive Handle.lock spanning the complete writer operation
```

The file's existence is not ownership. Ownership lives in the OS-managed lock attached to the open handle.

## Qualification

The workflow runs on both Ubuntu and macOS.

For each platform it:

1. creates one ordinary persistent lock file;
2. starts a separate Lean holder process;
3. waits until that process has acquired the exclusive Handle lock;
4. starts a separate Lean contender and requires `tryLock` to return `false`;
5. kills the holder process with `SIGKILL` while the lock is held;
6. starts another contender and requires `tryLock` to return `true`.

Required output:

```text
blocked_while_holder_alive=true
released_after_holder_death=true
```

The second condition is important. A lock-directory protocol would need an explicit stale-owner policy after process death. Here the persistent file may remain, but the ownership does not remain with it.

## Why this is preferable to the previously considered lock directory

For the current local-file persistence model, the native Handle lock has fewer moving parts:

- no atomic-directory-creation protocol;
- no owner token file;
- no stale lock directory cleanup rule;
- no PID reuse rule;
- no timeout that guesses whether an owner is dead;
- no extra FFI in LOAM;
- no external `flock` executable dependency.

It also matches Application 003's exclusive-ownership model more directly than a revision token followed by ordinary rename.

## What is not yet claimed

This experiment does not yet modify production Persistence, Application, or CLI code.

It does not yet prove that every production writer acquires the lock before observation.

It does not yet qualify Windows execution, network filesystems, distributed writers, fairness, lock starvation, power-loss durability, or a multi-machine protocol.

The Ubuntu/macOS qualification is intentionally aimed at LOAM's current local practical persistence shape.

## Correction relationship

If promoted to production, a correction operation must hold one writer ownership scope across the complete relation-first protocol:

```text
acquire writer ownership
  -> observe Event + Correction state
  -> prepare/admit
  -> publish Correction
  -> publish Event
release writer ownership
```

The Event and Correction files must not be independently locked as if they were unrelated writer transactions.

## Vocabulary boundary

`spend` remains a human-facing CLI entrance.

The physical primitive protects publication ownership, not a special `spend` operation.

## Scope

- native Lean Handle lock only;
- separate-process contention witness;
- holder-death release witness;
- Ubuntu and macOS qualification;
- no production mutation;
- no new Observation number.
