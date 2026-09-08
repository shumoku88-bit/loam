# Compression audit Phase 1 — production surface

Status: **IN PROGRESS**

Phase 1 answers a deliberately narrow question: what source surface participates in the current practical implementation before any semantic judgment is made about whether that surface is necessary?

The repeatable inventory command is:

```sh
bash tools/audit-production-surface
```

The `Compression Audit` workflow runs the same command in CI. Its output is the evidence for the physical line/file inventory.

This phase is not complete until each candidate practical module is also classified for reachability from a current executable or library entrance. Presence in `Loam/` alone is insufficient.

## Required outputs

- corrected/reproduced line and file counts by layer;
- current executable roots;
- production-reachable module set;
- present-but-not-production-reachable module set;
- explicit treatment of top-level writer/authority modules;
- no semantic deletion decision yet.

## Exit rule

Only after the physical surface and reachability map are reproducible may Phase 2 count independently retained meanings.
