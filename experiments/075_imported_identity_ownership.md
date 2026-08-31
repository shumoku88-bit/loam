# Observation 075 — Who owns identity when the source does not?

## Question

Observation 074 established a fail-closed shadow boundary:

```text
missing stable identity
    -> report pressure
    not invent identity
```

The private canonical source remains authoritative, and the read-only shadow
audit does not create EventId or EffectKey values when the source does not
retain suitable stable identity.

The next question is not which hash function to use. It is:

> If a source record has no stable occurrence identity, can a later snapshot of
> mutable source content determine which earlier occurrence it continues, and
> if not, what kind of retained anchor would be sufficient?

This observation deliberately does not choose a source format, sidecar format,
import protocol, or new Practical Core type.

## Why this is different from Observation 052

Observation 052 established:

```text
Effect identity
    !=
Locus × Measure coordinate
```

Observation 075 does not revisit that law. It asks how an imported occurrence
can keep any stable Event / Effect identity at all when the source itself may
not expose one.

## Bounded model

The model contains two snapshots, represented by two before-slots and two
after-slots. A slot has only mutable visible properties:

```text
Content
Position
```

A hidden continuity relation says which earlier occurrence continues as which
later occurrence.

Two possible stable anchors are modeled separately:

```text
StableSourceId
AdmissionAnchor
```

`StableSourceId` represents identity explicitly owned by the canonical source.
`AdmissionAnchor` represents an opaque identity retained outside the mutable
source snapshot, for example by a future private admission layer.

The names do not select an implementation. The experiment asks only what
information is required to make continuity determinate.

## Pressures under test

### Duplicate snapshots

Two histories can expose the same visible content and position while disagreeing
about which earlier duplicate continues as which later duplicate.

If that witness is reachable, current snapshot information alone cannot recover
historical occurrence identity.

### Content edits

A continuing occurrence may change visible content. Therefore identity derived
from the complete mutable content would change when the occurrence is edited.

### Reordering

A continuing occurrence may move to another source position. Therefore identity
derived from line or presentation position would change when records are
reordered or an earlier insertion shifts positions.

### Stable anchors

The model then imposes two alternative conformance laws:

```text
same StableSourceId
    iff
same continuing occurrence
```

or:

```text
same AdmissionAnchor
    iff
same continuing occurrence
```

If either law makes continuity determinate even while content changes and
position moves, then the important requirement is not where identity is owned.
It is that some stable occurrence anchor survives outside mutable snapshot
facts.

## Expected boundary

The expected result is:

```text
current mutable snapshot
    does not determine
historical continuity

content-derived key
    is not stable across allowed edits

position-derived key
    is not stable across allowed reorder
```

while either an explicitly stable source identity or an explicitly retained
admission anchor can make continuity determinate under the corresponding
conformance law.

## Deliberate boundary

Even if that expectation is confirmed, Observation 075 will not choose among:

- adding explicit identities to the canonical source;
- a private sidecar;
- an admission ledger;
- a reconciliation protocol for legacy records;
- or leaving some historical source records shadow-only and non-importable.

In particular, an external sidecar is not automatically sufficient merely
because it stores a LOAM identifier. It still needs a stable way to know which
source occurrence that identifier belongs to after source edits.

## Practical Core impact

None unless a later practical operation earns it.

Observation 075 is intended to constrain future importer design, not to add a
new Core identity layer.
