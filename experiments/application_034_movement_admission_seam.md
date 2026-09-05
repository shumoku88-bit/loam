# Application 034: Shared Movement Admission Seam

## Question

Application 033 showed that one practical Movement mutation can go directly from
selected generation-scoped typed state to manifest object preparation and one
`CURRENT` replacement without materializing or saving sidecar staging.

Its remaining weakness was deliberate: production Movement admission lived
inside the private sidecar publisher, so the scratch direct path copied the
identity-allocation and world-dependent admission rules.

Application 034 asks a narrower question:

> Can the current Movement-specific admission meaning become one production
> typed seam shared by the existing sidecar publisher and the direct manifest
> probe, without changing practical bytes and without introducing a generic
> writer framework?

## Pre-refactor baseline

Before changing production code, the branch ran the two Application 033
Movements through the then-current `loamMovement` and captured the five canonical
family images.

```text
Event              f1db19930ebce381589d55dcb6279031263465f088deaba3e7e68d5b83090992  177 bytes
ActualValidity     7a4d44b8a877386c70b91131f644e6e97e2a6ff8658989013e9958e1ef727f5f   81 bytes
EventDescription   77a98cf7921d12ee5da6757539d5e195410c8c3c0de971bc450689e0daedaa6a  113 bytes
RelationUnit       cd73e5303796be1e23711c7b9849190de4e61e4bd0672a5f2d6905552ff50f73   82 bytes
RelationDischarge  8e8626073f6e205950ab5287bee14372f0dd0e30a0b7d91076dc5faccba718ea   66 bytes
```

The final qualification regenerates these images after the refactor and requires
all five hashes and all five byte sizes to remain exact.

## Extracted boundary

`Loam.MovementAdmission` now owns three Movement-specific typed shapes:

```text
Draft
World
Admitted
```

and one operation:

```text
admit? : World -> Draft -> Except String Admitted
```

The operation owns the existing practical semantic work performed after writer
state has been read and before physical publication begins:

- fresh Event identity allocation;
- fresh ActualValidity fact identity allocation;
- fresh RelationUnit identity allocation;
- retained raw relation/discharge identity reservation rules;
- Event construction;
- RelationUnit and RelationDischarge materialization;
- ActualValidity and optional EventDescription extension;
- source-local relation frontier admission;
- current-target discharge frontier admission.

It performs no filesystem IO, sidecar save, manifest object preparation,
`CURRENT` replacement, terminal rendering, or writer locking.

This is deliberately Movement-specific. No generic writer, repository, CRUD,
transaction, or persistence framework is introduced.

## Existing sidecar writer

`MovementCli.publishDraftUnderOwnership` still re-reads the current sidecar world
under the existing writer-ownership boundary. It then calls
`MovementAdmission.admit?` and physically publishes the returned typed world in
the same qualified order:

```text
ActualValidity
-> optional EventDescription
-> optional RelationUnit update
-> optional RelationDischarge update
-> Event last
```

So Application 034 does not claim that the production sidecar publication state
machine has disappeared.

The measured publisher boundary is now:

```text
current_movement_publisher_lines=97
current_movement_publisher_bytes=5470
current_movement_cross_family_save_calls=5
current_movement_max_partial_authority_prefixes=4
```

## Direct manifest probe

Application 033 was changed to use exactly the same production admission seam.
Its previous copied admission implementation is gone:

```text
scratch_direct_admission_lines=0
scratch_direct_admission_bytes=0
scratch_admission_rule_copy=0
production_admission_seam_reused=1
production_sidecar_publisher_uses_seam=1
manifest_probe_uses_production_seam=1
```

The manifest-specific adapter remains small:

```text
scratch_direct_adapter_lines=19
scratch_direct_adapter_bytes=925
```

The shared production admission module currently measures:

```text
production_admission_seam_lines=287
production_admission_seam_bytes=11582
```

These numbers are not presented as a whole-source compression claim. The
important change is ownership: one Movement-specific semantic admission
implementation replaces a private production implementation plus a scratch copy.

## Requalification

The Application 033 direct path is rerun after the refactor. It still exercises:

```text
direct_manifest_mutations=2
manifest_mutation_sidecar_materializations=0
manifest_mutation_sidecar_save_calls=0
manifest_mutation_sidecar_writer_runs=0
selected_authority_switches=2
interrupted_candidate_authority_changes=0
orphan_event_id_reservations=0
orphan_relation_unit_id_reservations=0
retry_reused_prepared_objects=5
canonical_family_byte_matches=5
semantic_projection_match=1
scratch_admission_rule_copy=0
production_admission_seam_reused=1
```

The selected final answer remains:

```text
event_count=2
effect_count=4
recorded_paypay=-60
recorded_travel=100
recorded_friend_in=-40
relation_count=1
discharge_count=1
relation_outstanding=60
```

A separate Application 034 check also requires the production sidecar result to
match the pre-refactor five-family hashes exactly. A world-dependent discharge
against nonexistent `relation-999` must still fail closed with status 2 and must
not publish `record-2`.

## Interpretation

Application 033 moved the bottleneck from physical publication to a private
semantic seam. Application 034 removes that duplication without merging the five
semantic fact families and without making admission aware of either sidecars or
manifest authority.

The resulting shape is now:

```text
                         -> existing ordered sidecar publisher
MovementAdmission.admit?
                         -> direct manifest object publisher
```

The two physical publishers remain meaningfully different. Sharing admission
does not imply sharing their authority protocol.

## Remaining boundary

```text
production_sidecar_writer_still_exists=1
sidecar_save_protocol_retained=1
production_migration_earned=0
```

Application 034 therefore earns a shared production Movement admission seam, not
production manifest migration.

The next distinct gate, if this line continues, is whether the existing
production Movement entrance can replace only its physical publication tail with
manifest authority while preserving the same shared admission result, exact
household behavior, migration/cutover rules, and fail-closed operational
boundary. That should remain separate from this refactor.
