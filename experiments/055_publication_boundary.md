# Observation 055: publication boundary

## Question

Observation 054 separated LOAM's logical canonical basis from its physical storage topology. If Events, Corrections, and Resolutions may be logically distinct fact kinds, must they still share one atomic publication boundary to preserve a truthful readable state?

This observation compares three possibilities without choosing a production persistence protocol:

1. one atomic bundle publication;
2. independently published typed streams with no coordination;
3. independently published typed streams with either dependency ordering or fail-closed admission.

## Model

A `Snapshot` exposes three memberships:

- `events`
- `corrections`
- `resolutions`

A snapshot is `closed` only when every visible Correction target/replacement and every visible Resolution parent/replacement is also a visible Event.

`Old` and `New` are closed append-only snapshots. `Mid` represents a state that could become externally visible during publication.

### Atomic bundle

`bundleMid` allows `Mid` to equal only the complete `Old` snapshot or the complete `New` snapshot.

### Independent streams

`independentMid` allows each typed membership to have independently advanced from `Old` to `New`. This can expose a relation stream before the Event stream containing one of its endpoints.

### Dependency ordering

`eventsBeforeRelations` requires the Event membership to reach `New` before either relation membership is exposed at `New`.

This is intentionally stronger than the minimal dependency graph. It asks whether a simple publication discipline is already sufficient without requiring one physical bundle.

### Fail-closed admission

`admittedCorrections` and `admittedResolutions` retain only visible relations whose Event references are all currently present. A raw physical snapshot may therefore be torn while its admitted semantic view remains referentially closed.

This does not declare torn storage desirable. It asks whether a reader/admission boundary can prevent partial physical publication from becoming partial semantic truth.

## Commands

Expected Alloy results:

- `correctionPublicationCanTear`: SAT
- `resolutionPublicationCanTear`: SAT
- `dependencyOrderedPublicationExists`: SAT
- `failClosedCanHideTornRelation`: SAT
- `AtomicBundlePreservesClosure`: UNSAT
- `IndependentPublicationAlwaysPreservesClosure`: SAT
- `EventsBeforeRelationsPreservesClosure`: UNSAT
- `FailClosedAdmissionPreservesClosure`: UNSAT
- `FinalClosedSnapshotAdmitsAllRelations`: UNSAT

## Interpretation

An atomic bundle is sufficient to preserve referential closure, but the model does not make it necessary.

Uncoordinated independent publication can expose torn snapshots. Alloy can show both a Correction and a Resolution becoming visible before a newly referenced Event is visible. Therefore physical stream separation cannot by itself be treated as a safe semantic publication rule.

However, a simple dependency discipline can preserve closure while the physical streams remain distinct: publish the required Event membership before exposing new Correction or Resolution membership.

A fail-closed admission boundary provides another separation. Even when raw storage is temporarily torn, relations with missing Event endpoints are not admitted into the readable semantic view. Once the final closed snapshot is visible, every relation is admitted again; the guard does not permanently erase the facts.

So the logical canonical basis and the atomic publication boundary do not have to share the same topology.

The emerging distinction is:

- **logical canonical basis**: admitted facts plus explicit identity relations;
- **raw physical state**: bytes/streams that may be at different publication points;
- **admitted semantic snapshot**: only a referentially closed view is allowed to answer domain queries;
- **publication protocol**: bundle replacement, dependency ordering, manifest/generation switching, or another future mechanism.

## Practical consequence

LOAM should not yet commit to either "one canonical file" or "three independently authoritative files".

Observation 055 instead gives a stronger requirement for future persistence work:

> A reader must never promote a partially published relation into semantic truth when its referenced Events are absent.

Atomic bundle publication is one way to satisfy that requirement. Dependency-aware publication plus fail-closed admission is another modeled possibility.

The next persistence decision should therefore be driven by operational pressure such as crash recovery, concurrent writers, synchronization, generation switching, compaction, or human inspectability rather than by the logical fact topology alone.

This observation does not add time, chronology, transaction ordering, Account, Journal, debit, credit, or a production source-of-truth schema.
