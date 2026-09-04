# Observation 153 — production fixture parity through typed sections

## Question

Can the typed-section framing qualified by Observation 152 carry the existing
production Actual persistence representations without becoming a second semantic
parser or changing any currently observable household meaning?

## Public fixture

This observation uses only synthetic public data:

- two Events and four Effects;
- Event-rooted ActualValidity dates for both Events;
- one EventDescription per Event;
- one EventCorrection from the first Event to the second.

No private canonical household data is used.

## Boundary under test

The inner payloads are the existing production versioned representations:

- `LOAM-EVENT-MEMORY\t1`;
- `LOAM-ACTUAL-VALIDITY-HISTORY\t2`;
- `LOAM-EVENT-DESCRIPTION-MEMORY\t1`;
- `LOAM-EVENT-CORRECTION-MEMORY\t1`.

Observation 152's typed framing carries those representations as opaque payloads.
After unwrap, semantic admission is performed only by the existing production
decoders. The observation does not introduce a unified production parser,
writer, loader, file path, migration, or canonical format.

## Qualified pressure

The Lean witness checks that:

1. each public sidecar is already canonical under its production
   decode-then-encode path;
2. typed-section pack then unpack preserves all four sidecar representations
   exactly;
3. the production semantic projection is identical before and after framing;
4. the projection retains Event/Effect counts, exact quantities, occurrence
   dates, descriptions, and EventCorrection endpoint admission;
5. a valid outer frame containing an unsupported inner EventMemory version is
   still rejected by the production semantic decoder.

## Result

The framing can remain representation-only. It does not need to understand the
four Actual fact families in order to preserve their current production meaning.
The existing production decoders remain the semantic authority after unwrap.

This earns the next question, not a migration: can one complete framed Actual
image be staged and atomically replaced while preserving the existing practical
read/write behavior on public filesystem fixtures?
