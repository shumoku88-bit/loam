# Experiment 248: retained basis inventory

Status: **inventory for #700; classification pressure only**

This inventory separates household meaning, operational policy, replaceable configuration, and publication mechanics before any attempt to count canonical state.

## Working household semantic basis

The current audit has **15 household semantic distinctions** worth retaining or continuing to challenge as information, after applying two already-qualified/reasoned classification changes:

- Scheduled Completion / Retirement / Replacement are counted as one `ScheduledTerminal` relation candidate after Observation 244 rather than three independently threaded memory concepts;
- `LocusAdmissionVocabulary` is not counted as household fact/evidence here because its own Core contract calls it current new-write policy. Its meaning remains required, but it is counted separately below.

The 15 are:

```text
1  Event signed effects
2  ActualValidity
3  EventDescription
4  RelationUnit
5  RelationDischarge
6  EventCorrection
7  ActualReversal
8  AccountingRole
9  ZeroOriginCoverage
10 ActualRouting
11 ScheduledOccurrence
12 ScheduledTerminal
13 ScheduledRouting
14 CapacityMovement
15 CapacityEffective
```

This is a **working semantic count**, not a claim that 15 files or 15 authorities are ideal. Some distinctions are mutation-only, some are currently empty, and some may eventually share one representation.

### Current evidence table

| Candidate information | Current physical shape | Read pressure | Write pressure | Safety pressure | Current status |
| --- | --- | --- | --- | --- | --- |
| Event signed effects | Movement Event object | yes | yes | publication | KEEP information |
| ActualValidity | Movement ActualValidity | yes | yes | publication | KEEP information |
| EventDescription | Movement EventDescription | yes | limited | publication | KEEP information |
| RelationUnit | selected empty Movement family | no current Q_read | yes | publication | mutation-only information; representation open |
| RelationDischarge | selected empty Movement family | no current Q_read | yes | publication | mutation-only information; representation open |
| EventCorrection | currently absent/known-empty read path | yes | yes | publication | meaning retained; storage-presence semantics open |
| ActualReversal | explicit empty root memory | no current Q_read | yes | publication/retry | known-empty vs unavailable retained; dedicated file not automatically earned |
| AccountingRole | direct `accounting-role.loam` partial relation | yes | administration | direct-file integrity | KEEP information |
| ZeroOriginCoverage | five-coordinate direct file | yes | limited | decode/fail-closed | KEEP information; current set not derived from obvious retained sets |
| ScheduledOccurrence | one Scheduled lifecycle image | yes | yes | atomic image publication | KEEP information |
| ScheduledTerminal | completion/retirement/replacement sections | yes | yes | atomic image publication | KEEP meaning; one-relation recompression qualified by Observation 244 |
| ScheduledRouting | direct routing memory | yes | yes | publication | KEEP information; subject is `ScheduledId × LocusId` |
| ActualRouting | direct routing memory | yes | yes | publication | KEEP information |
| CapacityMovement | one sidecar | yes | yes | publication | KEEP information |
| CapacityEffective | companion sidecar | yes | yes | publication | KEEP information; split topology challenged by #699 |

Attention item/closure remain LOAM semantics but are not present as current `loam-data` household state in this snapshot, so they are not included in the present 15-state count.

## Operational policy kept separately

### LocusAdmissionVocabulary

`LocusAdmissionVocabulary` answers a write-policy question:

> may this existing Locus identity appear in a new quantity-bearing canonical write?

Observation 212 established that historical usage does not determine this answer. The policy itself therefore remains independently required.

But its own Core and Movement admission contracts explicitly identify it as **current new-write policy**, not Event history or display metadata. Counting it as another household fact obscures the audit.

Current classification:

```text
KEEP POLICY MEANING
CHALLENGE CURRENT AUTHORITY PLACEMENT
```

It is currently the sixth Movement manifest family. Because the production administration operation is add-only, a later audit should test whether monotone policy can have a separate authority without weakening Movement admission or crash/concurrency safety. Do not split it merely for aesthetic layering.

## Replaceable configuration, not household fact basis

These values affect answers because they choose questions or views, but they do not describe immutable household reality and should not inflate the household-semantic count:

| Configuration | Meaning |
| --- | --- |
| `config/balance-view.tsv` | selected balance coordinates for presentation |
| `config/cycle-funding.tsv` | selected backing coordinates for cycle-budget queries |
| `config/boundary-presets.tsv` | named report/query windows |
| `config/locus-catalog.tsv` | human-readable vocabulary/catalog presentation |
| `config/purpose-catalog.tsv` | human-readable Purpose presentation/catalog |

These may be persisted, but they belong to a replaceable query/config basis rather than append-only household evidence.

## Publication / transport / replay mechanics, not semantic household facts

Current examples include:

- Movement `CURRENT` selection;
- content-addressed object names and object-store layout;
- recovery manifests;
- request directories and request payloads;
- applied request-id ledgers;
- writer-lock and staged-replacement artifacts.

They may be required by `Q_safe` even though they do not add household meaning. Count their safety obligations separately from retained semantic information.

## Current ZeroOrigin result

The current five-coordinate ZeroOrigin set is:

```text
cash
paypay
smbc
yucho
all-country
```

The obvious candidate dependencies do not determine it:

```text
cycle-funding = cash/paypay/smbc
AccountingRole=ASSET additionally includes point
LocusAdmission is much wider than holdings
```

`balance-view.tsv` happens to select exactly the same five coordinates today, but `BalanceReview` deliberately consumes display selection and coverage independently, and a selected-but-uncovered coordinate is unavailable rather than zero. Therefore equality of today's bytes does not establish a semantic dependency.

Experiment 247 further qualifies that one origin fact alone cannot replace the coordinate set. A smaller representation needs some independently justified source that determines *which* coordinates are complete from that origin.

## Current ScheduledRouting result

All seven current ScheduledRouting rows happen to choose the same Purpose as current ActualRouting for their Loci. This is useful duplication pressure, but not enough for deletion.

The Scheduled routing subject is `ScheduledId × LocusId`, earned because bare Locus identity can merge distinct Scheduled intent. CurrentCoverage also consumes ActualRouting for Actual Consumption and ScheduledRouting for future Commitment as independent inputs.

Therefore:

```text
current row equality != derivability
```

A default-plus-exception representation would change the meaning of absence and needs an explicit policy/equivalence argument before it can reduce retained information.

## Measuring future reductions

The useful measurements are now at least five-dimensional:

```text
H = independently retained household semantic distinctions
W = independently retained operational/write-policy distinctions
C = independently replaceable configuration distinctions
A = semantic authority/publication units
P = physical persisted artifacts in the current tree
```

Current working semantic count:

```text
H = 15
W = 1 identified admission-policy family
C = 5 current config families
```

`A` and `P` remain deliberately uncoupled from those counts and should be measured per topology experiment rather than inferred from H/W/C.

A design can reduce `P` without reducing `H`, or reduce `H` while leaving `P` temporarily unchanged. Conversely, merging files can reduce `P` while making authority and crash semantics worse.

Therefore no future cleanup should report only "files removed" or "types removed". A semantic compression claim should identify which of `H`, `W`, `C`, `A`, or `P` changed and which observable answers were preserved.

## Current highest-value questions

1. Can mutation-only `RelationUnit` / `RelationDischarge` / `ActualReversal` knowledge share a smaller representation without losing their distinct write answers?
2. Can `LocusAdmission` leave the Movement generation because its policy evolves monotonically, while preserving fail-closed new-write admission under crashes and concurrent writers?
3. Can Observation 244 graduate Scheduled terminal recompression into production and remove three independently threaded memory types?
4. Does #699 justify reducing Capacity physical artifacts from two mutable images to one while keeping both semantic dimensions?
5. Is there stronger historical reconstruction evidence that determines exactly the five ZeroOrigin coordinates, rather than merely restating them?

This inventory is deliberately not a migration plan. Each reduction still needs a witness or equivalence argument.