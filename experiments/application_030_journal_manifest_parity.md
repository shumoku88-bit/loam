# Application 030 — Production-typed JournalExport manifest parity

## Question

Application 029 showed that seven retained read-only call-site shapes can share one generation-scoped physical reader while preserving caller-specific absence policy. This application asks a narrower, executable question:

> Can one complete retained read-only product path consume a manifest-selected generation through the existing production typed decoders and reproduce the current sidecar-derived answer byte-for-byte?

`loamJournalExport` is the first candidate because its output is a deterministic derived artifact. That gives a strong comparison surface:

```text
current sidecars -> production loamJournalExport -> journal A
manifest CURRENT -> production typed decoders -> same journal semantics -> journal B

journal A == journal B byte-for-byte
```

## Freshness and stack

This observation is stacked on Application 029 / PR #409 head `d2e21a140f8736e029291a529aa7f547ac75734d`.

At observation start actual `main` is `f9428b09bea3ee61d61ed8a6fa0512ec7a2701a9` (`experiment: separate choice commitment and funding posture (#408)`), unrelated to the publication stack.

Application 029 is open and mergeable with exact-head Application 029 workflows successful.

## Current JournalExport meaning

The production `JournalExportCli` currently reads four canonical evidence families:

```text
Event                required
EventCorrection      absent -> empty corrections
ActualValidity       absent -> empty history
EventDescription     absent -> empty descriptions
```

It then:

1. derives the current Event correction frontier;
2. derives one current ActualValidity per Event;
3. joins optional EventDescription text;
4. sorts by occurrence date and Event identity;
5. writes one derived human-readable journal.

The output is explicitly non-authoritative.

## Scratch manifest executable

Application 030 adds only an experiment executable source. It does not modify `JournalExportCli` or any production persistence module.

The scratch path:

```text
capture CURRENT once
  -> resolve requested content-addressed objects
  -> verify SHA-256
  -> existing production decoders
       decodeEventMemory?
       decodeEventCorrectionMemory?
       decodeActualValidityHistory?
       decodeEventDescriptionMemory?
  -> existing CorrectionFrontier / ActualValidityFrontier application logic
  -> the current JournalExport projection/rendering rules
  -> derived output
```

The manifest keeps explicit `PRESENT` / `ABSENT` for all four families. Event absence is rejected by this view. The other three preserve the existing JournalExport empty-evidence policy.

The rendering code is intentionally copied into the scratch experiment because the production renderer is private. The qualification therefore does not claim renderer deduplication or a production API change. The important comparison is the externally generated journal bytes.

## Qualification fixture

The workflow builds the real `loamMovement` and `loamJournalExport` executables and creates a genuine two-Event practical world through `loamMovement`.

It then runs two parity cases.

### Case A — descriptions present

- Event: present
- EventCorrection: absent
- ActualValidity: present
- EventDescription: present

The production sidecar exporter writes journal A. A second Lean process captures the manifest generation, decodes selected objects through production codecs, and writes journal B. `cmp` must report exact byte equality.

### Case B — descriptions absent

The production EventDescription sidecar is removed. The production exporter therefore falls back to `[EventId]` headings. A new manifest generation records EventDescription as `ABSENT`; the manifest-backed exporter must produce exactly the same bytes.

This case directly pressures Application 029's finding that physical absence must remain observable to the meaning-specific adapter instead of being globally collapsed into one storage rule.

## Qualified result

The first pull-request run completed successfully. Both parity cases produced exact byte equality:

```text
Application 030 JournalExport byte parity PASS
parity_cases=2
byte_equal_cases=2
production_typed_family_boundaries=4
explicit_absence_cases=2
```

Each manifest-backed export reported one generation capture:

```text
generation_captures=1
typed_family_boundaries=4
derived_output_publications=1
```

Case A recorded:

```text
EventCorrection  ABSENT
EventDescription PRESENT
```

Case B recorded:

```text
EventCorrection  ABSENT
EventDescription ABSENT
```

and still reproduced the production `[record-1]` / `[record-2]` fallback headings byte-for-byte.

So for this complete retained read-only answer, changing only the physical source of canonical bytes did not change the generated household-facing artifact.

## What is earned

Application 030 supports the narrow claim:

```text
one complete retained read-only product answer
can cross the sidecar -> manifest physical boundary
through existing production typed decoders
without changing its generated bytes
```

This is stronger than Application 029's opaque-byte reader probe. It still does not authorize production migration: the scratch executable duplicates the private JournalExport renderer, writer-capable consumers remain separate, and migration/GC/epoch orchestration remain governed by Applications 024-029.

A useful next pressure is no longer another opaque reader. It is whether the same generation snapshot can support a second meaningfully different retained read-only answer, preferably one whose output is not a regenerated file, without growing a generic repository layer.

## Boundary

No production source, canonical path, persistence format, typed decoder, CLI behavior, writer path, household data, migration contract, or deployment mechanism changes. This remains a scratch executable parity observation.
