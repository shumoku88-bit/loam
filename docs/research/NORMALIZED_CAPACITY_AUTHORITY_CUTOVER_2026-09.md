# Normalized Capacity authority cutover

Date: 2026-09-18

## Decision

`CapacityMovement` and `CapacityEffective` remain independent retained meanings.
The production persistence topology changes from two sibling files to one normalized
`capacity.loam` authority image.

Historical storage:

```text
capacity.loam
capacity.loam.effective
```

Production storage after cutover:

```text
capacity.loam
```

## Why

The former publisher required an effective-first two-write protocol. If the second
write failed, the retained effective row was intentionally inert and later writers
refused the incomplete pair until explicit recovery.

The normalized document was first qualified independently by round-tripping both
synthetic fixtures and the current private canonical household Capacity pair.
`CapacityEvidence` preserves the semantic distinction while admitting only
cross-family complete images.

The production writer can therefore publish:

```text
load admitted image
-> pure candidate transition
-> encode one normalized document
-> stage off-authority
-> typed re-decode
-> single rename over capacity.loam
```

No orphan effective state is part of the new publication protocol.

## Migration boundary

`CapacityAuthority` temporarily accepts both representations on read:

- normalized `capacity.loam`;
- a complete legacy `capacity.loam` + `.effective` pair.

Writers always emit the normalized representation. The first successful Capacity
write against a legacy pair therefore replaces the primary file atomically with a
normalized image. Any old `.effective` sidecar becomes an ignored compatibility
artifact and may be removed separately when canonical household data is migrated.

## Non-changes

- no effective coordinate is derived from movement content;
- no time field is added to `CapacityMovement`;
- no generic transaction or authority framework is introduced;
- Entitlement and windowed Capacity projections are unchanged;
- stable Capacity movement identities and their namespace are unchanged.

## Qualification obligations

- fresh normalized publication creates no legacy sidecar;
- refused writes leave the normalized primary bytes unchanged;
- legacy complete pairs remain readable during migration;
- first post-legacy write preserves identity allocation and emits normalized primary;
- normalized reads ignore stale or removed legacy sidecars;
- existing Capacity publisher, review, selected observations, and compression CI remain green.
