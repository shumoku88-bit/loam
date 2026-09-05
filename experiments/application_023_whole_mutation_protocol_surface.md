# Application 023: Whole mutation protocol surface

## Pressure

Applications 021-022 showed that a generation-manifest boundary can sharply reduce
writer-specific publication code, but raw line count did not give one clean winner.
Across five writers the scratch topology used more lines while using fewer bytes.

That is enough evidence that `small` must not be reduced to LOC.

Application 023 therefore compares the current and scratch designs as a vector of
independent obligations:

```text
semantic distinctions
authority-store mutations
partial durable authority prefixes
writer-specific publication order
partial-residue policy
semantic identity reservation caused by residue
reader indirection
garbage-collection obligation
migration obligation
writer ownership
source lines / bytes
```

The goal is not to manufacture one score. The goal is to expose where each design
is actually simpler and where it merely moves complexity.

This application is intentionally stacked on Application 022 / PR #395.

## Freshness

At the start of this observation actual `main` was
`bc604f8c1de0869c6c55629a3bc3b33c92b14f61` (`feat(cli): expose read-only Scheduled suppression query (#397)`).

The five mutation-writer blobs measured by Applications 021-022 remain unchanged
on that main: Movement, Scheduled completion, Event correction, Capacity, and
QuantityBasis correction therefore still have the same mutation/publication
shapes measured by the stack.

## Current maximum physical fan-out

The source-qualified maximum publication path is:

```text
Movement                  5 canonical family saves
Scheduled completion      4 canonical family saves
Event correction          3 canonical family saves
Capacity                  2 canonical family saves
QuantityBasis correction  2 canonical family saves
                         -------------------------
                         16 canonical family saves
```

For an ordered n-save operation there are at most n-1 durable prefixes after some
changed family has been published but before the final publication completes.
Application 019 already established the important semantic boundary: those partial
prefixes may remain durable while the activation discipline prevents readers from
observing a partially active household operation.

Applied to the five maximum shapes above:

```text
Movement                  4 partial authority-store prefixes
Scheduled completion      3
Event correction          2
Capacity                  1
QuantityBasis correction  1
                         --
                         11 maximum partial prefixes
```

This does **not** mean eleven simultaneous states exist in one run. It is a sum of
per-operation maximum interruption positions, useful only as a protocol-surface
measure.

## Current residue policies are not one generic rule

All five writers have explicit semantics for partial cross-family residue, but the
policies differ.

- Movement treats earlier Event-last residue as inert provenance and widens fresh
  Event identity allocation across validity/description/relation/discharge evidence;
  RelationUnit allocation also reserves retained discharge target ids.
- Scheduled completion recognizes and reuses retained completion/date/description
  evidence when retrying the deterministic completion Event identity.
- Event correction can resume one dangling correction relation and widens fresh
  replacement Event allocation across correction endpoints and validity history.
- Capacity publishes effective evidence before authority, reserves movement ids
  mentioned by effective evidence, and fails closed when the pair is incomplete,
  requiring explicit recovery.
- QuantityBasis correction publishes the correction relation first; if replacement
  basis publication fails, the retained relation remains inactive until its
  replacement exists.

So the current source is not merely five copies of `save A; save B`. The physical
split creates five operation-specific answers to interruption, retry, residue, and
identity reuse.

The measurement identifies three fresh-id allocators whose search domain is
explicitly widened by supporting-stream residue: Movement, Event correction, and
Capacity. Scheduled completion instead uses a deterministic Event identity plus
retained-evidence collision/retry checks; QuantityBasis correction has a different
relation-first boundary.

## Manifest topology

Application 022's scratch side retains the same typed fact-family distinctions and
five meaning-specific adapters, but physical publication is centralized:

```text
writer says which families changed
        ↓
prepare content-addressed objects off-authority
        ↓
construct next complete manifest
        ↓
replace CURRENT once
```

For five operations this gives five manifest authority switches and zero partial
**authority** prefixes. Partial object preparation still exists, but unreferenced
objects are outside authority.

Because object names are derived from family plus content digest rather than from
EventId, RelationUnitId, CapacityMovementId, or another household identity, an
interrupted unreferenced object does not reserve a semantic identity merely by
existing.

This is a real simplification of writer-side temporal state.

## Complexity that moves to readers and lifecycle

The manifest topology is not free simplification.

It adds one reader-indirection layer:

```text
CURRENT
  -> typed family ref + digest
      -> immutable family object
          -> existing family decoder
```

It also introduces obligations that current direct canonical family paths do not
need in the same form:

- unreachable immutable-object garbage collection or an explicit decision never
  to collect them;
- migration from the existing direct-path layout;
- compatibility/version policy for the manifest itself;
- digest verification and missing-object failure handling.

Writer ownership is **not** removed. A stale writer can still prepare from an old
manifest and must not overwrite a newer selected generation. Existing ownership,
or an equivalent compare-and-swap discipline, remains required.

## Multi-axis comparison

```text
                                      current ordered streams     manifest/object selector
semantic fact distinctions            retained                    retained
meaning-specific writer adapters      5                           5
writer-specific publication protocols 5                           0 (1 shared physical primitive)
maximum canonical save/switch steps    16 family saves             5 selector switches
maximum partial authority prefixes     11                          0
partial non-authority preparation      no separate boundary        yes
writer-specific residue policy         5 distinct policies          largely removed physically
orphan semantic-id reservation         present in several writers  none from object existence
reader indirection                     direct family paths          +1 manifest layer
garbage-collection obligation          no manifest-object GC        new obligation
migration obligation                   current format               new adoption cost
writer ownership                       required                     still required
Application 022 source bytes           11,779 publication-tail B    7,665 shared+adapters B
Application 022 source lines           164 publication-tail lines   201 shared+adapters lines
```

The source byte/line rows are deliberately kept beside, not above, the protocol
rows. They are two measurements among several.

## Result

The manifest topology is **smaller on writer-side state-machine surface** but not
unconditionally smaller as a whole product.

The strongest earned statement is:

```text
same semantic families
+ same domain admission responsibilities
+ same writer-ownership requirement

can be paired with

fewer canonical mutation steps
+ no partial authority-store prefixes
+ fewer writer-specific interruption protocols
+ less semantic identity reservation caused only by orphan publication residue
```

The counterweight is equally real:

```text
manifest parsing
+ reader indirection
+ digest/object lifecycle
+ migration/compatibility
```

Therefore production migration is still not earned from source size alone.

## Next adoption gate

The smallest useful next experiment is not another adapter-count exercise. It is
a **reader + recovery lifecycle prototype**:

1. read a complete household generation only through `CURRENT`;
2. reject malformed/missing/digest-mismatched objects fail-closed;
3. simulate an interrupted writer leaving unreferenced objects;
4. restart without semantic-id reservation from those objects;
5. define one conservative orphan-retention/GC policy;
6. compare total reader + writer + recovery implementation surface with the
   current direct-path system.

If that full lifecycle remains simpler while preserving inspectability and typed
fact boundaries, the case for production migration becomes much stronger.

## Boundary

No production source, persistence format, canonical path, executable behavior,
identity rule, household data, or current writer semantics change in this
application. It is a source/topology observation only.
