# Observation 060: split publication recovery

## Question

Observation 059 found a bounded single-writer/single-reader protocol for physically separate Event and Correction streams:

```text
writer: Correction -> Event
reader: Event -> Correction
```

The next operational question is whether that ordering still protects semantic truth when either process can crash and restart.

More precisely:

1. Can a writer crash after publishing the Correction but before publishing the replacement Event without exposing an unsafe correction-aware view?
2. If the same publication request is explicitly retried after restart, can the writer safely restart from its first idempotent step?
3. Can a reader crash during acquisition, discard its partial sample, restart from the Event stream, and remain safe?
4. Does this already require a manifest/generation selector or one atomic multi-kind bundle?

This observation uses TLA+ and Apalache because the subject is now a state-transition protocol across crash/restart, rather than only a finite relational shape or one concrete two-process interleaving.

## Important distinction: safety versus recovery intent

A disk state such as:

```text
Correction stream: new
Event stream:      old
```

is semantically safe under fail-closed admission: the new Correction is inert while its replacement Event is absent.

But canonical facts alone do not say *why* that state exists. It can mean either:

- a publication crashed between its two physical writes; or
- a raw dangling relation was deliberately retained, which Observation 058 already allows.

Therefore this model does **not** infer a retry obligation from disk contents. `WriterRestart` means that the same publication request is supplied again from outside the canonical fact store.

If LOAM later needs autonomous crash recovery, that pressure may earn operational metadata such as a generation/manifest or another recovery-intent marker. Such metadata would not automatically become a domain fact.

## Model

`Observation060SplitPublicationRecovery.tla` models one original Event, one new replacement Event, and one new Correction.

Persistent physical state:

- `diskCorrectionNew`
- `diskEventNew`

Volatile writer/probe state:

- `writerUp`
- `writerPc`
- `writerCrashed`
- `crashedAfterRelation`

`crashedAfterRelation` records the specific recovery midpoint where the Correction has reached disk but the replacement Event has not.

Volatile reader state:

- `readerUp`
- `readerPc`
- `seenEventNew`
- `seenCorrectionNew`
- `readerDone`

Physical stream replacement itself is assumed atomic, as in the current EventMemory persistence boundary. Crashes do not roll back a stream that was already replaced.

### Writer recovery

The candidate writer remains relation-first:

```text
publish Correction
publish Event
```

If the writer crashes before completion, restart retries from the first step:

```text
Correction -> Event
```

Repeated publication of the already-new Correction is treated as idempotent at this abstraction level.

### Reader recovery

The reader remains Event-first:

```text
read Event
read Correction
```

If it crashes before completing the sample, restart discards the partial volatile acquisition and reads both streams again from the Event step.

## Safety properties

### `DiskOrder`

```text
new Event visible => new Correction already visible
```

A crash is allowed to leave the opposite mixed state:

```text
Correction new / Event old
```

because fail-closed admission keeps that Correction inert.

### `ReaderSnapshotSafe`

A completed reader sample must never have:

```text
new Event / old Correction
```

That is the transient shape that can make a correction-aware view pass through `original + replacement` merely because physical streams were sampled at incompatible publication points.

### `IndInv`

The model records a stronger reachable-state shape for Apalache's inductive-invariant check. It combines:

- type constraints;
- `DiskOrder`;
- reader snapshot safety;
- writer phase constraints;
- reader phase/sample constraints;
- the monotone mid-publication crash marker.

This is protocol structure only. It does not add chronology, transaction identity, authority, or a domain batch concept.

## Observed Apalache results

CI pins Apalache 0.62.2 and its release SHA-256, runs it on Java 21, and checks:

1. `Init` satisfies `IndInv`: **PASS**.
2. One `Next` step preserves `IndInv` from an arbitrary `IndInv` state: **PASS**.
3. `IndInv` implies `Safety`: **PASS**.
4. A bounded witness exists for `Correction published -> crash before Event -> restart/retry -> Event published`: **PASS, counterexample to `NoRecoveredCompletion` found**.
5. The sensitivity model `UnsafeNext`, which publishes Event before Correction, violates `DiskOrder`: **PASS, counterexample found**.

The first two checks establish the ordinary induction pattern: the initial state is inside `IndInv`, and every modeled transition preserves it. Because `Safety` follows from `IndInv`, the modeled safety property is not limited to one chosen execution length.

The last two checks keep the model from becoming vacuous. The exact mid-publication crash can recover under explicit retry, while reversing writer order still reaches the bad physical state.

## Interpretation

Observation 060 strengthens Observation 059:

> Crash/restart does not by itself force Event and Correction into one atomic physical bundle, provided publication remains relation-first, acquisition remains Event-first, already-published stream state does not roll back, and retry is explicit and idempotent at this level.

The crash after relation publication is safe because the relation remains semantically asleep until the Event appears.

This does **not** prove that autonomous recovery is available. After process death, the canonical disk facts intentionally do not distinguish an interrupted publication from a legitimate dangling raw relation. Completion therefore needs either:

- the original publication request to be retried externally; or
- a future operational recovery protocol with additional metadata.

That distinction keeps recovery machinery from leaking backward into LOAM's canonical domain vocabulary.

## What this does not model

- concurrent writers;
- writer serialization or locking;
- fsync / power-loss durability;
- corrupted or partially written individual files;
- multiple Corrections in one publication request;
- Resolution publication;
- compaction;
- deletion or rollback of already published facts;
- autonomous recovery-intent discovery;
- liveness or fairness guarantees for eventual retry.

No Core, Persistence, CLI, or wire-format change is made by this observation.

## Practical consequence

Do not add a manifest or combined Event/Correction/Resolution bundle merely for crash safety yet.

If explicit retry plus monotone atomic stream replacement is enough for the next practical persistence step, the split protocol can remain smaller. If LOAM later requires autonomous recovery, multiple coordinated relation publications, or concurrent writers, then generation/manifest semantics should be observed as an operational protocol before implementation.
