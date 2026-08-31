# Observation 074 — Can a private canonical source pressure LOAM without invented identity?

## Question

Observation 062 showed that anonymized real-ledger shapes fit the existing
Event / Effect / Locus / Quantity vocabulary without forcing a conventional
Account object back into the neutral core.

That observation deliberately left one import question unresolved:

```text
source posting identity
    ?=
LOAM Effect identity
```

Observation 052 had already established the more general law:

```text
Effect identity
    !=
Locus × Measure coordinate
```

Observation 074 now applies those two findings to practical dogfooding. The
question is:

> Can a private canonical household source be projected into the Practical
> Core read-only, without copying private values into the public repository and
> without manufacturing stable Event or Effect identity that the source did not
> actually retain?

## Private boundary

A private canonical household source was inspected read-only.

The public observation copies none of its:

- descriptions;
- account or locus names;
- dates;
- quantities;
- plan or issue identities;
- policy values;
- notebook text.

Only anonymous structural pressure is recorded here.

The private source remains canonical. LOAM does not become a writer, backup,
mirror, migration target, or second authority in this observation.

## Anonymous real-data pressure

The sampled source contains ordinary quantity-bearing records with several
structural properties already anticipated by earlier observations:

- one source record may contain two or more quantity postings;
- some source records carry an explicit event-like identity, while others do
  not;
- the sampled posting representation does not universally retain a stable
  per-posting identity suitable for direct use as `EffectKey`;
- descriptive text and additional metadata coexist with the quantity shape;
- some metadata refers to planning or other relations rather than physical
  quantity placement.

The first item is not a problem for current Practical Core `Event`, which can
retain several independently identified Effects.

The identity items are the important pressure.

## Why direct conversion is not yet honest

Current Practical Core requires:

```text
EventId
EffectKey
Locus
Measure
Quantity
```

`EventId` and `EffectKey` are opaque stable identities. They are deliberately
not derived from:

- list or file position;
- display description;
- Locus / Measure coordinate;
- amount;
- a convenient presentation ordering.

Therefore a source record that has quantity placement but lacks explicit
stable identity cannot be turned into a lossless Practical Core Event merely by
choosing a convenient token.

For example, assigning identities from source line number would make file
reordering an identity change. Assigning them from date, description, or amount
would fuse identity with mutable or non-unique presentation facts. Assigning an
Effect key from its coordinate would reverse Observation 052.

The bounded practical conclusion is:

```text
source quantity shape
    does not by itself earn
stable LOAM Event / Effect identity
```

## Read-only shadow audit

Observation 074 introduces a deliberately narrow adapter:

```text
./tools/loam shadow-audit <journal-file>
```

Its job is not import. Its job is to answer whether the scanned source has
sufficient explicit identity to admit a lossless Practical Core projection
without invention.

The adapter has a fail-closed privacy and authority boundary:

- reads one external source file;
- writes nothing;
- creates no LOAM Event or EventMemory;
- creates no sidecar, cache, converted source, or migration artifact;
- never emits raw source lines or tokens;
- normal output exposes only `complete`, `partial`, or `absent` identity
  coverage and a yes/no readiness result;
- `--counts` is opt-in and emits only aggregate structural counts;
- source descriptions, identities, coordinates, dates, measures, quantities,
  and metadata values are never printed.

The scanner recognizes only enough journal-shaped structure to count source
records, candidate effects, multi-effect records, opaque metadata presence, and
explicit identity markers. It deliberately does not interpret accounting role,
plan semantics, recurrence, issue meaning, description meaning, or balance.

## CI boundary

Private canonical data must not enter public CI logs, fixtures, artifacts, PRs,
or repository history.

The dedicated workflow therefore uses only synthetic fixture data. It checks:

- the compiled audit path;
- fail-closed identity readiness when identity is incomplete;
- successful readiness for a fully identified synthetic specimen;
- aggregate count behavior;
- byte-for-byte source immutability;
- absence of synthetic raw descriptions, loci, and quantities from audit
  output.

A successful public CI run proves the adapter boundary against synthetic input.
It does not claim that private data was uploaded to or evaluated by CI.

## Why no new Alloy, TLA+, or Lean Core theorem

The semantic identity laws are already established by earlier observations and
encoded in the Practical Core types.

The new pressure is operational: a real private source does not uniformly carry
all identity required by the target representation. Alloy would restate an
already-earned information distinction, and TLA+ would add temporal machinery
without answering a different question.

Lean is used here only to compile the practical read-only scanner. No new Core
law is introduced.

## Finding

The first real-data shadow boundary is:

```text
observe source structure
    !=
import source facts
```

and:

```text
missing stable identity
    ->
report pressure
    not
invent identity
```

This means real canonical data can already participate in LOAM dogfooding while
remaining outside LOAM authority. The useful output of the first shadow pass is
not a migrated ledger. It is evidence about which parts of the source can be
projected honestly and which parts still need an explicit relation or identity
owner.

## Practical Core impact

None.

- `Event` unchanged
- `Effect` unchanged
- `EventMemory` unchanged
- Persistence unchanged
- correction semantics unchanged
- source canonical authority unchanged

The new code is an adapter-side observation tool, not a Core importer.

## Next pressure

If real shadow audit confirms incomplete identity, the next question should not
be “what hash should the importer use?”

It should be:

> Who owns imported identity, and what future edits must preserve it?

Possible later observations may compare:

- source-owned explicit identity;
- a private external identity sidecar;
- identity assigned once at an admission boundary;
- content-derived identity and the edit/reordering failures it creates.

No option is selected by Observation 074.
