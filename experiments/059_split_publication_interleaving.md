# Observation 059: split publication interleaving

## Question

LOAM now has three typed raw memories:

- `EventMemory`
- `EventCorrectionMemory`
- `EventResolutionMemory`

Observation 054 showed that these fact kinds do not need one globally ordered logical history. Observation 055 showed that separate physical streams can expose torn raw snapshots, while fail-closed relation admission prevents a dangling relation from becoming semantic truth. Observations 057 and 058 then kept admission derived and kept raw relation append independent from current Event availability.

The practical persistence question is now close enough to ask a more operational question:

> If an Event memory and its Correction memory are persisted separately, can publication and acquisition order preserve a correction-aware effective view without requiring one atomic multi-kind bundle?

This observation does **not** yet choose a production file layout. It probes one bounded single-writer/single-reader protocol before LOAM adds Correction or Resolution persistence.

## Why SPIN

Earlier persistence observations were finite relational questions, so Alloy was the smaller tool. This question is different: the property depends on concrete writer/reader interleavings between separately published physical streams.

SPIN is used because the thing being observed is now the protocol itself.

## Bounded correction shape

The model fixes one common correction publication shape:

- the original Event is already visible;
- one replacement Event is new;
- one Correction targets the original and names the replacement;
- the final state contains both the replacement Event and the Correction.

The two physical stream versions are represented by booleans:

- `disk_event_new`: the Event stream exposes the replacement Event;
- `disk_correction_new`: the Correction stream exposes the raw Correction.

Fail-closed admission gives an asymmetry:

- Correction visible, replacement Event absent: the Correction is hidden, so the effective view remains old;
- replacement Event visible, Correction absent: the Correction cannot apply, so the effective view can transiently expose both original and replacement.

The second mixed state is the one this observation calls unsafe.

## Protocols compared

### Candidate split protocol

Writer:

```text
Correction stream -> Event stream
```

Reader:

```text
Event stream -> Correction stream
```

The writer publishes the relation first. Until the replacement Event becomes visible, fail-closed admission hides that relation. The Event publication acts as the semantic activation edge.

The reader acquires in the opposite direction. If it sees the new Event version, a single monotone writer must already have published the new Correction version, which the later Correction read can observe.

### Counterexample A: Event-first writer

Writer:

```text
Event stream -> Correction stream
```

Reader:

```text
Event stream -> Correction stream
```

There is an interleaving where the reader sees the replacement Event after the first writer step and sees the old Correction stream before the second writer step.

### Counterexample B: relation-first reader

Writer:

```text
Correction stream -> Event stream
```

Reader:

```text
Correction stream -> Event stream
```

There is an interleaving where the reader first acquires the old Correction stream, the writer then completes both publications, and the reader finally acquires the new Event stream.

## Expected SPIN results

- `059_split_publication_safe.pml`: **0 errors**
- `059_split_publication_unsafe_writer.pml`: **assertion violation exists**
- `059_split_publication_unsafe_reader.pml`: **assertion violation exists**

The assertion rejects a completed reader snapshot in which the replacement Event is visible while the Correction is not.

## Interpretation

For this bounded one-Correction protocol, separate physical streams do not automatically require one atomic bundle. But they are also not safe merely because each file is individually atomically replaced.

The ordering discipline matters in both directions:

```text
writer: relation -> Event
reader: Event -> relation
```

Fail-closed admission is doing more than rejecting malformed semantic input here. It becomes a semantic activation gate: an early raw relation can remain inert until its replacement Event is visible.

This also clarifies the distinction between LOAM's two quantity readings:

- **recorded** reading may legitimately change as soon as the replacement Event enters EventMemory;
- **correction-aware effective** reading should not accidentally pass through an `original + replacement` transient merely because two physical streams were sampled at incompatible publication points.

## What this does not prove

This bounded model does not yet establish a production persistence protocol.

It does not model:

- multiple concurrent writers;
- crashes or process restart;
- fsync or power-loss durability;
- retry or recovery;
- multiple Corrections in one publication;
- Resolution publication;
- compaction;
- a manifest/generation selector;
- a semantic transaction or batch identity.

In particular, LOAM still has no domain law saying that several newly appended facts belong to one all-or-nothing transaction. A bundle or manifest would therefore be premature if introduced only to manufacture such a grouping.

## Practical consequence

Do not yet add one combined Event/Correction/Resolution persistence bundle.

If LOAM next explores physically separate typed persistence, the reader and writer must be designed together. A naive set of independent `save...` / `load...` calls can recreate a transient effective meaning that the Core never intended.

The next persistence observation should move to crash/restart or multi-relation publication only when a concrete protocol is proposed. At that point TLA+/Apalache would be a strong candidate for checking state-transition invariants beyond this bounded two-process interleaving experiment.
