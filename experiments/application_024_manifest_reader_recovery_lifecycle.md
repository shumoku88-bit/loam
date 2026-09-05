# Application 024: Manifest reader + recovery lifecycle

## Pressure

Application 023 showed that the generation-manifest topology is materially smaller on the writer-side temporal state-machine surface, but it also identified the costs moved to the other side of the boundary:

- one reader indirection through `CURRENT`;
- object lifecycle / garbage collection;
- migration / compatibility;
- continued writer ownership.

A writer-only comparison is therefore not enough.

Application 024 asks:

> If `CURRENT` is also the only physical reader authority, can restart and interruption recovery remain generic and fail-closed without recreating writer-specific residue policy elsewhere?

This application is intentionally stacked on Application 023 / PR #399.

## Scratch lifecycle

The probe keeps the same twelve typed family names used by Application 022. Each selected family reference has the exact shape:

```text
FamilyName -> objects/FamilyName/<sha256>.loam + sha256
```

The manifest parser requires every family, the expected family order, a 64-character lowercase hexadecimal digest, and the exact content-addressed path implied by family + digest.

`readCurrent` performs one shared physical read path:

```text
CURRENT
  -> strict manifest decode
  -> every selected object must exist
  -> every selected object must match its digest
  -> one coherent Generation
```

No fallback to object-directory contents is permitted.

## Interrupted preparation and restart

The probe deliberately prepares new Event and RelationUnit objects without replacing `CURRENT`.

After a simulated process restart, a fresh `readCurrent` must still reconstruct the old selected generation exactly. The unreferenced objects exist physically but are not authority.

The retry then publishes Event + ActualValidity. Because the Event object is content-addressed and already exists with matching bytes, it is reused rather than rewritten. No operation-specific "dangling Event evidence" recovery branch is required at this physical layer.

The abandoned RelationUnit object remains unreferenced and inert.

## Stale readers and garbage collection

A reader may load the old manifest before a writer replaces `CURRENT`, then open one of that generation's objects afterward. Writer ownership does not own readers.

Therefore the safe online GC policy in this experiment is deliberately:

```text
no deletion
```

The probe verifies that the old selected object remains readable after a new generation is published, and that the unrelated abandoned object is retained as well.

This is not a claim that garbage collection is unnecessary. It makes the cost explicit: deletion requires a separate quiescent/offline or otherwise reader-safe maintenance proof. Immediate online deletion is not smuggled into the shared publication primitive.

## Fail-closed reader qualification

The executable probe requires rejection of four physical failures:

1. missing `CURRENT`;
2. malformed `CURRENT`;
3. missing selected object;
4. selected object whose bytes do not match the manifest digest.

After each injected failure, restoring the authoritative bytes must restore the same selected generation.

## Smallness dimensions

The point is not to optimize one score. The candidate is evaluated on several independent dimensions:

```text
writer-specific publication protocol
partial authority states
operation-specific recovery branch
semantic identity reservation caused by residue
shared reader mechanism
reader indirection
online GC
storage-retention obligation
migration obligation
source lines / bytes
```

A smaller writer is not enough if reader/recovery complexity merely reappears elsewhere.

## Boundary

This is a scratch physical-persistence experiment only.

It changes no production parser, persistence format, canonical path, executable behavior, semantic identity rule, household data, or current migration contract. The family payloads are opaque bytes here; production typed decoders remain a separate integration gate.

Production migration is not earned by this application alone.
