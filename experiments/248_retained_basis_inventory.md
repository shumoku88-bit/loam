# Experiment 248: retained basis inventory

Status: **inventory for #700; classification pressure only**

This inventory separates semantic information from configuration and publication mechanics before any attempt to count canonical state.

## Retained semantic candidates

| Candidate information | Current physical shape | Read pressure | Write pressure | Safety pressure | Current status |
| --- | --- | --- | --- | --- | --- |
| Event signed effects | Movement Event object | yes | yes | publication | KEEP information |
| Actual validity/correction frontier | Movement ActualValidity + correction semantics | yes | yes | publication | KEEP information |
| Event description | Movement EventDescription | yes | limited | publication | KEEP information |
| Locus admission | Movement LocusAdmission | routing administration | yes | publication | KEEP information; representation open |
| Relation unit | selected empty Movement family | no current Q_read | yes | publication | mutation-only pressure; representation open |
| Relation discharge | selected empty Movement family | no current Q_read | yes | publication | mutation-only pressure; representation open |
| Actual reversal | root explicit empty memory | no current Q_read | yes | publication/retry | mutation-only pressure; representation open |
| Accounting role | direct `accounting-role.loam` partial relation | yes | administration | direct-file integrity | KEEP information |
| Zero-origin coverage | five-coordinate direct file | yes | limited | decode/fail-closed | KEEP information; dependency/minimality open |
| Scheduled occurrence | one Scheduled lifecycle image | yes | yes | atomic image publication | KEEP information |
| Scheduled terminal meaning | completion/retirement/replacement sections | yes | yes | atomic image publication | KEEP meaning; candidate one terminal relation |
| Scheduled routing | direct routing memory | yes | yes | publication | KEEP information |
| Actual routing | direct routing memory | yes | yes | publication | KEEP information |
| Capacity movement | one sidecar | yes | yes | publication | KEEP information |
| Capacity effective coordinate | companion sidecar | yes | yes | publication | KEEP information; split topology challenged by #699 |
| Attention item/closure | LOAM retained semantics, not currently present in this loam-data root snapshot | yes when source exists | yes | source/publication | semantic candidate, data presence separate |

## Replaceable configuration, not household fact basis

These values affect answers because they choose questions or views, but they do not describe immutable household reality and should not inflate the canonical-fact count:

| Configuration | Meaning |
| --- | --- |
| `config/balance-view.tsv` | selected balance coordinates for presentation |
| `config/cycle-funding.tsv` | selected backing coordinates for cycle-budget queries |
| `config/boundary-presets.tsv` | named report/query windows |
| `config/locus-catalog.tsv` | human-readable vocabulary/catalog presentation |
| `config/purpose-catalog.tsv` | human-readable Purpose presentation/catalog |

These may be persisted, but they belong to a replaceable policy/query/config basis rather than append-only household evidence.

## Publication / transport / replay mechanics, not semantic household facts

Current examples include:

- Movement `CURRENT` selection;
- content-addressed object names and object-store layout;
- recovery manifests;
- request directories and request payloads;
- applied request-id ledgers;
- writer-lock and staged-replacement artifacts.

They may be required by `Q_safe` even though they do not add household meaning. Count their safety obligations separately from retained semantic information.

## Why this changes the notion of "how much canonical data"

The useful measurements are now at least four-dimensional:

```text
S = number of independently retained semantic distinctions
C = independently replaceable configuration distinctions
A = semantic authority/publication units
P = physical persisted artifacts in the current tree
```

A design can reduce `P` without reducing `S`, or reduce `S` while leaving `P` temporarily unchanged. Conversely, merging files can reduce `P` while making authority and crash semantics worse.

Therefore no future cleanup should report only "files removed" or "types removed". A semantic compression claim should identify which of `S`, `C`, `A`, or `P` changed and which observable answers were preserved.

## Current highest-value questions

1. Can the known-empty/absent/nonempty mutation-state knowledge needed by Q_write be represented more compactly than three separate persisted families?
2. Is the five-coordinate ZeroOriginCoverage set independently observed, or exactly derivable from another retained coordinate universe?
3. Can Observation 244 remove three independently threaded Scheduled memory types while keeping one terminal meaning relation?
4. Does #699 justify reducing Capacity physical artifacts from two mutable images to one while keeping two semantic dimensions?
5. Can read projections depend only on the read basis, leaving mutation-only evidence behind a write-admission boundary?

This inventory is deliberately not a migration plan. Each reduction still needs a witness or equivalence argument.