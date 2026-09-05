# Application 021: Scratch manifest Movement publisher

Status: **QUALIFIED** by the dedicated Lean runtime probe and exact-source measurement.

## Pressure

Applications 016-020 narrowed the production-size question from generic source
compression to one concrete hypothesis:

```text
keep semantic fact families separate
prepare changed family images off-authority
select the coherent generation with one atomic manifest replacement
```

Application 020 qualified that topology with TLA+ and public filesystem fixtures.
It did **not** establish that a production implementation would actually be
smaller than current Event-last publication.

Application 021 therefore asks the deliberately practical question:

> If one already-admitted Movement is published through the generation-manifest
> boundary, does the physical publication code become visibly smaller without
> hiding the five typed family images or rewriting an unchanged family?

This application is stacked on Application 020 / PR #389. No production source,
canonical path, persistence format, household data, or executable behavior is
changed.

## Scope of comparison

The current production `MovementCli` does much more than physical publication:
interactive input, world re-read, identity allocation, Core admission, relation
and discharge frontier checks, preview, publication, and failure reporting.

The scratch publisher therefore does **not** pretend to replace the whole module.
It isolates the boundary Application 019 identified:

```text
already-admitted updated family images
-> physical publication
```

The scratch candidate uses the existing production codecs for:

- EventMemory;
- ActualValidityHistory;
- EventDescriptionMemory;
- RelationUnit stream;
- RelationDischarge stream.

The public fixture must decode and re-encode exactly through those codecs before
publication. Full domain admission is intentionally still owned by the existing
Core/Application layers.

## Scratch physical shape

Family images are stored as content-addressed, write-once objects:

```text
objects/event/<sha256>.loam
objects/actual-validity/<sha256>.loam
objects/event-description/<sha256>.loam
objects/relation-unit/<sha256>.loam
objects/relation-discharge/<sha256>.loam
objects/actual-routing/<sha256>.loam
```

Each new object is first written to a sibling staging path and renamed into its
content-addressed object path. The object remains outside canonical authority
until selected by `CURRENT`.

`CURRENT` is a tiny versioned manifest with one typed row per family:

```text
LOAM-GENERATION-MANIFEST<TAB>1
Event<TAB>...<TAB>sha256
ActualValidity<TAB>...<TAB>sha256
EventDescription<TAB>...<TAB>sha256
RelationUnit<TAB>...<TAB>sha256
RelationDischarge<TAB>...<TAB>sha256
ActualRouting<TAB>...<TAB>sha256
```

A Movement-like publication prepares exactly the first five references, retains
the current ActualRouting reference unchanged, and atomically replaces only
`CURRENT`.

## Why content-addressed objects

The object filename is derived from physical bytes, not EventId or RelationUnitId.
This keeps interrupted object preparation from reserving a semantic identity.

If an object with the same digest already exists, the probe requires its bytes to
match exactly and reuses it. Otherwise the new object is staged beside its final
object path and renamed before manifest publication.

This does not solve concurrent stale writers. A production version would still
retain the existing `WriterOwnership` scope while observing current authority,
admitting the candidate, and selecting the new manifest.

## Qualified runtime result

The exact-head workflow succeeded after one same-day entry-point correction. The
runtime probe produced:

```text
Application 021 manifest Movement probe PASS
changed_family_objects=5
authority_switches=1
unchanged_routing_rewrites=0
```

It therefore exercised one five-family Movement-like publication through the
current production codecs, one manifest authority switch, reuse of unchanged
ActualRouting bytes, digest-checked reads of every selected family, and retention
of the old immutable objects.

## Exact-source measurement

The same successful workflow measured these source boundaries:

```text
current publishDraftUnderOwnership     132 lines   8501 bytes
current physical-publication tail       58 lines   3949 bytes
scratch publishAdmittedMovement          20 lines    767 bytes
scratch manifest infrastructure         141 lines   5352 bytes
```

The current writer contains five cross-family save calls. The scratch publisher
still prepares five changed family objects, but it has one manifest authority
switch.

The narrow publication function is therefore materially smaller:

```text
20 / 58 lines  = 0.345
767 / 3949 B   = 0.194
```

So, at the already-admitted physical-publication boundary, the manifest shape
reduces writer-specific publication code by roughly two thirds in lines and four
fifths in bytes in this scratch specimen.

## The honest counterweight

The shared manifest infrastructure is not free.

For a single Movement probe:

```text
scratch publisher + manifest infrastructure
= 161 lines / 6119 bytes
```

That is **more lines** than the current 132-line whole
`publishDraftUnderOwnership` boundary, although still fewer raw bytes than its
8501-byte source body. This is not an apples-to-apples whole-writer victory: the
current boundary also contains world reload, identity allocation, admission, and
frontier checks that the scratch manifest infrastructure does not replace.

So Application 021 does **not** claim that one Movement alone earns a production
migration.

What it establishes is narrower and useful:

```text
writer-specific physical publication gets much smaller
but the shared selector/object layer must amortize across more than one writer
before net production simplicity can be claimed
```

## Decision boundary

Production adoption now needs aggregate evidence across the writers that share
this same physical problem. The next measurement should reuse the exact same
manifest infrastructure for at least Movement, Scheduled completion, Event
Correction, Capacity publication, and QuantityBasis correction, then compare:

- aggregate writer-specific publication code removed;
- shared manifest/object code added once;
- recovery branches removed or retained;
- semantic identity reservation that remains necessary;
- reader indirection and garbage-collection cost.

Do not multiply the 141-line infrastructure by writer count. Do not count domain
admission code as publication savings. The question is whether one shared
physical primitive replaces several independent publication protocols.

## Smallness criterion

Application 021 treats smallness as a constrained optimization rather than a
style preference:

```text
same retained meaning
same fail-closed safety
same inspectability
same required capability
with fewer independent mechanisms / branches / bytes
```

If removing code requires hiding semantic distinctions or weakening recovery,
that is not compression. If the same distinctions survive while one physical
mechanism replaces several writer-specific protocols, then smallness is positive
evidence.
