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

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced:

```text
duplicateSnapshotAmbiguity                         SAT
contentChangesAcrossContinuation                   SAT
positionChangesAcrossContinuation                  SAT
sourceOwnedIdentitySurvivesEditAndReorder           SAT
externalAnchorSurvivesEditAndReorder                SAT
VisibleSnapshotDeterminesContinuity                 SAT counterexample
ContentDeterminesStableContinuity                   SAT counterexample
PositionDeterminesStableContinuity                  SAT counterexample
StableSourceIdentityMakesContinuityDeterminate      UNSAT counterexample
StableAdmissionAnchorMakesContinuityDeterminate     UNSAT counterexample
```

The duplicate witness is the strongest negative result. Two histories can have
the same visible before/after content and positions while disagreeing about
which earlier occurrence continues as which later occurrence. A current mutable
snapshot therefore does not contain enough information to reconstruct
historical occurrence identity in general.

The content and position counterexamples close two common shortcuts:

```text
identity = content hash
```

cannot be stable across an allowed content edit, and:

```text
identity = line / presentation position
```

cannot be stable across an allowed reorder.

This does not claim that hashing or positions are never useful as hints. It
shows that neither can carry the semantic law of stable occurrence identity.

The positive witnesses show that both candidate ownership shapes can coexist
with content edits and reorder:

```text
source-owned stable identity
```

and:

```text
externally retained stable admission anchor
```

Under an explicit law that equal stable anchors are exactly the continuing
occurrence relation, each anchor relation makes continuity determinate in the
bounded model.

## Finding

The observation earns a narrower requirement than “use a sidecar” or “put IDs
in the source”:

```text
imported identity
    must be retained as continuity information
    not recomputed from mutable snapshot facts
```

Ownership remains open.

A source-owned stable identity is sufficient if the canonical source actually
retains and preserves it. An external admission anchor is also sufficient if
some future private layer can preserve and correctly reattach that anchor
through source edits.

That last condition is important. This model does **not** prove that a sidecar
can discover its own attachment after arbitrary edits. A sidecar that merely
stores:

```text
LOAM id -> old content or old position
```

inherits the same ambiguity. The external anchor itself must have a reliable
continuity protocol, stable source anchor, or explicit reconciliation step.

So the unresolved design question becomes more precise:

> Where can LOAM honestly retain occurrence continuity so that later source
> edits can preserve or explicitly reconcile it?

## Deliberate boundary

Observation 075 does not choose among:

- adding explicit identities to the canonical source;
- a private sidecar with a genuine continuity protocol;
- an admission ledger;
- an explicit reconciliation protocol for legacy records;
- or leaving some historical source records shadow-only and non-importable.

No new `ImportedId`, `SourceRecordId`, or generic identity abstraction is earned.

## Practical Core impact

None.

- `EventId` unchanged
- `EffectKey` unchanged
- Persistence unchanged
- `shadow-audit` remains read-only
- canonical source authority unchanged

Observation 075 constrains future importer design without making the Practical
Core larger.

## Next pressure

The next useful question should be operational rather than nominal:

> What is the smallest admission/reconciliation protocol that can attach a
> stable external identity to a legacy source occurrence without mutating the
> source or silently guessing after ambiguity appears?

That question may show that a private sidecar is sufficient, that source-owned
identity is simpler, or that some legacy records must remain explicitly
unresolved. Observation 075 does not decide among those outcomes.
