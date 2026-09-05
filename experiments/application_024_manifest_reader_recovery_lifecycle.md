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

After a simulated process restart, a fresh `readCurrent` reconstructs the old selected generation exactly. The unreferenced objects exist physically but are not authority.

The retry then publishes Event + ActualValidity. Because the Event object is content-addressed and already exists with matching bytes, it is reused rather than rewritten. Only the not-yet-prepared ActualValidity object is created on retry. No operation-specific "dangling Event evidence" recovery branch is required at this physical layer.

The abandoned RelationUnit object remains unreferenced and inert.

## Stale readers and garbage collection

A reader may load the old manifest before a writer replaces `CURRENT`, then open one of that generation's objects afterward. Writer ownership does not own readers.

Therefore the safe online GC policy in this experiment is deliberately:

```text
no deletion
```

The probe verifies that the old selected generation remains readable after a new generation is published, and that the unrelated abandoned object is retained as well.

This is not a claim that garbage collection is unnecessary. It makes the cost explicit: deletion requires a separate quiescent/offline or otherwise reader-safe maintenance proof. Immediate online deletion is not smuggled into the shared publication primitive.

## Fail-closed reader qualification

The executable probe rejects four physical failures:

1. missing `CURRENT`;
2. malformed `CURRENT`;
3. missing selected object;
4. selected object whose bytes do not match the manifest digest.

After each injected failure, restoring the authoritative bytes restores the same selected generation.

## Qualified result

The exact-head lifecycle workflow on the executable probe succeeded and reported:

```text
Application 024 manifest reader/recovery lifecycle PASS
fail_closed_reader_cases=4
interrupted_unreferenced_restart_kept_authority=1
retry_reused_prepared_object=1
stale_reader_old_generation_survives=1
online_gc_deletions=0
orphan_objects_reserve_semantic_identity=0
verified_fail_closed_cases=4
```

The measured scratch physical lifecycle surface, including family identity, manifest codec, content-addressed object preparation, atomic selector publication, strict selected-generation reading, generic retry reuse, and conservative online retention, is:

```text
211 lines
8362 bytes
```

The measurement also fixes these structural counts:

```text
shared physical reader                  1
shared physical publisher               1
operation-specific recovery branches    0
online GC deletions                      0
deferred GC obligation                   1
migration obligation                     1
reader indirection layer                 1
```

These source numbers are supplemental. They are not treated as a synthetic score against current production because current direct readers, migration code, and writer-specific recovery logic live across several modules and do not share one exact source boundary.

## Interpretation

The reader/recovery cost does not recreate the five writer-specific state machines observed in Applications 018-023.

At this scratch physical layer, interruption before `CURRENT` replacement has one generic meaning:

```text
unreferenced immutable object
= not authority
```

Restart therefore does not need to inspect the object directory to infer a half-completed household operation. A retry may reuse matching prepared bytes by content address, but their mere presence neither activates semantics nor reserves EventId, RelationUnitId, CapacityMovementId, or another household identity.

The important counterweight is storage lifecycle. Because readers can outlive a `CURRENT` read and are not covered by writer ownership, eager online deletion would reintroduce a concurrency protocol. The smallest safe online rule observed here is instead to retain old and abandoned objects and defer deletion to a separately justified quiescent/offline mechanism.

So the complexity movement is now more precise:

```text
removed / centralized:
  writer-specific publication order
  partial canonical prefixes
  operation-specific physical recovery
  semantic identity reservation caused only by partial physical residue

added / retained:
  one shared reader indirection
  immutable-object storage growth
  deferred GC / maintenance obligation
  migration / compatibility obligation
  writer ownership
```

This is a stronger result than writer-side source reduction alone: the restart path remains generic rather than recreating the removed protocol under another name.

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

A smaller writer is not enough if reader/recovery complexity merely reappears elsewhere. Application 024 did not observe that reappearance in the physical lifecycle tested here.

## Boundary

This is a scratch physical-persistence experiment only.

It changes no production parser, persistence format, canonical path, executable behavior, semantic identity rule, household data, or current migration contract. The family payloads are opaque bytes here; production typed decoders remain a separate integration gate.

Production migration is not earned by this application alone. The smallest remaining gate is to connect the manifest-selected bytes to the existing production typed codecs and compare one complete practical read/write path, while separately designing migration and offline/quiescent object retirement.
