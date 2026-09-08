# Compression audit Phase 3 — mechanics multiplication

Status: **COMPLETE — M1–M9 DECIDED**

Phase 2 closed with this current audit basis:

```text
18 retained fact/policy families
~9 physical authority instances
134 executable-reachable practical Lean files
21,226 executable-reachable practical lines
```

Phase 3 asks why the implementation surface is much larger than the retained information basis.

This phase does **not** assume that repeated code is accidental. Different semantic authorities may legitimately need separate codecs, publication protocols, recovery behavior, or failure boundaries. Conversely, giving every fact family a narrowly named helper does not prove those mechanisms are distinct.

## Audit families

### M1 — collection / identity admission

Unique stable identity, List-backed memory, runtime admission, append, lookup, and representation-order independence.

### M2 — text codec admission

Versioned text framing, token syntax, row parsing, trailing-newline admission, typed re-admission, and fail-closed malformed input.

### M3 — stage + rename publication

Sibling staging, complete candidate write, and filesystem replacement.

### M4 — missing-storage semantics

Whether missing storage means empty evidence, unavailable evidence, or authority failure.

### M5 — writer ownership and current-world re-read

Ownership scope, stale-state re-read, semantic admission, publication order, authority commit, and receipt.

### M6 — fresh identity allocation

Runtime `prefix-N` allocation against explicit collision domains.

### M7 — replacement / correction frontier mechanics

Directed supersession mechanics shared across correction/replacement meanings.

### M8 — historical routing mechanics

Latest-visible historical routing shared across different routing subjects.

### M9 — complete-image / multi-family authority

Physical packaging of several semantically distinct fact families under one authority switch.

## Mechanical smoke scan

`tools/audit-mechanics-patterns` scans only executable-reachable practical Lean modules for textual pressure indicators such as:

- `.loam-stage`;
- `IO.FS.rename`;
- `pathExists`;
- `WriterOwnership`;
- Movement selected-world load/prepare/commit calls;
- `OrEmpty?` loaders;
- `fresh...` identity helpers;
- `ReplacementFrontier`;
- `RoutingHistory`;
- `Nodup` collection laws;
- executable-reachable `*Publisher.lean` modules.

The smoke scan found, among other signals:

```text
stage path / .loam-stage     17 matches / 15 files
filesystem rename            18 matches / 15 files
path existence branch        58 matches / 29 files
writer ownership             34 matches / 15 files
manifest current-world load  22 matches / 15 files
or-empty loader              37 matches / 13 files
fresh identity helper       183 textual matches / 16 files
ReplacementFrontier use      13 matches / 4 files
RoutingHistory use           66 matches / 11 files
Nodup collection law         55 matches / 20 files
reachable *Publisher modules  7
```

These counts are pressure indicators, not duplication verdicts.

## M1 decision — `SHARE` narrowly, not as a generic Memory ontology

Several current runtime families use the same representation-level recipe:

```text
List item
+ a projection item -> stable key
+ Nodup over projected keys
+ runtime admission from a raw List
+ lookup by key
+ sometimes append-by-re-admission
```

`EventMemory` and `EventCorrectionMemory` independently carry almost the same recursive lookup plus a substantial proof that lookup is invariant under a permutation when projected keys are unique. `ActualValidityMemory` and capability-only `EventResolutionMemory` repeat the same proof shape as further evidence that the mechanic is representation-level rather than Event-specific.

The narrow reusable boundary already earned by current production is therefore:

```text
find an item in a List by an explicit key projection
prove that result invariant under List permutation when projected keys are Nodup
```

The audit rejects a universal `Memory α` or generic finite-map ontology. Domain laws remain explicit:

- Scheduled completion is unique on both Scheduled and Actual endpoints;
- Scheduled replacement is unique on both source and replacement endpoints;
- Scheduled retirement is unique by Scheduled source without an independent retirement identity;
- ActualValidityHistory owns independent fact and correction identity spaces;
- RoutingHistory is unique by a composite semantic coordinate;
- LocusAdmissionVocabulary and ZeroOriginCoverage are set-like evidence.

### M1 result

**`SHARE`**, only for unique-key list lookup and its permutation-independence mechanics.

Keep semantic memory structures, uniqueness fields, named admission, and append boundaries local. Do not introduce a generic Memory, repository, registry, entity store, or finite-map semantic layer.

## M2 decision — `SHARE` the exact line-image frame, keep codecs semantic

Many current production streams repeat this outer grammar:

```text
<header>\n
<row>\n
<row>\n
...
```

with identical mechanical obligations:

1. exact expected version header;
2. required trailing newline;
3. ordered body rows;
4. malformed outer frame => refusal;
5. domain row parsing and typed re-admission afterward.

Current routing, Capacity-effective, Event-description, Relation-discharge, open-relation, Attention, zero-origin, and other row-oriented codecs independently spell this framing.

A small persistence-level helper equivalent to

```text
encodeVersionedRows(header, rows)
decodeVersionedRows?(expectedHeader, input) -> Option (List String)
```

is justified.

The audit rejects a generic serializer or schema ontology. Domain code must continue to own row tags, field counts, typed interpretation, dates, endpoint encoding, description escaping, ActualValidity V2 normalization, typed re-admission, block/chunk formats, and Scheduled lifecycle sections.

### M2 result

**`SHARE`**, only for exact versioned line framing and trailing-newline admission.

## M3 decision — `SHARE` the sibling replacement primitive, preserve stronger protocols

Fifteen executable-reachable files use the same broad physical pattern:

```text
stage := sibling(target, ".loam-stage")
write complete candidate text to stage
rename stage -> target
```

For ordinary single-image streams the obligation is identical: do not expose a target truncated while a new image is still being written.

A small IO helper may own only this physical primitive, for example:

```text
replaceTextViaSiblingStage(target, text)
```

Stronger protocols stay explicit:

- Scheduled lifecycle reads the staged image back before rename;
- Movement `CURRENT` decodes the staged manifest and compares typed references;
- content-addressed Movement objects verify bytes/digests;
- ActualValidity refuses overwrite of storage not admitted by the current canonical format.

### M3 result

**`SHARE`**, only at the sibling stage/write/rename primitive. It is not a transaction, lock, recovery log, or durability abstraction.

## M4 decision — `SEPARATE`: missing storage has domain meaning

Current production has at least three materially different contracts:

```text
missing -> explicit empty evidence
missing -> evidence source unavailable
missing -> malformed/missing authority and refuse
```

Actual-validity and Capacity-effective have explicit absence-as-empty entrances. Attention review preserves absence as unavailable. Movement manifest treats missing `CURRENT` as authority failure. Scheduled lifecycle does not synthesize an empty configured lifecycle.

### M4 result

**`SEPARATE`**.

Do not normalize these branches through a generic `loadOrEmpty`, `loadOptional`, or configurable `MissingPolicy`. Named entrances should continue to state what absence means.

## M5 decision — `SEPARATE` beyond the already-shared ownership primitive

Cross-process ownership is already factored correctly in `WriterOwnership.withOwnership`: it owns only the OS-level exclusive lock and the manifest-mode ownership guard.

The remaining publisher windows are not one transaction shape.

Examples:

- Movement publication owns only Movement `CURRENT`, re-reads one selected world, admits one Movement draft, and switches one manifest generation.
- ActualValidity publication uses the same Movement ownership anchor but additionally reads EventCorrection evidence and may perform a no-op when the supplied date is already current.
- Correction publication prepares a Movement generation, may publish a separate Correction relation first, then commits `CURRENT`; interrupted relation-first publication is resumable.
- Scheduled creation owns two authorities in a fixed order, `Scheduled lifecycle -> Movement CURRENT`, and writes the lifecycle image rather than Movement authority.
- Scheduled terminal and replacement publishers have lifecycle-specific admission and publication obligations.

A callback-heavy generic write transaction would need parameters for lock sets/order, loaded worlds, no-op behavior, relation-first residue, preparation, commit target, and recovery. That abstraction would be larger and less legible than the current domain publishers.

### M5 result

**`SEPARATE`** beyond `WriterOwnership`.

Keep `WriterOwnership` as the shared physical exclusion primitive. Keep each semantic publisher's re-read/admit/publish protocol explicit. Do not add a general transaction/publisher framework.

## M6 decision — `SHARE` only the opaque candidate enumeration mechanic

Fresh-id helpers are widespread, but they contain two layers:

```text
enumeration mechanic: prefix + increasing Nat -> candidate token
collision policy: which retained namespaces reserve that candidate
```

The first layer is mechanically identical. The second is semantic and intentionally different.

Examples:

- Scheduled creation tests candidate `ScheduledId` only against retained Scheduled identity;
- ActualValidity fact and correction ids have different namespaces/prefixes;
- Movement Event identity is reserved by Event, validity, description, relation, and discharge evidence;
- correction replacement Event identity must also avoid Correction endpoints;
- RelationUnit allocation reserves the operational relation/discharge target namespace.

A small helper may enumerate candidate opaque tokens from a prefix/start/fuel and call a caller-supplied `used?` predicate. Each domain must continue to own that predicate and the typed-id wrapper.

The audit does **not** justify a global identity service, registry, UUID authority, entity allocator, or shared collision database.

### M6 result

**`SHARE`**, narrowly for deterministic candidate enumeration. Collision domains remain explicit at each writer.

## M7 decision — `SHARE`, already substantially achieved by `ReplacementFrontier`

`ReplacementFrontier` is already a small domain-neutral directed-edge kernel containing only:

- source/successor edges;
- endpoint uniqueness;
- reference closure;
- acyclicity;
- superseded-source frontier filtering.

Domain adapters retain their laws:

- ActualValidity adds same-Event preservation and one-current-fact-per-Event;
- Event correction requires referenced Events and its own frontier semantics;
- Scheduled replacement adds completion/retirement compatibility and Scheduled-specific refusal states.

This is the desired compression form: the graph mechanic is shared while the semantic frontier is not collapsed.

### M7 result

**`SHARE`**, and largely **already realized**. Do not expand it into a generic history/revision framework unless a later concrete domain earns another graph law.

## M8 decision — `SHARE`, already achieved by `RoutingHistory`

Actual and Scheduled routing share the same historical selection algebra:

```text
RoutingEntry Subject Time
unique (subject, effectiveOn)
latest visible by Time order
managed / unmanaged / unrouted
```

They retain distinct subject types, wire syntax, physical authority, and application meaning. Scheduled routing specializes the subject to `ScheduledId × LocusId`; Actual routing uses Locus identity with its own effective-coordinate type.

This is the second positive control, alongside ReplacementFrontier, showing that LOAM can share a small mathematical mechanism without inventing a semantic super-object.

### M8 result

**`SHARE`**, and **already realized**. No broader routing registry or authority unification is justified.

## M9 decision — `SEPARATE` beyond the M2/M3 physical helpers

The three prominent multi-family authorities look similar only at a high level.

### Movement manifest

Movement uses content-addressed immutable family objects plus a versioned `CURRENT` manifest. Preparation is off-authority, selected object digests are verified, and one manifest replacement switches several typed family references together. Version-1/2 behavior also carries migration and new-write-policy meaning.

### Scheduled lifecycle

Scheduled occurrence, completion, retirement, and replacement are four semantic families encoded into one complete lifecycle file. The outer section frame delegates to their existing codecs and one stage+rename replaces the whole image. Scheduled routing is intentionally outside the atomic image.

### Attention

Attention item and closure evidence are encoded directly as rows in one complete file. No content-addressed object layer or nested family codec frame is required.

A generic complete-image/authority framework would therefore need to abstract over object stores, manifest pointers, nested codecs, section framing, direct rows, migration versions, and different atomicity sets. The only substantial common pieces are already captured by M2 line framing and M3 physical replacement.

### M9 result

**`SEPARATE`** beyond those smaller shared mechanics.

Do not create a generic authority/image framework. Preserve the physical topology that each atomicity/recovery requirement actually earned.

## Phase 3 decision matrix

| Mechanics family | Decision | Compression boundary |
| --- | --- | --- |
| M1 collection / identity | `SHARE` | unique-key List lookup + permutation theorem only |
| M2 text codec admission | `SHARE` | exact versioned line-image framing only |
| M3 stage + rename | `SHARE` | sibling stage/write/rename primitive only |
| M4 missing storage | `SEPARATE` | absence meaning stays named per authority |
| M5 writer protocol | `SEPARATE` | existing WriterOwnership is enough shared skeleton |
| M6 fresh identity | `SHARE` | candidate token enumeration only; collision policy local |
| M7 replacement frontier | `SHARE` | already realized by ReplacementFrontier |
| M8 historical routing | `SHARE` | already realized by RoutingHistory |
| M9 multi-family authority | `SEPARATE` | commonality already captured by M2/M3 |

## Phase 3 conclusion

The audit does **not** support a large architectural consolidation.

It supports three new narrow subtraction candidates:

```text
A. unique-key List lookup + permutation lemma
B. exact versioned line-image frame
C. sibling text stage + rename
D. deterministic opaque-id candidate enumeration
```

`ReplacementFrontier`, `RoutingHistory`, and `WriterOwnership` are positive evidence that the repository already knows how to factor mechanics at an appropriately small boundary.

The important negative result is equally strong:

```text
NO generic Memory ontology
NO serializer/schema framework
NO missing-storage policy abstraction
NO generic transaction/publisher framework
NO global identity service
NO generic revision/history framework
NO generic authority/image framework
```

So the current compression hypothesis is not "rewrite LOAM around fewer grand abstractions."

It is:

> preserve the small semantic families and authority-specific laws, remove repeated representation/IO/proof mechanics beneath them, and retire production surface that no current authority or entrance needs.

Phase 4 can now audit dead/obsolete production paths without needing to guess what should replace them.
