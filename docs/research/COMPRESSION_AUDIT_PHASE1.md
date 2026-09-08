# Compression audit Phase 1 — production surface

Status: **IN PROGRESS**

Current main baseline after the Scheduled lifecycle authority cut: `5d3c136b6e9fe119e2d0e2d1ba9365eb4b03812a`.

Phase 1 answers a deliberately narrow question: what source surface participates in the current practical implementation before any semantic judgment is made about whether that surface is necessary?

The repeatable inventory command is:

```sh
bash tools/audit-production-surface
```

The `Compression Audit` workflow runs the same command in CI. Its output is the evidence for the physical line/file inventory.

## First reproduced physical inventory

The first successful CI inventory against the PR merge with current main reported:

| Surface | Lines | Files |
| --- | ---: | ---: |
| Core | 4,171 | 38 |
| Application | 2,876 | 20 |
| Persistence | 2,313 | 20 |
| writer/top-level candidates | 2,004 | 9 |
| other top-level Lean requiring classification | 2,521 | 19 |
| CLI | 4,419 | 22 |
| TUI | 4,753 | 23 |
| Tests | 6,296 | 48 |
| Historical observations | 8,117 | 42 |
| practical subtotal before reachability filtering | **23,057** | **151** |

This materially supports the original concern that the practical implementation is not obviously small even after tests and historical observation proofs are excluded.

It also corrects the earlier ~25.3k / 156-file audit input for the current main snapshot. The two inventories are not directly interchangeable because the original grouping used a broader writer/top-level and CLI classification and, critically, main changed during the audit: PR #533 merged the complete Scheduled lifecycle authority cut. That commit itself removed substantially more code than it added and explicitly retired legacy Scheduled mutation CLI writers and standalone sidecar authority APIs.

Therefore the audit records both facts rather than choosing the more dramatic number:

```text
pre-#533 review input       ~25.3k / 156 practical files
post-#533 reproducible scan 23,057 / 151 candidate practical files
```

The reduction is evidence that destructive compression is real and can materially shrink production surface. It does not yet establish that the remaining surface is minimal.

## Current executable roots

`lakefile.lean` currently exposes 15 executable targets:

- `loam`
- `loamMovement`
- `loamCapacity`
- `loamActualRouting`
- `loamScheduledRouting`
- `loamBudgetWindow`
- `loamDailyQuantity`
- `loamOpenScheduled`
- `loamScheduledSuppression`
- `loamJournalExport`
- `loamShadowAudit`
- `loamShadowQuantity`
- `loamShadowDay`
- `loamShadowScheduledDay`
- `loamTui`

Executable count is itself an audit input. A target may remain useful for qualification without being part of ordinary household operation, so Phase 1 must distinguish operational entrances from diagnostic, migration, shadow, and historical entrances.

## Reachability is the next required filter

This phase is not complete until each candidate practical module is classified for reachability from a current executable or explicit practical library entrance. Presence in `Loam/` alone is insufficient.

The next mechanical output must distinguish at least:

- reachable from current executable roots;
- reachable from practical library entrances but not an executable;
- present/buildable but unreachable from either current practical entrance;
- test/observation-only reachability.

## Required outputs

- corrected/reproduced line and file counts by layer — **physical inventory complete**;
- current executable roots — **enumerated, role classification pending**;
- production-reachable module set — **pending**;
- present-but-not-production-reachable module set — **pending**;
- explicit treatment of top-level writer/authority modules — **pending**;
- no semantic deletion decision yet.

## Exit rule

Only after the physical surface and reachability map are reproducible may Phase 2 count independently retained meanings.
