# Application 033 — direct Movement manifest adapter

## Goal

Test whether the observed practical Movement mutation can bypass the Application 032 sidecar staging writer entirely:

```text
selected generation-scoped typed world
-> Movement admission shape
-> admitted typed world
-> content-addressed family objects
-> one CURRENT authority switch
-> restart
-> generation-scoped typed read
```

The experiment remains scratch and stacked on Application 032 / PR #413.

## Why this Application exists

Application 032 established the complete human-facing path through manifest authority, but it still ran the unchanged production five-save `loamMovement` writer inside disposable sidecar staging.

Application 033 asks the narrower next question:

> Is that sidecar staging writer semantically necessary once the selected generation has already been decoded as typed state?

## Direct mutation path

The scratch adapter reads the five selected Movement families directly from `CURRENT`:

- Event
- ActualValidity
- EventDescription
- RelationUnit
- RelationDischarge

It then applies the current Movement admission shape to an in-memory draft, encodes the resulting typed world with the existing production codecs, prepares immutable content-addressed family objects, writes a non-authoritative `CANDIDATE`, and changes selected authority only by replacing `CURRENT`.

The manifest mutation path performs no sidecar materialization and calls no sidecar save function.

## Honest admission boundary

The current production Movement admission mechanics are private inside `MovementCli.publishDraftUnderOwnership`.

Therefore Application 033 cannot call a production function equivalent to:

```text
TypedWorld -> MovementDraft -> AdmittedMovement
```

without first changing production source.

To keep this experiment scratch-only, Application 033 reproduces the current admission rules and then compares its result against an independent real-production `loamMovement` oracle.

This limitation is explicit:

```text
scratch_admission_rule_copy=1
production_admission_seam_reused=0
production_migration_earned=0
```

A successful parity result therefore supports removal of sidecar staging from the observed manifest mutation path, but does not yet qualify a reusable production admission seam.

## Practical fixture

The direct path applies the same two Movement cases used by Application 032.

First Movement:

```text
2026-09-05
paypay   -100 JPY
travel   +100 JPY
open relation relation-1 for 100 JPY
```

Second Movement:

```text
2026-09-06
friend-in  -40 JPY
paypay     +40 JPY
discharge relation-1 by 40 JPY
```

After the two selected authority switches, a fresh generation-scoped typed read reports:

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

## Interrupted candidate / retry

The first direct admitted candidate prepares `record-1` and `relation-1` but does not replace `CURRENT`.

A generation-scoped read still observes the empty selected world:

```text
event_count=0
relation_count=0
```

The same direct mutation is then retried from selected authority. It allocates `record-1` / `relation-1` again and reuses all five prepared family objects:

```text
retry_reused_prepared_objects=5
orphan_event_id_reservations=0
orphan_relation_unit_id_reservations=0
```

So the Application 032 distinction survives even after sidecar staging is removed:

```text
physical object exists
!=
selected authority contains semantic identity
```

## Production oracle parity

Only after the direct manifest mutation has completed, the workflow creates a separate production sidecar world by invoking the real `loamMovement` executable twice with the same practical inputs.

That production writer is comparison evidence only. It is never staging for the manifest mutation.

The final comparison reports:

```text
canonical_family_byte_matches=5
semantic_projection_match=1
comparison_oracle_production_writer_runs=2
manifest_mutation_sidecar_writer_runs=0
```

Thus the direct scratch mutation produced byte-for-byte identical canonical representations for all five Movement families and the same household projection as the current production writer for the observed fixture.

## Protocol surface measurement

Application 033 measures the current production Movement publisher separately from the scratch direct components.

Current production publisher slice:

```text
current_movement_publisher_lines=132
current_movement_publisher_bytes=8501
current_movement_cross_family_save_calls=5
current_movement_max_partial_authority_prefixes=4
```

Scratch admission copy:

```text
scratch_direct_admission_lines=212
scratch_direct_admission_bytes=8559
```

Scratch direct manifest adapter itself:

```text
scratch_direct_adapter_lines=19
scratch_direct_adapter_bytes=897
```

Scratch manifest mechanics used by this standalone experiment:

```text
scratch_manifest_mechanics_lines=210
scratch_manifest_mechanics_bytes=8985
```

Canonical direct-mutation protocol:

```text
manifest_mutation_sidecar_writer_protocols=0
manifest_mutation_sidecar_save_calls=0
manifest_partial_authority_prefixes=0
manifest_authority_switches_per_mutation=1
```

## Interpretation

Application 033 does **not** show a source-line compression win. The standalone scratch experiment duplicates both manifest infrastructure and private admission mechanics, so its total source is intentionally not a production design proposal.

What it does establish for the observed Movement path is more specific:

1. the Application 032 sidecar staging writer is not required to obtain the same admitted five-family typed world;
2. the manifest mutation itself needs zero sidecar writer protocols and zero sidecar save calls;
3. immutable candidate objects can remain non-authority until one `CURRENT` switch;
4. interrupted candidate objects still do not reserve EventId or RelationUnitId when retry begins from selected authority;
5. the direct selected result matches the real production writer byte-for-byte across all five family codecs and semantically at the household projection;
6. the remaining duplication pressure has moved from publication ordering to the private Movement admission seam.

The strongest compression result is therefore:

```text
Application 032 manifest mutation path:
  staging writer protocol retained = 1
  staging cross-family saves max   = 5

Application 033 manifest mutation path:
  sidecar writer protocols         = 0
  sidecar save calls               = 0
  partial authority prefixes       = 0
  CURRENT switches per mutation    = 1
```

The 19-line scratch direct adapter is small; the large remaining scratch block is the 212-line copied admission region. This strongly suggests that the next useful observation is not a generic writer framework. It is whether current Movement admission can be factored into one production typed seam shared by the existing sidecar publisher and a future manifest publisher without changing semantics.

## Boundary

No production source, production persistence path, CLI behavior, identity format, semantic family, migration contract, household data, or deployment behavior changes.

The production sidecar writer still exists unchanged. Production migration remains unearned.
