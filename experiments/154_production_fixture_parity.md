# Observation 154 — production fixture parity through typed sections

## Question

Can the typed-section framing qualified by Observation 152 carry the existing
production Actual persistence representations without becoming a second semantic
parser or changing any currently observable meaning?

Observation 153 is already assigned to Scheduled routing subject pressure. This
observation therefore continues the persistence-topology line as Observation 154.

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
decoders. The observation introduces no unified production parser, writer,
loader, file path, migration, or canonical format.

## Qualification shape

These checks deliberately run as an executable public fixture qualification
rather than theorem declarations. The production String parsers are executable
boundaries, while LOAM's umbrella Lean build is axiom-audited. Keeping the heavy
parity pressure in `lake env lean --run` preserves that audit boundary instead of
adding native-evaluation axioms to formal declarations.

The executable witness requires that:

1. each public sidecar is already canonical under its production
   decode-then-encode path;
2. typed-section pack then unpack preserves all four sidecar representations
   exactly;
3. the production semantic projection is identical before and after framing;
4. the projection retains Event/Effect counts, exact quantities, occurrence
   dates, descriptions, and EventCorrection endpoint admission;
5. a valid outer frame containing an unsupported inner EventMemory version is
   still rejected by the production semantic decoder.

## Result boundary

If the executable qualification succeeds, typed framing has earned the status of
representation-only transport for current production Actual sidecars on the
public fixture. The existing production decoders remain semantic authority after
unwrap.

This still does not earn a production migration. The next question is whether one
complete framed Actual image can be staged and atomically replaced while
preserving current practical read/write behavior on public filesystem fixtures.
