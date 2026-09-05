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

## Interrupted-attempt probe

The first Movement attempt creates a real production-admitted world containing `record-1` and `relation-1`. Application 032 prepares all five immutable family objects but does **not** replace `CURRENT`.

The staging directory is then destroyed to simulate process loss.

The expected selected world remains empty:

```text
event_count=0
relation_count=0
```

A retry starts from `CURRENT`, not from the abandoned staging files or unreferenced objects. The same production Movement entrance must therefore allocate:

```text
record-1
relation-1
```

again.

Because the candidate bytes are identical, all five content-addressed objects should be reused on retry.

This probes the distinction:

```text
physical object exists
!=
selected authority contains semantic identity
```

for mutation-time EventId and RelationUnitId allocation.

## Complete practical fixture

Two real production Movement inputs are used.

First Movement:

```text
paypay   -100 JPY
travel   +100 JPY
open relation relation-1 for 100 JPY
```

Second Movement:

```text
friend-in  -40 JPY
paypay     +40 JPY
discharge relation-1 by 40 JPY
```

After the second `CURRENT` switch and a fresh Lean process, the expected selected answer is:

```text
events                 2
effects                4
paypay                -60 JPY
travel                100 JPY
friend-in             -40 JPY
relations               1
discharges              1
relation-1 outstanding 60 JPY
```

The final selected manifest world is also compared byte-for-byte against the production staging world for all five canonical family encodings.

## What this can establish

If qualified, Application 032 shows that:

1. current Movement input UX can remain unchanged while manifest selection becomes the only canonical authority transition;
2. current production domain admission can remain unchanged;
3. an interrupted prepared candidate does not change selected authority;
4. unselected prepared objects do not reserve EventId or RelationUnitId when retry rematerializes from the selected generation;
5. identical retry bytes can reuse content-addressed objects;
6. restart through `CURRENT` and production typed decoders can reproduce the same final household world and family bytes.

## Important counterweight

This experiment intentionally reuses the unchanged production `loamMovement` writer inside a temporary staging directory.

Therefore the old writer-specific multi-stream publication order still executes **inside staging**. It has been removed from canonical authority semantics, but it has not yet been removed from the implementation protocol surface.

The expected qualification records this explicitly as:

```text
staging_writer_protocol_retained=1
production_migration_earned=0
```

So a successful Application 032 is not yet evidence that the production writer has become smaller in source or mechanism count. It closes the end-to-end semantic/authority path first.

A later direct admitted-typed adapter would still be required to prove that the sidecar staging publication state machine itself can be deleted rather than merely demoted to non-authoritative scratch mechanics.

## Boundary

No production source, canonical path, persistence format, typed decoder, Movement UX, domain admission rule, identity format, migration contract, household data, generic writer framework, or semantic fact family changes.

This remains a scratch Application stacked on Application 031 / PR #411.
