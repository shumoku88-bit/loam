# HouseholdImage remaining production cutover route — 2026-10

Status: **routing checkpoint only — no loam-data mutation**

Baseline:

```text
main: 87952f139425cfc1d570d1f93879a733f0f01adf
production HouseholdImage families:
  Attention
  Capacity
  LocusAdmission
  ScheduledRouting
  ActualRouting
  ZeroOrigin
```

## Why this checkpoint exists

The first six production cutovers established a repeatable storage-topology pattern,
but continuing with one identical two-PR ritual per semantic family would create
avoidable work.

The remaining seven families are not seven equally independent units.

They form five practical cutover stages:

```text
1. OpeningSupport
2. Current-support cluster
     CurrentQuantityAnchor
     CurrentQuantityPresence
     BoundedHistorySupport
3. Scheduled lifecycle
4. AccountingRole
5. Actual
```

The goal is to minimize the period in which one semantic operation must coordinate
both standalone files and HouseholdImage.

This checkpoint does not authorize real-data migration or legacy-file deletion.

## Current evidence

The production source surface at this baseline shows materially different
topologies.

| Family / stage | Current production shape | Migration cost | Mechanical payoff | Dependency pressure |
| --- | --- | ---: | ---: | ---: |
| OpeningSupport | read-only in production selection; optional readers use missing=empty, CurrentQuantityAnchor guard uses missing=error | low | modest | low |
| Current-support cluster | CurrentQuantityAnchorPublisher coordinates Actual + Anchor + Presence + BoundedHistory; BoundedHistorySupportPublisher coordinates Actual + Anchor + BoundedHistory | medium-high | very high | medium |
| Scheduled lifecycle | three publishers write lifecycle; many readers select scheduled.loam; terminal operations coordinate Scheduled + Actual | high | very high | high |
| AccountingRole | publisher coordinates Scheduled + Actual + Anchor + Role; many Reviews load role evidence directly | medium-high | high | very high before prior stages |
| Actual | central authority used across many publishers, reviews, CLI/TUI and exports | very high | highest | highest |

### Measured writer pressure

Current production publisher sizes and visible ownership calls:

| Publisher | LOC | ownership calls |
| --- | ---: | ---: |
| CurrentQuantityAnchorPublisher | 296 | 4 |
| BoundedHistorySupportPublisher | 129 | 3 |
| AccountingRolePublisher | 160 | 3 |
| ScheduledCreationPublisher | 121 | 1 |
| ScheduledReplacementPublisher | 147 | 1 |
| ScheduledTerminalPublisher | 258 | 2 |

The Scheduled lifecycle publisher surface above totals about **526 LOC** before its
persistence module and read-side consumers.

Actual remains substantially broader. Current search finds, excluding tests and
migration-only code:

```text
ActualAuthority.loadActual?   18 production files
ActualAuthority.loadImage?     6 production files
ActualAuthority.publishActual? 10 production files
```

This makes Actual a poor next cutover despite its eventual payoff.

## Stage 1 — OpeningSupport

**Do next.**

Why:

- no ordinary production writer was found;
- CurrentBalanceReview and HistoricalBalanceReview interpret absence as empty;
- CurrentQuantityAnchorPublisher requires explicit OpeningSupport and interprets
  absence as unavailable/error;
- this is the same kind of read-boundary asymmetry already qualified for
  ZeroOrigin, without adding a writer migration.

Preferred shape:

1. add one narrow OpeningSupport authority adapter with
   `loadHouseholdOrEmpty?` and `loadHouseholdRequired?`;
2. cut production readers/guard to HouseholdImage in the same PR if the adapter
   remains trivial;
3. leave explicit legacy/migration entrances available;
4. qualify stale valid `opening-support.loam` as frozen and ignored by
   production.

Do **not** force an adapter-only PR merely to repeat earlier ceremony. The family
has no production write path to qualify separately.

## Stage 2 — current-support cluster

Treat these as one migration unit:

```text
CurrentQuantityAnchor
CurrentQuantityPresence
BoundedHistorySupport
```

Why not migrate Presence alone:

- CurrentQuantityPresence is read by CurrentBalanceReview;
- its only production write is inside CurrentQuantityAnchorPublisher;
- moving only Presence would make one logical exact-anchor publication span
  HouseholdImage plus a legacy Anchor file.

Why not migrate BoundedHistorySupport alone:

- BoundedHistorySupportPublisher currently locks Actual + Anchor + BoundedHistory;
- CurrentQuantityAnchorPublisher also reads BoundedHistory while coordinating
  Anchor + Presence;
- moving only BoundedHistory would preserve most cross-authority topology while
  adding a HouseholdImage boundary.

The cluster is where consolidation should begin paying back mechanically.

CurrentQuantityAnchorPublisher currently has the visible topology:

```text
Actual ownership
  -> Anchor ownership
    -> Presence ownership
      -> BoundedHistory ownership
```

After this stage the target topology is approximately:

```text
Actual ownership
  -> Household ownership
       Anchor
       Presence
       BoundedHistory
       OpeningSupport read
       ZeroOrigin read
```

The semantic proposal laws remain separate. Only the physical ownership and
generation mechanics collapse.

This stage should earn a meaningful reduction. If it instead creates a large
generic transaction framework, stop and reassess.

## Stage 3 — Scheduled lifecycle

Move the `Scheduled` section only after the current-support cluster.

Current Scheduled publication is spread over:

- ScheduledCreationPublisher;
- ScheduledReplacementPublisher;
- ScheduledTerminalPublisher.

ScheduledTerminalPublisher also coordinates Actual through
`ScheduledActualOwnership`.

During this stage Actual may remain standalone, so one temporary cross-boundary
ownership relation is acceptable:

```text
Actual ownership
  -> Household ownership
       Scheduled
       already-cut-over sections
```

Do not invent dual-write between `scheduled.loam` and HouseholdImage.

Once Scheduled is authoritative in HouseholdImage, later AccountingRole
publication can observe Scheduled, Anchor and Role from one Household generation
instead of three physical authorities.

## Stage 4 — AccountingRole

AccountingRole should move **after** both the current-support cluster and
Scheduled lifecycle.

Its current publisher reads:

- Actual;
- Scheduled lifecycle;
- CurrentQuantityAnchor;
- LocusAdmission;
- AccountingRole.

Its current write topology includes Scheduled/Actual ownership plus Anchor and
Role locks.

Migrating it earlier would merely replace one of those files with a Household
lock while retaining the rest.

Migrating it after stages 2 and 3 lets one Household generation carry:

```text
Scheduled
CurrentQuantityAnchor
LocusAdmission
AccountingRole
```

with Actual as the only remaining external household authority.

This is the point where role-aware Reviews should also stop reopening the
standalone `accounting-role.loam`.

## Stage 5 — Actual

Move Actual last.

This is deliberate, not avoidance.

Actual is the widest and most operationally sensitive authority. It participates
in recording, correction, reversal, settlement, merchant classification,
exchange/original-amount publication, TUI reads, exports and many Reviews.

By moving it last:

- all secondary semantic families are already Household sections;
- Scheduled/Actual cross-file ownership can collapse inside one generation;
- `ScheduledActualOwnership` can become a deletion candidate;
- multi-family publishers no longer need to preserve compatibility with several
  standalone sibling authorities at once.

The final target is not a generic database abstraction. It is still the existing
semantic codecs and proposal laws behind one concrete Household generation.

## Revised migration strategy

Do not count remaining work as seven family migrations.

Count it as five checkpoints:

```text
P7  OpeningSupport
P8  Current-support cluster
P9  Scheduled lifecycle
P10 AccountingRole
P11 Actual
```

For P8-P11, use an adapter/qualification PR only when the writer topology is
materially new or dangerous. Read-only or mechanically trivial boundaries may
qualify and cut over in one small PR.

Every production cutover still requires:

- no production legacy fallback;
- no dual-write;
- stale valid legacy evidence may disagree and must be ignored;
- malformed present Household sections fail closed;
- existing missing-storage semantics remain boundary-specific;
- unknown Household sections survive unchanged;
- stale-generation refusal and `.prev` behavior remain intact;
- no `loam-data` mutation.

## Stop conditions

Pause consolidation if any stage requires one of the following merely to make
the migration work:

1. a generic Authority framework;
2. a generic transaction/repository abstraction;
3. weakening an existing fail-closed boundary;
4. production dual-write;
5. silently treating all missing sections as empty;
6. substantially more coordination code than the standalone topology being
   removed.

The expected payoff is back-loaded.

OpeningSupport is intentionally small. The first major simplification should
appear in P8 when three current-support physical authorities collapse into one
Household ownership scope. P9-P11 should then remove increasingly large pieces of
cross-file lock and path plumbing.

## Decision

**Continue HouseholdImage consolidation, but stop migrating one family at a time.**

Next production task:

> P7 — cut over OpeningSupport production selection to the HouseholdImage
> `OpeningSupport` section, preserving optional-empty versus required-error
> absence semantics.

If P7 remains small, proceed immediately to design P8 as one current-support
cluster rather than three independent migrations.
