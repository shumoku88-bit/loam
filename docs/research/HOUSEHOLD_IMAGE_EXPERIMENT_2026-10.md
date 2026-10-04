# Household image experiment — 2026-10

Status: **historical research checkpoint — experiment retired after HouseholdImage production cutover**

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

This was an exploratory checkpoint. Production later adopted HouseholdImage; the isolated experiment code has now been retired while this research record is preserved.

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

**Executable benchmark added on the follow-up branch.**

H3 does not repeat the old SQLite / Actual encoder benchmark. E3.3 already
established that normalized Actual encoding is near-linear after the production
encoder repair. The HouseholdImage question is narrower:

> If only Attention changes, what extra cost comes from carrying a large,
> unchanged Actual payload inside the same physical file?

The benchmark uses synthetic canonical Actual histories at:

~~~text
1,000 Events
10,000 Events
100,000 Events
~~~

Fixture generation and initial canonical qualification happen outside the timed
publication windows.

Four costs are measured separately, each averaged over three runs after warmup:

~~~text
split_publish
  current Attention-only sibling-stage publication

whole_publish
  replace only the Attention payload
  encode the complete outer HouseholdImage
  sibling-stage the complete image

selective_reopen
  read the complete HouseholdImage
  decode outer framing
  require exact intended generation
  decode only the changed Attention section

full_reopen
  read the complete HouseholdImage
  decode outer framing
  re-admit all thirteen known semantic sections
~~~

The distinction between the last two paths is intentional. Whole-image storage
does not logically require re-decoding a large unchanged Actual on every small
publication if the writer starts from an already-admitted generation and proves
unchanged payload preservation. Full re-admission is therefore measured as a
conservative upper bound rather than silently baked into the design.

The benchmark also reports complete HouseholdImage character count and the tiny
Attention payload character count so write amplification is explicit.

Interpretation rule:

- if `whole_publish` itself becomes operationally expensive at household-like
  scale, the single-image design is weakened;
- if only `full_reopen` is expensive while selective reopen remains small,
  the next question is whether unchanged-section preservation can be made a
  qualified production invariant;
- the 100,000-Event case is adversarial for household use and should not be
  treated as a normal expected history size.


#### H3 CI result

Representative GitHub Actions measurements from the first passing H3 run:

| Events | HouseholdImage chars | split Attention publish | whole-image publish | selective reopen | full semantic reopen |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 75,713 | 0.241 ms | 0.288 ms | 1.615 ms | 6.281 ms |
| 10,000 | 750,714 | 0.222 ms | 0.578 ms | 14.117 ms | 63.447 ms |
| 100,000 | 7,590,715 | 0.234 ms | 5.286 ms | 140.677 ms | 955.486 ms |

The Attention payload itself is only 126 characters in all three cases.

Absolute timings are runner-specific. The scale shape and decomposition are the
useful evidence.

The result separates three different effects that would otherwise be easy to
conflate:

1. **Physical whole-image rewrite is cheap in this experiment.** At the
   adversarial 100,000-Event scale, replacing Attention and sibling-staging the
   roughly 7.6-million-character image averaged about 5.3 ms.
2. **Reading and parsing the whole outer image is visible but still modest at
   ordinary scales.** Selective reopen was about 14 ms at 10,000 Events and
   about 141 ms at 100,000 Events.
3. **Re-decoding every unchanged semantic family is the expensive choice.**
   Conservative full reopen reached about 955 ms at 100,000 Events, compared
   with about 141 ms when unchanged section bytes were preserved and only the
   changed Attention payload was semantically decoded.

A conservative staged publication that combines whole-image rewrite with the
selective verification path would therefore be roughly the sum of those two
measured components on this runner:

~~~text
1,000 Events    ~1.9 ms
10,000 Events  ~14.7 ms
100,000 Events ~146.0 ms
~~~

This is not yet a production crash protocol, and simple addition of separately
timed components is not a latency guarantee. It is sufficient to falsify the
strong version of the write-amplification concern for this fixture: copying the
large unchanged Actual payload is not the measured bottleneck.

The result instead makes one future production invariant important:

> A writer starting from an already-admitted HouseholdImage generation should
> be able to prove all untouched section payloads were preserved exactly and
> re-admit only the section whose semantics changed.

If that invariant cannot be qualified safely, the full-reopen numbers become
the relevant upper bound. H4 must therefore test the selective staged-validation
story under interruption, malformed section, stale writer, and recovery rather
than assuming it.

### H4 — failure boundary

**Executable failure-boundary experiment added on the follow-up branch.**

The candidate publication protocol is intentionally narrow:

~~~text
observe admitted current bytes A
acquire one HouseholdImage writer ownership
re-read current
require current bytes == A
change exactly one semantic section
prove every other known and unknown section byte-identical
admit the changed section
stage complete candidate B
typed re-read of staged B

stage current A as previous candidate
validate previous candidate
rename previous candidate -> household.loam.prev

rename staged B -> household.loam
~~~

The final rename is the only current-generation switch. If interruption occurs
before it, `household.loam` still names the old complete generation.

H4 exercises:

- partial/corrupt candidate stage;
- complete candidate stage before final rename;
- interruption after the previous-generation switch but before current switch;
- successful selective Attention publication;
- stale writer rejection after ownership and re-read;
- malformed changed-section rejection without mutation;
- malformed outer current image with explicit previous-generation fallback;
- valid outer framing containing malformed inner semantic evidence;
- explicit restoration from the qualified previous generation;
- partial migration from the existing thirteen-file topology.

Recovery does not silently relabel previous evidence as current. The recovery
reader returns whether the usable image came from `current` or `previous`,
and restoration is a separate explicit operation.

The migration checkpoint keeps the existing split authorities untouched while
the HouseholdImage candidate is staged. A partial migration stage therefore
does not change existing Review answers or create a current HouseholdImage.
Only a complete typed image is atomically installed.

This is still a research protocol, not a durability guarantee. In particular,
the experiment tests malformed framing and malformed inner semantic evidence;
it does not yet add a cryptographic checksum or claim detection of an arbitrary
bit mutation that accidentally remains a different valid LOAM document.


#### H4 CI result

The first complete H4 GitHub Actions run passed every exercised failure shape:

~~~text
[ok] partial stage left current generation intact
[ok] complete pre-rename stage left current generation intact
[ok] previous switch before final rename still left old current intact
[ok] final rename installed B and retained A as previous
[ok] stale observed generation was refused without mutation
[ok] malformed changed section failed closed
[ok] malformed current fell back explicitly to previous and restored
[ok] outer-valid but inner-malformed current fell back to previous
[ok] partial migration remained inert and preserved split Review answers
~~~

The important architectural result is that the candidate does not need a
multi-file transaction log to preserve one complete household generation during
the tested interruption points.

The selected ordering is:

~~~text
current = A
stage B completely
qualify B completely

stage/certify A as previous
rename previous-stage -> previous

current is still A here

rename B-stage -> current

current = B
previous = A
~~~

An interruption before the final rename leaves A as current. An interruption
after the final rename leaves B as current and A as previous.

Stale-writer protection also collapses to one identity boundary: the writer
holds one household lock, re-reads the current complete image, and requires the
bytes to equal the admitted generation it originally observed. A writer based
on A cannot silently replace B.

The larger corruption blast radius remains real, but the tested recovery
contract is sharper than silent best-effort fallback:

~~~text
current valid
  -> return current

current invalid + previous valid
  -> return source = previous explicitly

current invalid + previous invalid/missing
  -> fail closed
~~~

Restoring previous is a separate explicit mutation under writer ownership.

For migration, a partially written HouseholdImage stage does not affect the
existing thirteen-file authority or its Review answers. This supports a future
migration design in which split authority remains authoritative until a complete
HouseholdImage has been constructed and explicitly selected.

### H4 limitation discovered rather than hidden

The format still has no independent integrity digest. Therefore H4 demonstrates
detection of malformed outer framing and malformed inner semantic documents,
but not arbitrary storage mutation that happens to produce a different,
fully-valid LOAM document.

That limitation also exists for the current plain-text authorities unless an
external integrity mechanism is used. A production HouseholdImage decision
should therefore treat per-generation or per-section integrity metadata as a
separate durability feature, not pretend semantic decoding is a checksum.

## Decision rule

Promote the idea beyond research only if all of the following become true:

1. existing semantic types and admission laws remain separate;
2. Review answers are unchanged;
3. one-generation publication materially removes production mechanics;
4. realistic publication cost remains negligible;
5. migration and recovery fail closed without inventing household facts;
6. the resulting codebase is measurably smaller and easier to audit.

Until then, the current production authority layout remains unchanged.

## Production-shape follow-up

After H1-H4 passed, the concrete production consolidation and migration surface
was audited in:

~~~text
docs/research/HOUSEHOLD_IMAGE_PRODUCTION_AUDIT_2026-10.md
~~~

That audit identifies one additional pre-migration correctness requirement:
legacy section presence/absence must be preserved exactly rather than
normalizing every missing file to an empty section.
