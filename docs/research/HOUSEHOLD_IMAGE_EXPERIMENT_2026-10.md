# Household image experiment — 2026-10

Status: **research checkpoint — no production persistence change authorized**

Baseline:

~~~text
main: dccbb2d9e17c6f5e92d8b6fb3390dbfd9ab2b926
~~~

## Question

LOAM currently keeps operational household authority in several independently
persisted `.loam` documents. Some publishers therefore need to coordinate
multiple paths, ownership scopes, missing-storage contracts, and reloads before
one semantic transition can be admitted.

This experiment asks a deliberately narrower question:

> Can the current canonical authority documents be packaged inside one physical
> household image without merging their semantic types or changing their inner
> wire formats?

This is not yet a proposal to replace production persistence.

## Hypothesis

If one outer image can preserve every current inner document exactly, then a
future production design could potentially reduce cross-file mechanics:

~~~text
many authority paths
+ several writer locks
+ cross-file read snapshots
+ per-file stage / replace
+ split-publication recovery cases

                ↓

one HouseholdImage generation
+ one writer ownership scope
+ one typed outer decode
+ existing inner semantic admission
+ one stage / replace
~~~

The hypothesis is useful only if semantic partitions remain visible after the
physical consolidation.

## Experiment boundary

The first checkpoint intentionally treats all thirteen current authority
documents as opaque text sections:

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

The outer envelope owns only:

- one version marker;
- fixed section identity and order;
- exact character length for each payload;
- fail-closed truncation and unknown-version behavior.

Every inner payload is then re-read through its existing production decoder and
re-encoded through its existing production encoder. The experiment requires the
result to equal the embedded payload exactly.

No generic semantic `Memory`, `Authority`, repository, schema, or transaction
ontology is introduced.

## Why length-prefixed sections

A sentinel-only section grammar would create an unnecessary collision question
with present or future inner text. The research envelope instead records:

~~~text
SECTION<TAB><name><TAB><character-count>
<exact existing canonical payload>
~~~

The next section begins immediately after that exact payload length.

This preserves the current inner text untouched and makes outer framing
independent of inner row tags.

## Initial executable checkpoint

`experiments/household_image/Main.lean` constructs a representative set of
all thirteen documents. Actual contains one balanced Event; Actual routing,
AccountingRole, and Locus admission contain small non-empty examples; the
remaining families use valid canonical empty images.

The executable requires:

~~~text
all 13 existing decoders accept their section
all 13 existing encoders reproduce the same section exactly
encode outer image
decode outer image
decoded sections == original sections
re-run all 13 canonical inner round-trips
truncated outer image is refused
unknown outer version is refused
~~~

This checkpoint tests packaging only. It does not yet claim cross-family
household consistency.

## What this does not prove

A passing checkpoint does **not** establish that production should move to one
file.

It does not yet test:

- equivalence of existing Review answers between ordinary files and the outer image;
- publication latency when a small family changes but Actual is large;
- crash behavior of a complete household publication;
- migration from an existing loam-data directory;
- backup / restore behavior;
- corruption blast radius;
- whether configuration TSV files should remain outside the image;
- whether every current independent missing-storage meaning has an equivalent
  whole-image representation.

Those are later gates.

## Next gates if this checkpoint passes

### H1 — coherent household snapshot

**Executable checkpoint implemented on the follow-up branch.**

The synthetic household now makes all thirteen authority sections non-empty and
ties them together through existing LOAM semantics:

~~~text
Actual:
  opening cash +10000 / opening-offset -10000
  food spend cash -2000 / food +2000

Capacity:
  food-budget entitlement 5000

Scheduled:
  future food pressure 1000

Routing:
  Actual food -> food-budget
  Scheduled food -> food-budget

Current support:
  cash     -> OpeningSupport -> 8000
  food     -> ZeroOriginCoverage -> 2000
  savings  -> CurrentQuantityAnchor -> 3000
  debt     -> CurrentQuantityPresence -> known present, amount unknown

Bounded history:
  savings/jpy from 2026-09-01, admitted through the production publisher law
~~~

The checkpoint does more than decode the files independently. It composes
existing production application laws and requires:

~~~text
Scheduled managed commitment = 1000

Capacity entitlement = 5000
Actual routed consumption = 2000
Remaining = 3000
Headroom = 2000
~~~

It also verifies that every AccountingRole and routing Locus is present in the
LocusAdmission vocabulary, Scheduled routing references a retained Scheduled
occurrence, and current support families remain non-overlapping.

No cross-family rule is added to HouseholdImage itself. The outer envelope still
owns framing only; coherence is demonstrated by existing LOAM application
boundaries.

### H1.5 — extensible named sections

The outer experiment now has a version-2 container contract:

~~~text
LOAM-HOUSEHOLD-IMAGE<TAB>2

SECTION<TAB>Actual<TAB><length>
<opaque payload>

SECTION<TAB>Scheduled<TAB><length>
<opaque payload>

...

SECTION<TAB>Securities<TAB><length>
<opaque payload unknown to this semantic version>
~~~

The physical image is an ordered collection of uniquely named opaque sections.
The thirteen currently understood household families are projected out of that
container only when semantic work is required.

This checkpoint adds a synthetic future `Securities` section that the current
household semantics do not understand. It requires:

~~~text
decode / encode preserves the unknown section exactly

change only Attention
re-encode the whole image
decode again

unknown Securities bytes are unchanged
unknown Securities position is unchanged
all thirteen known sections remain canonically valid
the H1 coherent household answers remain unchanged
~~~

Duplicate section identity is refused. A missing currently required known
section also fails closed rather than being interpreted as empty evidence.

This is the intended forward-extension rule: adding a future authority family
does not require a new outer format version merely because a new section name
exists. The outer version changes only when the framing contract itself changes.

This does not mean arbitrary large artifacts belong in the household image.
Raw media, telemetry, caches, disposable projections, downloaded statements,
and similarly large or independently managed material remain outside the
candidate canonical state unless a later experiment demonstrates a need for
atomic household publication.

### H2 — answer equivalence

**Executable checkpoint implemented on the follow-up branch.**

The experiment compares two physical routes to the same canonical payloads:

~~~text
ordinary directory
  13 canonical files
        ↓
existing production readers

            ==

HouseholdImage V2
  13 known sections + unknown Securities
        ↓
decode outer framing
        ↓
materialize the known opaque payloads unchanged
        ↓
the same existing production readers
~~~

The Review layer is deliberately not modified to understand HouseholdImage.
Only the storage adapter knows how to recover named payloads. Unknown sections
remain outside the readers and are preserved by the outer container.

The checkpoint compares exact answers for:

- admitted Actual evidence and the current Actual frontier;
- CurrentBalanceReview;
- RoleBalanceReview;
- CapacityReview;
- AttentionReview open-item summaries;
- current-open Scheduled occurrence identities;
- ActualRoutingReview;
- AccountingRoleReview initial candidates;
- CurrentCoverageReview, including Capacity, Actual routing, Scheduled pressure,
  roles, and the current window.

The current synthetic fixture therefore checks one of the central promotion
claims directly: existing read semantics can remain unchanged while physical
authority topology changes underneath them.

### H3 — publication cost

Measure complete-image publication with realistic and adversarial Actual sizes.
The current normalized Actual encoder is already near-linear after E3.3, so the
experiment must measure the current implementation rather than reuse the old
pre-linearization result.

### H4 — failure boundary

Compare:

~~~text
current split authorities
vs
one household generation
~~~

under interruption, malformed section, stale writer, and partial migration.

The single-image design wins only if reduced split-publication complexity
outweighs the larger corruption / rewrite blast radius.

## Decision rule

Promote the idea beyond research only if all of the following become true:

1. existing semantic types and admission laws remain separate;
2. Review answers are unchanged;
3. one-generation publication materially removes production mechanics;
4. realistic publication cost remains negligible;
5. migration and recovery fail closed without inventing household facts;
6. the resulting codebase is measurably smaller and easier to audit.

Until then, the current production authority layout remains unchanged.
