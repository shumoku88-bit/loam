# Application 032 — complete Movement mutation through manifest authority

## Goal

Run the existing human-facing Movement entrance all the way through one selected generation-manifest authority path without changing production input semantics, domain admission, canonical fact families, or production persistence.

The experiment deliberately stays scratch. It asks whether the authority boundary can move before LOAM commits to a production migration.

## Path

Application 032 uses the real production `loamMovement` executable for:

```text
human / scripted input
-> current Movement input semantics
-> current world-dependent domain admission
-> current Event / RelationUnit identity allocation
-> current production typed sidecar encoders
```

The sidecars produced by that executable are placed in a temporary staging directory materialized from the currently selected generation. They are **not** canonical authority.

The scratch manifest layer then performs:

```text
staging typed world
-> production typed decoding
-> content-addressed family object preparation
-> CANDIDATE
-> one CURRENT replacement
-> process restart
-> generation-scoped typed read
-> production typed decoding
-> same household projection
```

Five Movement families remain separate:

- Event
- ActualValidity
- EventDescription
- RelationUnit
- RelationDischarge

No semantic family is merged.

## Qualified result

The practical workflow reports:

```text
Application 032 complete Movement manifest mutation PASS
human_input_mutations=2
production_input_semantics_reused=1
production_domain_admission_reused=1
selected_authority_switches=2
interrupted_candidate_authority_changes=0
orphan_event_id_reservations=0
orphan_relation_unit_id_reservations=0
retry_reused_prepared_objects=5
production_typed_family_boundaries=5
canonical_family_byte_matches=5
semantic_projection_match=1
staging_writer_protocol_retained=1
production_migration_earned=0
```

## Interrupted-attempt result

The first Movement attempt creates a real production-admitted world containing `record-1` and `relation-1`. Application 032 prepares its five family references but does **not** replace `CURRENT`.

`RelationDischarge` is unchanged from the selected empty generation, so that immutable object is reused immediately; the other four family objects are newly prepared.

The staging directory is then destroyed to simulate process loss. A fresh generation-scoped read still observes:

```text
event_count=0
relation_count=0
```

A retry rematerializes only the selected `CURRENT` generation and runs the same production Movement entrance again. It allocates `record-1` again, and its relation input admits `relation-1` again. Thus the abandoned candidate's physical objects do not reserve either semantic identity.

The retry reproduces the same canonical family bytes, so all five prepared objects are reused:

```text
retry_reused_prepared_objects=5
orphan_event_id_reservations=0
orphan_relation_unit_id_reservations=0
```

This establishes the mutation-time distinction:

```text
physical object exists
!=
selected authority contains semantic identity
```

for the observed EventId and RelationUnitId namespaces.

## Complete practical fixture

Two real production Movement inputs are used.

First Movement:

```text
paypay   -100 JPY
travel   +100 JPY
open relation relation-1 for 100 JPY
```

After the first `CURRENT` switch and a fresh process:

```text
event_count=1
paypay=-100
travel=100
relation_count=1
relation_outstanding=100
```

Second Movement:

```text
friend-in  -40 JPY
paypay     +40 JPY
discharge relation-1 by 40 JPY
```

After the second `CURRENT` switch and another generation-scoped typed read:

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

The final selected manifest world also matches the production staging world across all five canonical family encodings:

```text
canonical_family_byte_matches=5
semantic_projection_match=1
```

## Movement protocol surface measurement

Application 032 remeasures the current Movement writer and the scratch manifest authority mechanics separately:

```text
current_movement_publisher_lines=132
current_movement_publisher_bytes=8501
current_movement_cross_family_save_calls=5
current_movement_max_partial_authority_prefixes=4
current_movement_residue_widened_identity_namespaces=2

manifest_authority_mechanics_lines=196
manifest_authority_mechanics_bytes=8622
manifest_authority_switches_per_mutation=1
manifest_partial_authority_prefixes_per_mutation=0
manifest_orphan_objects_reserve_semantic_identity=0
manifest_operation_specific_retry_branches=0

staging_writer_protocol_retained=1
staging_cross_family_save_calls_max=5
staging_partial_residue_policy_retained=1
production_migration_earned=0
```

The source-size numbers are deliberately **not** treated as a win. The scratch manifest authority mechanics are currently larger than the current Movement publisher slice in both lines and bytes, and the slices do not represent identical reusable scope.

The useful compression appears instead in canonical protocol state:

- five independent cross-family authority writes become one selected-authority switch per mutation;
- four possible partial-authority prefixes become zero;
- two Movement semantic identity namespaces no longer need to treat unselected prepared objects as reservations;
- no operation-specific retry branch is required in the scratch manifest authority layer.

But because the unchanged production Movement writer still runs inside disposable staging, the implementation as a whole has not yet eliminated its five-save state machine or residue policy. Application 032 therefore separates **authority compression** from **implementation compression** instead of claiming both at once.

## Interpretation

Application 032 qualifies these points for the observed Movement path:

1. current Movement input semantics can remain unchanged while canonical authority becomes one selected generation;
2. current production domain admission can remain unchanged;
3. candidate object preparation can occur without changing authority;
4. retry can ignore unselected object residue for EventId and RelationUnitId allocation when it rematerializes from selected authority;
5. identical retry bytes can reuse content-addressed objects;
6. restart through `CURRENT` and production typed decoders reproduces the same final household world and canonical family bytes;
7. canonical authority protocol complexity decreases even though scratch source size and total implementation surface have not yet decreased.

## Important counterweight

This experiment intentionally reuses the unchanged production `loamMovement` writer inside a temporary staging directory.

Therefore the old writer-specific multi-stream publication order still executes **inside staging**. It has been removed from canonical authority semantics, but it has not yet been removed from the implementation protocol surface.

The qualification records this explicitly as:

```text
staging_writer_protocol_retained=1
production_migration_earned=0
```

So Application 032 is not yet evidence that the production writer has become smaller in source or mechanism count. It closes the end-to-end semantic/authority path first.

A later direct admitted-typed adapter is still required to prove that the sidecar staging publication state machine itself can be deleted rather than merely demoted to non-authoritative scratch mechanics.

## Boundary

No production source, canonical path, persistence format, typed decoder, Movement UX, domain admission rule, identity format, migration contract, household data, generic writer framework, or semantic fact family changes.

This remains a scratch Application stacked on Application 031 / PR #411.
