# Application 020: Generation-manifest publication boundary

Status: **QUALIFIED** by bounded TLA+ / TLC exploration and public filesystem
fixtures on both Ubuntu and macOS. No production persistence or household data
changes here.

## Pressure

Application 019 found that LOAM's largest practical writer paths spend substantial
source on cross-stream publication, interruption residue, retry, and identity
reservation. Its TLA+ comparison also found that:

```text
several files -> one typed file
```

is not temporal compression by itself when facts are still durably published one
at a time. Only complete off-authority preparation followed by one authority
transition removed partial authority-store prefixes in that model.

The next question is therefore concrete:

> Can LOAM realize one atomic selector over several separately stored typed fact
> families without physically rewriting every unchanged family?

This application is stacked on Application 019. The production source inspected
remains `main` at:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

## Existing boundaries

### Individual stream replacement already exists

Current persistence already writes complete family images to sibling
`.loam-stage` paths and then renames them over their targets. For example,
`saveEventMemory?` explicitly says its rename is one-file atomic publication,
not a cross-stream transaction.

Application 020 therefore does not invent atomic replacement of one file.

### Writer ownership already exists

`Loam.WriterOwnership.withOwnership` gives one OS-managed cross-process writer
scope. A future manifest writer would still need ownership spanning:

```text
read authority selector
-> prepare candidate
-> admit candidate
-> publish selector
```

Manifest indirection does not solve stale concurrent writers by itself.

### Observation 060 remains valid

Observation 060 already showed that relation-first split publication plus
Event-first acquisition can remain safe through explicit retry. It concluded
that a generation/manifest selector was not required merely for crash safety.

Application 020 does not reverse that result. The new pressure is whether a
selector can make the *production protocol smaller* now that cross-stream
recovery dominates practical source size.

### Observation 157 left this topology open

Observation 157 found a structural tradeoff for direct authority partitions:

```text
one whole authority
    -> one authority transition
    -> broad rewrite scope

one authority per family
    -> strict family rewrite locality
    -> no whole-view one-transition publication without coordination above it
```

Application 020 tests exactly that previously excluded `coordination above
sidecars` case.

## Candidate primitive

The scratch physical shape is:

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

`CURRENT` is a small versioned manifest. Each row names:

```text
family
relative object path
digest
```

Family images are write-once at this abstraction. `CURRENT` is the only mutable
operational selector.

A reader performs:

```text
read CURRENT once
-> validate manifest
-> read exactly the referenced family images
-> validate digests
-> perform ordinary typed decode/admission
```

If `CURRENT` changes while those images are being loaded, the reader still holds
one stable manifest snapshot and follows only write-once paths from that snapshot.

The manifest is operational publication metadata, not a household domain fact.

## Multi-family publication

For a maximum-fan-out Movement-like update, the modeled changed families are:

```text
Event
ActualValidity
EventDescription
RelationUnit
RelationDischarge
```

while ActualRouting remains unchanged.

A candidate writer shape is:

```text
hold WriterOwnership
-> read CURRENT
-> prepare new changed-family images off-authority
-> validate the complete candidate view
-> stage next CURRENT with new refs for changed families
   and old refs for unchanged families
-> atomically replace CURRENT
```

The order in which off-authority objects are constructed has no reader-visibility
meaning. Partial objects are not discovered by canonical readers because the
published manifest does not reference them.

This does not remove Event, Relation, or Discharge semantics. It only moves the
physical activation boundary above their storage paths.

## Single-family locality

The routing-only model prepares only a new ActualRouting image:

```text
old Event ref             -> old Event ref
old Validity ref          -> old Validity ref
old Description ref       -> old Description ref
old Relation ref          -> old Relation ref
old Discharge ref         -> old Discharge ref
old Routing ref           -> new Routing ref
```

Only one family image is physically rewritten. The manifest itself changes
because it is the selector.

This produces a topology not represented by Observation 157's direct partition
model:

```text
one authority selection step
+
changed-family-only object rewriting
```

The price is one new indirection layer.

## TLA+ model

`application_020_generation_manifest.tla` keeps six families distinct:

```text
Event
Validity
Description
Relation
Discharge
Routing
```

The manifest maps each family to an old or new write-once image. Family images may
be prepared one at a time off-authority. One crash may occur during preparation;
prepared objects survive restart. Readers capture the manifest before completing
their read.

Two positive configurations qualified:

1. Movement-like five-family change;
2. Routing-only one-family change.

The checked invariants require:

- only changed families are prepared;
- authority manifest is always exactly old or complete candidate;
- completed readers observe only old or complete candidate manifests;
- unchanged references remain old;
- published state selects the complete candidate manifest.

All passed.

Dedicated expected-counterexample checks also qualified and prove non-vacuity:

- partial off-authority preparation is reachable;
- crash with prepared off-authority residue is reachable;
- completed manifest publication is reachable;
- routing-only publication is reachable without preparing every family.

So the model does not obtain safety by forbidding interruption, publication, or
single-family locality.

## Filesystem fixture

`tests/application_020_generation_manifest.py` exercises the same shape with
ordinary files.

It first creates one old selected generation, then performs a routing-only update
where exactly one family object reference changes.

It then starts concurrent readers, gradually writes five new Movement-family
objects while the old manifest remains authoritative, and finally replaces a
staged manifest with `os.replace`.

Every reader reconstructs its view from one manifest read plus the family objects
named by that manifest.

The fixture requires:

- readers see only one complete old or one complete new selected view;
- both complete generations are actually observed;
- mixed views are never observed;
- a partial unreferenced object has no authority effect;
- a complete unreferenced object has no authority effect;
- routing-only publication changes exactly one family reference;
- Movement publication changes exactly five family references and leaves routing
  untouched;
- previously published object bytes remain unchanged after later selector moves.

The exact-head workflow passed on both `ubuntu-latest` and `macos-latest`.
The TLA+ protocol job and every intended positive/negative boundary also passed.

As with Observation 155, this is a process-concurrency filesystem qualification,
not a power-loss or directory-fsync guarantee.

## Finding

The qualified result is:

> One small atomically replaced manifest can select several separately stored
> write-once typed family images as one coherent authority view while unchanged
> family images remain physically untouched.

That is stronger than Application 019's abstract atomic-bundle transition and
different from a unified one-file Actual snapshot.

The important new shape is:

```text
immutable/versioned family images
        +
one mutable generation selector
        =
atomic multi-family selection with family-byte locality
```

## Why this could matter for production size

Current multi-stream writers must reason about partially published sibling facts
that physically occupy canonical family paths. That drives operation-specific
logic for publication order, inert residue, retry recognition, and identity
reservation against interrupted residue.

Under manifest selection, unreferenced object versions are not canonical merely
because they exist. This could allow physical recovery to collapse toward:

```text
prepare complete candidate objects
-> validate candidate
-> switch selector once
```

But **could** is the boundary. Application 020 does not prove any current writer
checks removable and does not claim a net LOC reduction.

## Costs introduced

A production version would add at least:

- a versioned manifest parser and writer;
- one new operational authority path;
- fresh/write-once object naming;
- digest validation or another immutability discipline;
- reader indirection through the manifest;
- migration from current direct canonical paths;
- orphan-object cleanup policy;
- compatibility rules for direct inspection/export tools;
- a decision about retaining old manifests or publication receipts.

The manifest selector may therefore be architecturally cleaner but still lose the
code-size contest. Realizability is not net simplicity.

## Explicit limits

Application 020 does not introduce or decide:

- production manifest or object-store code;
- garbage collection;
- content-addressed naming;
- symlinks or hard links;
- power-loss durability or directory fsync;
- a new concurrent-writer protocol;
- stale-manifest CAS without ownership;
- torn-object recovery;
- malicious path mutation;
- full correction graphs inside the TLA+ model;
- private household data;
- canonical migration.

The write-once object discipline is a protocol assumption in this experiment,
with digest validation in the runtime fixture. A production design would have to
make that boundary explicit and fail closed when it is violated.

## Smallest earned follow-up

Do **not** migrate production storage yet.

The next useful experiment is a scratch Lean Movement publisher that reuses the
existing typed encoders but publishes through this manifest boundary. Compare it
directly with current `MovementCli` for:

```text
publication steps
recovery branches
identity-reservation branches
source size
reader complexity
failure messages
```

Only if the scratch writer demonstrably deletes more protocol than the manifest
layer adds has a production persistence change been earned.
