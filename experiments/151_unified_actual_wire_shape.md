# Observation 151 — Which unified Actual wire shape is earned?

## Context

Observation 149 kept the current sidecar topology as the production baseline but found that unified Actual deserved deeper study.

Observation 150 then qualified a narrower authority model:

- Event, ActualValidity, EventDescription, and EventCorrection remain distinct semantic facets;
- one complete Actual generation may be staged beside the current authority;
- readers see old generation until the atomic authority switch;
- the qualified path exposes old, old while staged, then new;
- Scheduled, QuantityBasis, and view configuration remain outside that switch.

Observation 151 asks what physical wire shape best fits those already-earned constraints. It does not add production persistence or migrate canonical data.

## Candidate A — opaque bundle

Representative shape:

```text
LOAM-ACTUAL-BUNDLE 1
SECTION event-memory <length> <raw current bytes>
SECTION actual-validity <length> <raw current bytes>
SECTION descriptions <length> <raw current bytes>
SECTION event-corrections ABSENT|<length> <raw current bytes>
```

Strengths:

- exact byte-for-byte recovery of the current streams;
- explicit facet framing;
- easy one-time migration and rollback qualification;
- preserves physical absence of an optional current EventCorrection stream.

Weakness:

- it is still a container around several old persistence grammars;
- production would retain the old parser family inside a new outer shell;
- therefore it is a useful migration/recovery specimen, not yet a native unified wire.

## Candidate B — tagged flat stream

Representative shape:

```text
LOAM-ACTUAL 1
EVENT ...
EFFECT ...
VALIDITY ...
DESCRIPTION ...
EVENT_CORRECTION ...
...
```

Strengths:

- one native parser surface;
- compact and human-readable;
- correction relations can remain explicit cross-Event records.

Weakness:

- the four semantic facets become one undifferentiated record sequence;
- boundaries earned by Observation 150 survive only as tags, not as framed structural units;
- later extension makes ordering and unknown-record handling part of one global grammar.

Observation 151 therefore does not select the flat stream.

## Candidate C — typed sections

Representative shape:

```text
LOAM-ACTUAL 1

SECTION EVENT_MEMORY 1 <byte-length>
  EVENT ...
  EFFECT ...
END

SECTION ACTUAL_VALIDITY 1 <byte-length>
  BASE ...
  REVISION ...
  CORRECTION ...
END

SECTION EVENT_DESCRIPTION 1 <byte-length>
  DESCRIPTION ...
END

SECTION EVENT_CORRECTION 1 ABSENT
```

The exact text above is illustrative, not a production syntax proposal.

Properties:

- one physical authority generation;
- four explicit semantic facet boundaries remain visible;
- EventCorrection remains a relation section rather than being owned by one endpoint Event;
- each section can carry deterministic framing and a section-local version;
- unknown framing can fail closed before semantic interpretation;
- a future Actual facet can be added as another framed section without rewriting existing facet grammars.

Under the currently earned constraints, this is the surviving native candidate.

## Candidate D — per-Event aggregate

Representative shape:

```text
EVENT e1 {
  effects ...
  validity ...
  description ...
  corrections ...
}
```

This is locally attractive, but EventCorrection relates a target Event to a replacement Event. Assigning that relation to either Event invents ownership not present in the current semantics. Correction chains also become physically scattered according to an arbitrary nesting rule.

Therefore per-Event aggregation is not earned.

## Optional-section presence

Migration qualification must distinguish:

```text
ABSENT
```

from

```text
PRESENT but empty
```

for an optional source stream such as the currently empty EventCorrection persistence stream. A candidate must not invent a physical empty source file merely because the unified representation has an empty semantic section.

This distinction is migration provenance, not a claim that absence and emptiness are forever different domain facts.

## Envelope versioning

A wire/header/section version belongs to persistence framing. It must not become:

- Event identity;
- Effect identity;
- provenance identity;
- household evidence.

Versioning metadata is representation glue around typed household facts.

## Result

Observation 151 classifies the candidates as:

```text
OPAQUE BUNDLE
  useful for exact migration / recovery qualification
  not selected as native production wire

TAGGED FLAT STREAM
  native but loses explicit facet structure
  not selected

PER-EVENT AGGREGATE
  invents ownership for cross-Event correction topology
  not selected

TYPED SECTIONS
  survives the currently earned constraints
  deserves concrete synthetic serializer/parser pressure
```

This does **not** authorize production implementation or canonical migration.

The next step, if this observation qualifies, is to implement a scratch/public synthetic typed-section codec and test:

- deterministic encode;
- encode -> decode semantic identity;
- decode -> encode canonical byte identity;
- malformed/truncated section failure;
- unknown section/tag failure policy;
- absent optional correction-state preservation during current-stream migration;
- projections after decoded materialization.

Only after that pressure should production persistence be considered.
