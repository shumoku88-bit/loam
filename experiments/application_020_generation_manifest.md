# Application 020: Generation-manifest publication boundary

Status: **QUALIFICATION PENDING**. This application is a scratch protocol/model and
filesystem fixture only. It changes no production persistence or household data.

## Pressure

Application 019 found a real temporal distinction:

```text
per-fact durable publication
    -> partial authority-store residue remains

complete off-authority bundle
    -> one authority transition
    -> partial work stays outside authority
```

But that result did not yet identify a filesystem primitive LOAM could actually
use without flattening its fact families or rewriting every family for every
small change.

The next question is therefore:

> What is the smallest realizable indirection that can select several already
> complete typed family images in one authority transition while leaving
> unchanged family images physically untouched?

This application is stacked on Application 019 at:

```text
6f7ac80039500948656578a3030b71275026dd6e
```

The production snapshot under observation remains `main` at:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

## Existing facts that constrain the experiment

This is not the first LOAM observation about atomic publication.

### Current production already stages each individual stream

`Loam.Persistence.saveEventMemory?` writes a complete encoded EventMemory to a
sibling `.loam-stage` path and then renames it over the EventMemory target.
EventCorrection and the newer family persistence modules use the same basic
per-target shape.

That gives one atomic replacement boundary **per family path** where the
filesystem rename has replacement atomicity. The persistence comments explicitly
do not claim a cross-stream transaction.

So Application 020 is not looking for a better way to atomically replace one
file. LOAM already has that primitive.

### Writer ownership already exists

`Loam.WriterOwnership.withOwnership` supplies one OS-managed exclusive writer
scope anchored at the canonical EventMemory path. Application 020 does not try to
replace that concurrency boundary. Any future manifest publication would still
need ownership spanning:

```text
read current authority
-> prepare candidate
-> admit candidate
-> publish new authority selector
```

Without ownership, two writers could still prepare from one old selector and let
a later stale selector lose the earlier completed update.

### Observation 060 did not require a manifest for crash safety

Observation 060 already showed that relation-first split publication plus
Event-first acquisition can remain safe across explicit retry. It deliberately
concluded that a generation/manifest selector should **not** be added merely for
crash safety.

Application 020 does not overturn that result. The new pressure is different:
production code-size work in Applications 016-019 found that explicit
cross-stream publication/recovery protocol is now the largest practical source
cost. A manifest is being observed as a possible *protocol-compression* boundary,
not as a newly discovered requirement for semantic safety.

### Observation 157 exposed a locality tradeoff

Observation 157 compared direct authority partitions and found a structural
competition:

```text
one whole Actual authority
    -> one authority transition
    -> broad rewrite scope

one authority per family
    -> strict single-family rewrite locality
    -> no one-transition whole-Actual publication without coordination above it
```

The final phrase matters. Application 020 deliberately tests that previously
unmodeled coordination-above-sidecars case rather than contradicting the Alloy
result.

## Candidate primitive: one manifest selects immutable family images

The scratch topology is:

```text
objects/
  Event/v17.loam
  ActualValidity/v12.loam
  EventDescription/v9.loam
  RelationUnit/v4.loam
  RelationDischarge/v3.loam
  ActualRouting/v6.loam

CURRENT
```

`CURRENT` is a tiny versioned manifest. For every family it records:

```text
family
relative object path
digest
```

The referenced family images are write-once at this abstraction. `CURRENT` is the
only mutable authority selector.

A reader does:

```text
read CURRENT exactly once
-> validate the manifest
-> read exactly the family-image paths named by that manifest
-> validate their digests
-> perform ordinary typed decode/admission
```

If `CURRENT` changes while the reader is loading those paths, the already-read
manifest remains a stable snapshot because its referenced objects are not
mutated in place.

## Multi-family publication

For a maximum-fan-out Movement-like change, a future writer shape could be:

```text
hold WriterOwnership
-> read CURRENT
-> prepare new Event image off-authority
-> prepare new ActualValidity image off-authority
-> prepare new EventDescription image off-authority
-> prepare new RelationUnit image off-authority
-> prepare new RelationDischarge image off-authority
-> validate the complete candidate view
-> write CURRENT.loam-stage with all five new refs
   plus unchanged refs such as ActualRouting
-> atomically replace CURRENT
```

The order in which the five object files are constructed no longer has reader
visibility meaning because none is selected until the manifest switch.

This does **not** remove Event as a semantic fact or relation activation concept.
It only tests whether physical partial-object order can stop being an authority
protocol.

## Single-family locality

For an ActualRouting-only change, the candidate shape is smaller:

```text
prepare one new ActualRouting image
-> next CURRENT keeps every other old reference
-> atomically replace CURRENT
```

Only the routing object bytes are rewritten. The manifest is rewritten because it
is the selector, but Event, validity, description, relation, and discharge object
images remain physically unchanged and continue to be referenced.

This is the important distinction from a complete unified snapshot. Manifest
indirection can potentially combine:

```text
one authority selection step
+
changed-family-only object rewriting
```

at the cost of introducing one new operational authority layer.

## Interruption and orphan residue

Before the selector changes, an interrupted writer may leave:

- a partial unreferenced family object;
- several complete unreferenced family objects;
- a complete but unpublished candidate set;
- a partial `CURRENT.loam-stage` file.

None is canonical merely because it exists. Readers discover family images only
through the currently published manifest.

This gives orphan residue a simpler operational meaning than current raw
cross-stream residue:

```text
unreferenced object
    !=
selected authority
```

A later production design would still need object-name collision rules and a
cleanup policy. Application 020 does not infer garbage-collection authority from
file age or naming.

## Append-only provenance boundary

The fixture keeps every previously published family image byte-identical after a
later manifest switch. New versions use fresh paths; old images are not replaced.

That gives a useful physical provenance shape:

```text
family images: write-once / retained
CURRENT: moving operational selector
```

This is not yet a complete provenance design. In particular, the current
manifest itself is replaced, and this application does not decide whether old
manifests, publication receipts, or a manifest history must also be retained.
Canonical append-only correction semantics remain inside the typed family images.

## TLA+ model

`application_020_generation_manifest.tla` keeps six family names:

```text
Event
Validity
Description
Relation
Discharge
Routing
```

A manifest maps each family to either its old or new immutable image.

Two positive configurations are checked.

### Movement-like multi-family update

Changed families are:

```text
Event
Validity
Description
Relation
Discharge
```

Routing remains old.

The model permits family preparation one by one, crash/restart during preparation,
reader acquisition before or after publication, and one atomic manifest switch.

Expected invariants:

- only changed families are prepared;
- authority manifest is always exactly old or complete candidate;
- completed readers observe only old or complete candidate manifests;
- unchanged family references stay old;
- published state selects the complete candidate.

### Routing-only update

Only Routing is prepared as new. Every other family reference remains old even
after the new manifest is published.

This is the model-level locality witness that coordination above sidecars need not
rewrite every family image.

### Non-vacuity boundaries

Dedicated negative configurations require the following states to be reachable:

- partial off-authority preparation;
- crash with prepared off-authority residue;
- completed manifest publication;
- routing-only publication without all families having been prepared.

## Filesystem fixture

`tests/application_020_generation_manifest.py` exercises the same shape with
ordinary files.

It first publishes one old manifest, then performs a routing-only update where
only one family object path changes.

Next it starts concurrent readers, gradually writes five new Movement-family
objects while the old manifest remains authoritative, and finally replaces a
staged manifest using `os.replace`.

Every reader reconstructs its view from one manifest read plus the immutable
objects named by that manifest. The fixture requires every observation to equal
either the complete old selected view or the complete new selected view.

It also requires:

- partial unreferenced objects do not change authority;
- complete unreferenced objects do not change authority;
- routing-only publication changes exactly one family object reference;
- Movement publication changes exactly five family object references and leaves
  the routing version untouched;
- old published object bytes remain unchanged after later publication;
- both complete reader generations are actually observed.

The runtime fixture is run on both Ubuntu and macOS GitHub runners. As with
Observation 155, this tests process-concurrent visibility on those filesystems;
it does not claim power-loss durability or directory-entry fsync guarantees.

## What this could compress if production evidence later supports it

A manifest selector has one potentially important consequence for the source-size
pressure that motivated this line.

Current writers must make partially published sibling facts semantically inert and
resumable. That drives operation-specific logic for:

- publication order;
- which fact activates the operation;
- interrupted raw residue recognition;
- retry reuse;
- identity reservation against residue that physically sits on canonical paths.

With explicit manifest selection, unselected object versions are not discovered
by canonical readers. That may allow some physical-publication recovery logic to
collapse into one generic operational rule:

```text
prepare complete candidate objects
-> validate candidate
-> switch selector once
```

But **may** is the boundary. Application 020 does not delete any of those checks
or claim a source reduction. A scratch Lean writer must demonstrate actual code
deletion before a production migration is earned.

## Costs introduced by the candidate

The primitive is not free. A production version would add at least:

- a versioned manifest format and parser;
- one operational authority path;
- fresh/write-once object naming;
- digest validation or another immutability check;
- reader indirection through the manifest;
- migration from current direct canonical paths;
- orphan-object cleanup policy;
- compatibility decisions for direct inspection/export tooling;
- a decision about retaining old manifest generations or receipts.

Therefore a successful fixture proves **realizability**, not net simplicity.

## Explicit limits

Application 020 does not model or implement:

- a production manifest parser or writer;
- a production object store;
- garbage collection;
- content-addressed naming;
- hard links or symlinks;
- power-loss durability;
- directory fsync;
- two concurrent writers beyond reusing the existing ownership requirement;
- stale-manifest compare-and-swap without ownership;
- torn-object recovery;
- malicious path mutation;
- full correction graphs inside the scratch TLA+ state;
- private household data;
- a canonical migration.

## Decision rule

If qualification succeeds, the earned statement is deliberately narrow:

> A small versioned manifest can act as one realizable atomic selector over
> separately stored write-once typed family images, while unchanged family images
> remain physically untouched.

That is stronger than Application 019's abstract atomic-bundle transition and
different from a one-file unified Actual image.

It still does not earn production adoption. The next useful test would be a
scratch Lean Movement publisher using the existing typed encoders behind this
manifest boundary, followed by a direct source/protocol comparison with the
current Movement writer. Only then can LOAM ask whether the new indirection
actually makes the product smaller rather than merely moving complexity.
