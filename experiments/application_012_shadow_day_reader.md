# Application 012: Can one useful household day be read without importing HRA ontology?

## Pressure

A household application eventually needs questions such as:

```text
what happened on this day?
```

The private canonical source already contains dated Actual records, but LOAM
should not treat the source schema as its own ontology merely because that data
is convenient to read.

Application 012 therefore asks a deliberately narrow question:

> Can one exact recorded day be presented from a journal-shaped source while
> keeping source date and human context at the adapter boundary and leaving the
> neutral LOAM Core unchanged?

## Boundary

The new executable is:

```text
lake exe loamShadowDay -- YYYY-MM-DD PATH/TO/actual.journal
```

It is a read-only source adapter, not an importer.

The adapter temporarily retains only:

```text
day
human header context
neutral Event
  -> Effects
     -> Locus / Measure / Quantity
```

The `day` and human context do not become fields of production `Event`.
No `Account`, `AccountType`, `Transaction`, `Actual`, `Plan`, `Envelope`,
`Issue`, or HRA package vocabulary is introduced into LOAM Core.

Generated EventId and EffectKey values are run-local representation witnesses
only. They are not printed, persisted, or reused across runs.

## Recorded, not effective

This first reader says only:

```text
recorded on this source day
```

It does not yet claim:

```text
effective on this day
```

Source correction, reversal, realization, completion, and other durable
relations are not reconstructed from physical quantity shape or description
text.

That distinction is intentional. A later effective-day query must earn the
specific relation evidence it needs rather than inherit source-specific rules
implicitly.

## Include boundary

The reader is file-local. It recognizes `include` directives so that they are
not mistaken for occurrences, but does not follow them. The output explicitly
reports when include directives were present.

This keeps the first operation small and honest:

```text
read this file
    !=
claim complete canonical include-graph admission
```

If an application question later needs included occurrence-bearing documents,
include traversal should be introduced as its own source-adapter capability.

## Why this does not make HRA the design

The source answers the factual question "which records carry this day?".
LOAM still decides the target vocabulary.

The mapping is deliberately asymmetric:

```text
source date header
    -> adapter-local day evidence

source posting
    -> neutral Effect

source account-looking token
    -> neutral Locus

source human description
    -> untyped presentation context
```

Nothing maps automatically to a LOAM `AccountType`, expense ontology, income
ontology, or report subsystem.

The adapter can be deleted without changing `Loam/Core` or existing Practical
Core persistence.

## Qualification

Public CI uses synthetic journal-shaped input only. It checks that:

- only the requested day is printed;
- several occurrences on the same day remain distinct;
- another day does not leak into the answer;
- include directives are reported but not followed;
- malformed day input fails closed;
- malformed source lines fail closed;
- the source file remains byte-for-byte unchanged;
- no LOAM persistence or sidecar is created.

Private household values, descriptions, dates, identities, and paths are not
copied into public fixtures or logs.

## What this earns

A first useful household-facing temporal view can stay outside the neutral
Core:

```text
journal-shaped source
    -> adapter-local day evidence
    -> neutral Events
    -> recorded-day presentation
```

It does **not** yet earn a general LOAM time model.

## Next pressure

After private dogfood, inspect what is actually missing from this recorded-day
view.

Likely candidates include:

- effective correction / reversal interpretation;
- source include traversal;
- day aggregation by selected loci or categories;
- a month or cycle query built from the same minimal evidence.

Each should be earned by a concrete household question rather than by copying
HRA's source taxonomy wholesale.
