# Application 021: Scratch manifest Movement publisher

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

## Qualification

The dedicated workflow performs two checks.

### 1. Lean runtime probe

The probe:

1. creates an initial six-family manifest;
2. verifies a five-family Movement fixture round-trips through production codecs;
3. prepares five new immutable family images;
4. publishes one new `CURRENT` manifest;
5. confirms the reader selects exactly that manifest;
6. confirms the unchanged ActualRouting reference and bytes are reused;
7. digest-checks every selected family image;
8. confirms older immutable objects remain present.

Expected receipt:

```text
Application 021 manifest Movement probe PASS
changed_family_objects=5
authority_switches=1
unchanged_routing_rewrites=0
```

### 2. Source-boundary measurement

A small source measurement reports, without forcing a preferred answer:

- current `publishDraftUnderOwnership` lines/bytes;
- the current physical-publication tail beginning at
  `saveActualValidityHistory?`;
- scratch `publishAdmittedMovement` lines/bytes;
- scratch manifest infrastructure lines/bytes;
- current cross-family save-call count;
- scratch changed-object preparation count;
- scratch manifest authority-switch count.

The measurement deliberately reports both the tiny per-Movement publisher and
the manifest infrastructure it depends on. A prototype is not allowed to claim
victory by hiding infrastructure outside the measured function.

## Decision boundary

A smaller per-Movement publisher is useful but insufficient by itself.

Production adoption would need evidence that, across the writers which share the
same physical problem, the manifest layer removes more code and recovery state
than it adds in:

- manifest codec and reader indirection;
- object naming and digest checks;
- garbage collection of unreachable objects;
- migration and compatibility;
- writer ownership and stale-writer checks.

Conversely, a prototype that is not smaller for one Movement is not automatically
a failure. Shared infrastructure may amortize across Movement, Scheduled,
Correction, Capacity, and QuantityBasis publication. That must be measured rather
than assumed.

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
