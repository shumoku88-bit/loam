# Application 025: Typed Movement manifest round-trip

## Pressure

Applications 020–024 established that a generation manifest can reduce the physical mutation/recovery state machine while keeping separately typed fact families. Application 024 still used opaque payload bytes at the reader boundary.

The remaining gate is semantic rather than merely physical:

> Can one genuine practical Movement world pass through `CURRENT`, restart, and the existing production codecs without changing the household answers LOAM publishes?

This application is intentionally stacked on Application 024 / PR #401.

## Practical fixture

The dedicated workflow creates the fixture through the existing `loamMovement` executable, not by constructing a synthetic Core value directly.

It records two practical Movements:

1. `2026-09-05`: `paypay -> travel`, 100 JPY, with one 100 JPY open RelationUnit to `friend` and an EventDescription;
2. `2026-09-06`: `friend-in -> paypay`, 40 JPY, with one 40 JPY RelationDischarge against the first relation and a second EventDescription.

The current production writer therefore owns admission, Event/Effect identity, date evidence, description evidence, relation admission, discharge admission, and the existing sidecar wire formats before the manifest experiment begins.

## Typed publication boundary

Application 025 loads the five resulting production families:

- EventMemory;
- ActualValidityHistory;
- EventDescriptionMemory;
- RelationUnit list;
- RelationDischarge list.

It decodes them with the existing production decoders, then re-encodes those typed values with the existing production encoders before preparing content-addressed objects.

The five immutable family images are selected by one `CURRENT` replacement.

No new household codec or alternate Event/Relation representation is introduced.

## Restarted typed reader

A second Lean process is the restart boundary.

It reads only the manifest-selected family images for the candidate authority, verifies each SHA-256 digest, and invokes the existing production decoders again. The reconstructed typed world is then projected through existing Core/Application operations.

The comparison observes:

- Event and Effect counts;
- `EventMemory.quantityAtRecorded` for `paypay`, `travel`, and `friend-in`;
- admitted ActualValidity dates for both Events;
- EventDescription lookup for both Events;
- RelationUnit and RelationDischarge counts;
- current admission of `relation-1`;
- `relationOutstandingQuantity?` for `relation-1`.

The expected household answers are:

```text
recorded paypay       -60 JPY
recorded travel       100 JPY
recorded friend-in    -40 JPY
relation-1 outstanding 60 JPY
```

The manifest-selected projection must equal the direct production-sidecar projection, and production re-encoding of all five selected typed families must reproduce the same canonical bytes.

## Cross-layer fail-closed check

Physical digest validity is not sufficient semantic validity.

After the positive comparison, the probe publishes a content-addressed Event object whose digest is internally consistent but whose EventMemory version is unsupported. `readCurrentTyped?` must still fail because the existing production Event decoder rejects that payload.

This checks that the manifest layer does not become a semantic bypass around the production codecs.

## Boundary

This is still a scratch authority experiment.

It changes no production writer, reader, persistence path, identity rule, CLI behavior, household data, or migration contract. The practical fixture is disposable CI data.

A successful result would establish that one complete Movement meaning path survives the manifest topology. It would not yet establish migration/rollback policy or justify replacing all production readers and writers at once.
