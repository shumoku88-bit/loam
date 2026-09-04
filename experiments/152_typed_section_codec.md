# Observation 152 — typed-section codec pressure

Observation 151 narrowed a unified Actual wire to one candidate family: a single
physical authority generation containing explicit typed sections for EventMemory,
ActualValidity, EventDescription, and optional EventCorrection.

This observation asks the next smaller question before any production persistence
change:

> Can the typed-section shape be encoded and decoded deterministically while
> malformed or ambiguous framing fails closed?

## Boundary

This is a public synthetic codec only.

It does **not**:

- define the production `actual.loam` syntax;
- read or rewrite private canonical household data;
- replace the current sidecar production loader;
- add a migration or compatibility layer;
- choose a permanent checksum algorithm or byte representation.

The synthetic wire uses `List Nat` so the observation can pressure framing rules
without smuggling in an implementation commitment.

## Synthetic framing

The model uses a fixed wire/version marker followed by framed sections:

```text
magic/version
section-tag payload-length payload...
section-tag payload-length payload...
...
```

Canonical required order:

1. EventMemory
2. ActualValidity
3. EventDescription
4. optional EventCorrection

EventCorrection is optional at the wire level in this observation because current
canonical history may have no physical correction stream. Crucially, absence and a
present-but-empty correction section remain different wire states during migration
qualification.

## Qualified pressure

Observation 152 checks:

- deterministic canonical encoding;
- required-facet round-trip;
- present correction round-trip;
- absent optional correction is not collapsed into present-empty;
- a representative projection is preserved after round-trip;
- truncated payloads fail;
- unknown section tags fail;
- duplicate sections fail rather than using merge or last-write-wins semantics;
- missing required sections fail;
- reordered required sections fail;
- unknown wire version/header fails.

## Unknown-section policy

Under this synthetic wire version, unknown section tags fail closed. Forward
extension is not silently accepted by an old parser.

A future Actual facet therefore needs either:

- an explicitly qualified new wire version; or
- a separately observed extension rule that proves old readers can skip the new
  section without changing the meaning they publish.

Observation 152 deliberately does not earn that rule in advance.

## Result interpretation

A passing observation does not mean production unification is earned. It means the
candidate survived one concrete codec pressure without requiring ambiguity,
implicit section ownership, or permissive recovery behavior.

The next question, if this passes, is whether the synthetic typed-section codec can
be connected to the existing production semantic parsers on public fixtures while
preserving exact projections and atomic stage/replace behavior. That should remain
a separate observation before any private canonical migration is considered.
