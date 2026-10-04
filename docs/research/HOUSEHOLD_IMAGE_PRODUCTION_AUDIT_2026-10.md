
# HouseholdImage production consolidation audit — 2026-10

Status: **production-shape audit only — do not migrate loam-data yet**

Baseline:

~~~text
main: b89728faf2ff5d5e21a2d58a94ed333f26754073
HouseholdImage H1-H4: passing
~~~

## Decision question

The research sequence has now established:

- H1: one coherent non-empty thirteen-family household can live in one image;
- H1.5: named unknown sections can survive old readers/writers unchanged;
- H2: selected production Review answers are storage-topology equivalent;
- H3: whole-image physical rewrite is not the measured scale wall;
- H4: one-generation staged publication can fail closed with explicit previous-generation recovery.

The remaining question is therefore no longer whether one file is plausible.

It is:

> If production adopts one logical Household authority, does the resulting code
> become materially smaller and easier to audit without changing current
> missing-storage meaning or the thirteen semantic families?

This audit inspects the current production mechanics and defines a migration
shape. It does not change production persistence and does not inspect or mutate
private loam-data.

## What must remain

Physical consolidation is **not** semantic consolidation.

Keep the existing domain/application meanings and codecs for:

1. Actual
2. Scheduled lifecycle
3. Capacity
4. Attention
5. Actual routing
6. Scheduled routing
7. AccountingRole
8. Locus admission
9. Zero-origin coverage
10. Opening support
11. Current quantity anchor
12. Current quantity presence
13. Bounded historical support

Also keep configuration outside the candidate HouseholdImage:

~~~text
config/
  boundary-presets.tsv
  measure-presentation.tsv
  locus-catalog.tsv
  purpose-catalog.tsv
  balance-view.tsv
  cycle-funding.tsv
  daily-pace.tsv
  scheduled-coverage.tsv
~~~

The intended simplification is only:

~~~text
many physical authority files
many writer scopes
many path/load/save adapters

        ↓

one Household generation
one writer ownership scope
one stage/replace/recovery protocol
existing semantic codecs and proposal laws
~~~

## Measured current mechanics surface

Repository search at the baseline found:

~~~text
HouseholdPaths references:
  52 indexed files total
  42 production Loam/ files excluding tests

WriterOwnership references:
  46 indexed files total
  18 production Loam/ files excluding tests
~~~

Not every hit disappears: configuration authorities and export/CLI locks remain
separate where they are not part of the thirteen-family HouseholdImage.
Nevertheless, canonical household storage topology is spread broadly through
the read/write surface today.

### Direct per-family persistence I/O

The semantic codecs should remain, but direct filesystem save/load wrappers are
duplicated in the current persistence modules.

Approximate raw function spans observed in the current files:

| Persistence module | direct path/save/load span |
| --- | ---: |
| ScheduledLifecyclePersistence | ~35 lines excluding semantic helpers |
| AttentionPersistence | 18 |
| ActualRoutingPersistence | 17 |
| ScheduledRoutingPersistence | 17 |
| AccountingRolePersistence | 16 |
| LocusAdmissionPersistence | 17 |
| ZeroOriginCoveragePersistence | 17 |
| OpeningSupportPersistence | 15 |
| CurrentQuantityAnchorPersistence | 17 |
| CurrentQuantityPresencePersistence | 16 |
| BoundedHistorySupportPersistence | 16 |

That is roughly **200 lines of direct per-family filesystem I/O** before counting
ActualAuthority, CapacityAuthority, path selection, writer ownership, publisher
reloads, or Review-side path fan-out.

NormalizedActualPersistence and NormalizedCapacityPersistence are already
primarily semantic/wire codecs and should not be collapsed merely to save lines.

### Authority wrappers

Current physical authority wrappers include:

~~~text
ActualAuthority                 170 LOC
CapacityAuthority                74 LOC
LocusAdmissionAuthority          70 LOC
ScheduledActualOwnership         34 LOC
HouseholdPaths                   97 LOC
~~~

Most of those files contain useful compatibility or semantic API surface, so the
whole files are not deletion candidates.

But the physical mechanics they currently repeat or expose become one central
Household authority concern:

- canonical file path selection;
- required/missing file checks;
- filesystem read;
- section decode;
- sibling stage path;
- staged readback;
- final rename;
- per-file writer ownership;
- fixed cross-file ownership ordering.

In particular, ScheduledActualOwnership is a topology adapter whose reason for
existence disappears if Scheduled and Actual are sections of the same generation.

### Publisher pressure

The largest simplification opportunity is not the codec layer. It is publishers
that reconstruct one household world by loading and locking several physical
authorities.

Selected current files:

| Publisher | LOC | visible ownership calls | load/save-style references |
| --- | ---: | ---: | ---: |
| AttentionPublisher | 132 | 2 | 7 |
| ActualRoutingPublisher | 96 | 1 | 5 |
| ScheduledRoutingPublisher | 123 | 1 | 4 |
| AccountingRolePublisher | 160 | 3 | 10 |
| CapacityPublisher | 341 | 2 | 3 |
| BoundedHistorySupportPublisher | 129 | 2 | 11 |
| CurrentQuantityAnchorPublisher | 300 | 3 | 24 |
| ScheduledCreationPublisher | 121 | 1 | 6 |
| ScheduledTerminalPublisher | 258 | 2 | 10 |
| ScheduledReplacementPublisher | 147 | 1 | 6 |

These counts are indicators, not automatic deletion counts.

The important examples are structural:

~~~text
AccountingRole publication
  Scheduled ownership
    -> Actual ownership
      -> Anchor ownership
        -> Role ownership

CurrentQuantityAnchor publication
  Actual ownership
    -> Anchor ownership
      -> Presence ownership
        -> BoundedHistory ownership
~~~

A HouseholdImage does not eliminate the semantic checks behind those operations.
It eliminates the need to coordinate their physical file identities and lock
ordering.

### Review pressure

HouseholdPaths is also embedded in many Review loaders. Selected Review modules
currently reopen several files to reconstruct one answer, including:

- CurrentBalanceReview;
- RoleBalanceReview;
- CurrentCoverageReview;
- AccountingRoleReview;
- ActualRoutingReview;
- HistoricalBalanceReview;
- BudgetWindowReview;
- LocusTrendReview and related reporting.

H2 already showed that the pure Review answers do not need to change.

The production direction should therefore be:

~~~text
HouseholdAuthority.loadGeneration
        ↓
already-admitted section views
        ↓
existing project / inspect functions
~~~

not:

~~~text
Review A opens household.loam
Review B opens household.loam
Review C opens household.loam
...
~~~

One loaded generation should be reusable by composed reads.

## Important production gap found by this audit: missing is not empty

The research fixtures intentionally contained all thirteen sections.

Production cannot assume that.

Current readers encode several different absence contracts.

Examples observed in production:

| Family / boundary | Current absence meaning |
| --- | --- |
| Actual | required; missing is an error |
| Scheduled lifecycle | required by Scheduled readers; missing is an error |
| Attention Review | missing = **unavailable**, distinct from available-empty |
| Capacity practical view | missing = empty retained Capacity |
| CurrentCoverage Capacity | required for that composed answer |
| Actual routing Review | required; missing is an error |
| AccountingRole Review | required; missing is an error |
| Locus admission | required; missing is an error |
| Zero-origin coverage | missing = empty coverage |
| Opening support | missing = empty support |
| Current quantity anchor | missing = empty evidence |
| Current quantity presence | missing = empty evidence |
| Bounded historical support | missing = empty evidence |

Some write boundaries can also create a family from previously absent storage
while read boundaries deliberately distinguish that absence.

Therefore a production HouseholdImage must **preserve physical presence**, not
normalize every missing legacy file to a canonical empty document.

### Production rule

The outer image remains a named-section collection.

Migration copies a section **only when the legacy canonical file exists**.

Thus:

~~~text
legacy file absent
    ==
HouseholdImage named section absent
~~~

The outer container itself does not decide whether absence means empty,
unavailable, or error.

That decision stays with the existing semantic boundary.

A production typed view should therefore not reuse the research-only
knownSections? rule that requires all thirteen sections.

Conceptually:

~~~text
HouseholdGeneration
  rawImage
  actual?
  scheduled?
  capacity?
  attention?
  ...
~~~

Each consumer then applies its existing absence contract.

This is required before real data migration.

## Candidate production modules

Do not create a generic Authority framework.

Two concrete modules are enough initially.

### 1. HouseholdImagePersistence

Own only:

- outer version and named-section framing;
- duplicate-name refusal;
- unknown-section preservation;
- exact payload replacement;
- section-presence preservation;
- outer encode/decode.

Inner semantic codecs stay where they are.

### 2. HouseholdAuthority

Own only:

- household.loam;
- household.loam.prev;
- one writer ownership scope;
- current generation load;
- explicit previous-generation recovery;
- staged candidate publication;
- stale observed-generation rejection;
- preservation proof/check for unchanged section bytes;
- changed-section admission through the existing codec/law.

No generic Authority-of-T, repository abstraction, schema framework, or generic
transaction layer is earned by this work.

## Expected code effect

A precise net LOC result cannot be known until the production adapter is
implemented because central code must replace deleted mechanics.

The audit supports the following bounded expectation.

### Directly removable/simplifiable surface

- about 200 lines of duplicated per-family persistence filesystem wrappers;
- the 34-line ScheduledActualOwnership topology helper;
- most canonical-file path definitions for the thirteen families;
- significant load/lock/save scaffolding in multi-authority publishers;
- repeated Review-side canonical path fan-out;
- root-to-individual-file plumbing in HouseholdCommand.

### New central surface required

A production-quality outer codec, authority boundary, selective staged
publication, previous-generation recovery, and one-time migration path will add
new code.

So the useful target is not a heroic line-count promise.

A reasonable **net** success criterion for the first production consolidation is:

~~~text
at least ~500 LOC net removed
and
fewer physical ownership/recovery paths
and
no new generic framework
~~~

If implementation cannot achieve that, the consolidation should be reconsidered
even though H1-H4 passed.

A stronger reduction near 800-1,000 net LOC is plausible from the inspected
surface, but is not claimed before a real diff exists.

## Migration design

Migration should be one-time, explicit, and initially reversible.

### M0 — Git checkpoint

Before migration:

~~~text
loam-data clean
commit current canonical data
push private remote backup
~~~

Git owns long-term history. HouseholdAuthority owns only current plus previous.

LOAM should not invent a second long-retention backup system.

### M1 — quiescent legacy snapshot

The migration command must not simply read thirteen files one after another while
old writers are active.

It must either:

1. run in an explicit maintenance/quiescent mode; or
2. acquire a legacy lock set whose order extends every existing multi-lock
   ordering before reading the files.

The second option is mechanically possible but adds one-time compatibility
complexity. For this personal/local-first migration, a deliberately offline
migration is the smaller candidate unless an executable concurrency test shows a
need for more.

### M2 — preserve presence exactly

For each of the thirteen legacy canonical paths:

~~~text
if file exists:
  read exact bytes
  run existing decoder
  require canonical re-encode equality where that codec promises it
  add named HouseholdImage section

if file absent:
  add no section
~~~

Never manufacture an empty document merely to make the new container look full.

Unknown future sections are irrelevant during initial migration but the new
format must continue to preserve them thereafter.

### M3 — qualify the candidate

Before authority switch:

- encode one HouseholdImage candidate;
- stage it off-authority;
- decode the outer image;
- decode every **present** known section with its production decoder;
- materialize the present sections into a temporary legacy-shaped directory;
- run the H2 Review-equivalence suite against the original legacy directory;
- refuse migration on any mismatch.

This turns H2 into the actual migration admission gate.

### M4 — atomic install, no legacy mutation

Only after M3 passes:

~~~text
household.loam.stage
      ↓ atomic rename
household.loam
~~~

The original thirteen files remain byte-for-byte untouched during this first
cutover checkpoint.

If installation is interrupted before rename, legacy production remains
authoritative and unchanged.

### M5 — binary cutover

The production binary begins selecting HouseholdImage only after a valid
household.loam exists and has passed the migration contract.

Do **not** dual-write HouseholdImage and thirteen legacy authorities. Dual-write
would recreate the split-publication problem the consolidation is meant to
remove.

During the first dogfood period, the old files may remain as a frozen rollback
snapshot. They are no longer authority once HouseholdImage writes begin.

Downgrading to an old binary after the first HouseholdImage write is therefore
unsupported without restoring the pre-migration Git state.

### M6 — retire legacy physical files

After several real operating cycles and explicit comparison:

- remove the frozen legacy canonical files from the active data directory;
- rely on Git history for long-term recovery;
- retain only household.loam and household.loam.prev as LOAM-managed household
  authority generations;
- keep config/*.tsv separate.

The old data remains recoverable from Git and does not need an in-product archive
hierarchy.

## Suggested implementation order

Do not migrate real data in the first production PR.

Use small reversible steps:

1. promote the outer codec from experiment to production, adding exact
   section-presence semantics;
2. add HouseholdAuthority and qualification tests;
3. refactor one low-risk family such as Attention to publish through a
   HouseholdGeneration while preserving all other bytes;
4. refactor composed readers to reuse one loaded generation;
5. migrate the remaining publishers, deleting obsolete per-file locks/load/save
   wrappers as each family moves;
6. add an offline dry-run migration command that creates and verifies a candidate
   but does not switch authority;
7. run that dry-run against a copy/fixture, not private live data;
8. only then perform the real loam-data migration.

## Audit decision

**Proceed with production implementation, but do not migrate real canonical data
yet.**

H1-H4 removed the major semantic, compatibility, performance, and failure-mode
objections.

This audit found one remaining correctness gate that matters before real data:

> section absence must be preserved exactly through migration.

That is small enough to solve without weakening the one-file design.

The next production checkpoint should therefore be **P1: promote the
HouseholdImage outer codec with presence-preserving semantics and no change to
current authority selection**.

If P1 remains small and the later real diff meets the ~500 net-LOC reduction
criterion, proceed toward migration. If centralization grows into a generic
framework or fails to reduce the mechanics surface, stop and retain the current
layout.
