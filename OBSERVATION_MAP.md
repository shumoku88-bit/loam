# LOAM Observation Map

This document is a checkpoint after Observations 001–060.

It is not a final ontology, schema, or roadmap. It records what the current observations have earned, what remains derived or overlay-like, what the practical Lean core currently carries, and what LOAM has deliberately not promoted into domain meaning.

## 1. The arc so far

### 001–017 — before household nouns

The first observations begin without Account, Transaction, Budget, Envelope, Month, or Report and ask what survives when finite resources are distributed through time and purpose.

The main pressure is whether familiar household nouns carry independent information or can be recovered as views over smaller relations.

Notable outcomes include:

- availability can be derived in the bounded consumptive world;
- live envelope-like holdings can be a projection of purpose placement and derived availability;
- commitment needs information beyond live holdings;
- vocabulary itself changes what history must remain distinguishable.

### 018–029 — memory, provenance, correction, and resolution

The second arc asks how much history must remain when later questions can target, explain, correct, or resolve earlier facts.

The recurring separation is:

```text
what happened
!=
how the current view interprets it
```

Append-only parentage, explicit identity, correction, resolution, conflict, and provenance pressure appear here. Compression remains vocabulary-relative: information may be forgotten only when no retained future question can distinguish the worlds it separates.

### 030–039 — generic events, coordinates, and time geometry

The third arc removes more nominal household structure.

A bounded generic event can carry selected household distinctions without primitive stored event-kind names. `Account` does not yet return as an irreducible domain object, but a distinguishable `Locus` coordinate becomes necessary once future questions ask where quantity resides.

A separate `Measure` coordinate becomes necessary when quantities that must not be collapsed coexist.

Time also separates into more than one observable coordinate. In particular:

```text
valid time
!=
learned time
```

and retrospective knowledge is naturally queried as a two-dimensional view:

```text
view(valid time, knowledge time)
```

### 040–051 — revision structure, overlays, and asynchronous evidence

The fourth arc pressures explanation edges, conflict recurrence, revision graphs, frontier settlement, coverage, selection, backing eligibility, accounting role, asynchronous settlement, and reconciliation evidence.

A repeated result is that many familiar classifications are not properties of physical quantity placement itself. They remain independent overlays unless richer facts later earn a derivation.

In particular:

```text
where quantity is
!=
what accounting role that locus plays
```

Selection and backing eligibility likewise remain outside the physical holdings core in the observations that test them.

### 052–060 — from observation to practical protocol

The fifth arc turns directly toward the practical Lean core and persistence boundary.

It first separates effect identity from coordinate aggregation:

```text
Effect identity
!=
Locus × Measure coordinate
```

Then it separates physical storage order from history, compares unified and split canonical fact topologies, observes publication boundaries, relation collection identity, derived referential admission, and raw relation-memory append admission.

The final two observations use protocol-specific tools:

- Observation 059 uses SPIN to check split-stream publication/acquisition interleavings.
- Observation 060 uses TLA+ / Apalache to check crash/restart/retry behavior for the same candidate protocol.

The candidate ordering earned by those bounded observations is:

```text
writer: Correction -> Event
reader: Event -> Correction
```

with fail-closed semantic admission hiding an early Correction until its referenced replacement Event is available.

Observation 060 does not earn autonomous recovery, concurrent-writer semantics, fsync guarantees, or a manifest/generation protocol.

## 2. Earned structure

The following structures currently carry distinctions that at least one retained question can observe.

### Stable identity

- Event identity
- Effect identity
- Locus identity
- Measure identity
- per-kind Correction identity
- per-kind Resolution identity

Identity is not inferred from list position, physical storage order, display names, or aggregate coordinates.

### Quantitative coordinates

The practical physical shape is centered on exact signed quantity effects with explicit coordinates:

```text
Event
  -> Effect
       -> Locus
       -> Measure
       -> Quantity
```

Coordinate totals are projections over effects, not effect identity.

### Explicit revision relations

Correction and Resolution remain explicit raw relation facts rather than edits that erase earlier facts.

Their referenced Events may be absent from the current Event memory. Raw memory can still retain the relation fact while derived referential admission fails closed.

### More than one time coordinate when the question requires it

The observation layer has earned a distinction between validity and knowledge time for retrospective questions. This does not imply that every practical-core fact must immediately carry both timestamps.

## 3. Derived views

The following have appeared as derivable views rather than automatically deserving primary stored identity.

- live envelope-like holdings
- availability in the bounded consumptive model
- total balance
- balance by Locus / Measure
- transfer-like shape
- current tips of a revision graph
- correction-aware effective views
- referentially admitted relation views
- report-like readings over physical facts plus overlays

A derived view may later earn stored operational support for performance or publication, but that would not by itself make the stored representation canonical domain meaning.

## 4. Overlays

These relations have evidence of semantic independence from the neutral physical core, or are intentionally kept outside it pending stronger pressure.

- Purpose / intentional assignment
- AccountingRole
- valuation / rate relations
- selection policy
- backing eligibility
- recipient assignment
- other application-facing classifications

An overlay is not "less real." It means its meaning is not determined by the underlying physical placement and quantity relations currently retained.

## 5. Practical Lean core

The practical core now contains small typed pieces including:

- `Quantity`
- `Measure`
- `Effect`
- `Event`
- `EventMemory`
- `EventCorrection`
- `EventCorrectionMemory`
- `EventResolutionMemory`
- correction-aware quantity projections
- relation admission
- `Rate`
- `Allocation`
- `RecipientAssignment`

The implementation policy remains conservative:

```text
observation
  -> identify one earned distinction or law
  -> add only the minimum practical representation needed
```

The practical core is not intended to mirror every experimental vocabulary term.

## 6. Persistence boundary

The current practical persistence work has crossed an important boundary without introducing one global ordered history.

Event memory and raw Correction memory can be persisted as separate versioned streams. The logical canonical basis is the admitted facts and their explicit identity relations, while physical storage topology is a separate operational choice.

The current observations therefore distinguish:

```text
logical canonical facts
!=
physical storage topology
!=
derived projections
```

Separate atomic file replacement is not sufficient by itself when multiple streams form one semantic read/write protocol. Writer and reader order are part of the protocol.

## 7. Deliberately unearned concepts

LOAM should not silently promote the following into domain law without a new observation that requires them.

- one global FactId shared by all fact kinds
- one globally ordered canonical history
- chronology from list or file position
- priority or authority from arrival order
- a conventional Account object as the physical primitive
- a stored Envelope balance as the live-holdings source of truth
- one mandatory transaction/event nominal sum type for household roles
- eager referential rejection as a raw relation-memory rule
- autonomous recovery metadata
- concurrent-writer locking semantics
- fsync or power-loss durability guarantees
- a manifest or generation selector
- Resolution persistence protocol parity with Correction
- compaction semantics

These are not rejected forever. They are simply not earned yet.

## 8. Tool roles after sixty observations

LOAM's method is now easier to state from evidence rather than intention.

### Alloy

Use when the question is primarily structural:

- can two worlds share one retained structure but differ in a future answer?
- is one relation independent of another?
- does removing a field collapse distinctions?
- can a familiar household noun remain a projection?

### J

Use when array shape, projection, quotienting, or information loss is the clearest form of the question.

J is not a mandatory second implementation of every Alloy observation.

### Lean 4

Use when a discovered law is worth preserving generally or when the practical typed core needs to embody an earned distinction.

Lean is both a proof environment and the current practical-core language.

### TLA+ / TLC

Use when the distinction depends on state transitions, temporal knowledge, operation order, or reachable intermediate states.

### Apalache

Use selectively with TLA+ when symbolic checking or inductive-invariant obligations add a distinct answer, as in Observation 060.

### SPIN / Promela

Use when explicit process interleavings and protocol order are the pressure point, as in Observation 059.

### miniKanren

Use when genuinely relational or backwards search adds something the other tools do not express as directly.

The rule remains:

> Using every tool is not a goal. A tool must earn its place in the question.

## 9. Current checkpoint

After Observation 060 and the first raw Correction-memory persistence step, LOAM has completed one full development loop:

```text
question
  -> structural observation
  -> counterexample or law
  -> protocol observation when needed
  -> practical Lean boundary
  -> persistence
```

This is a good stopping point before choosing Observation 061.

A natural next pressure is whether a multi-parent Resolution can use the same split-publication protocol as a single Correction, or whether whole-frontier settlement introduces a stronger requirement. That question should be observed before copying the Correction persistence protocol mechanically.
