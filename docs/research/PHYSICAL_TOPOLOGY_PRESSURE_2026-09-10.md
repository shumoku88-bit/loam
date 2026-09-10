# Physical topology pressure checkpoint — 2026-09-10

Status: **evidence checkpoint for #693; no file migration authorized**

Baseline reviewed: `9d11b5413bc353d1e596aa7e839ee281cd28e613`

## Question

After separating retained semantic meaning from authority state, is current LOAM
also allowing physical file layout to shape higher-level design?

This checkpoint records production evidence for that pressure. It deliberately
does not conclude that any current file should already be merged or removed.

## Finding 1 — Correction discovers Reversal authority from a sibling filename

`CorrectionPublisher.publishUnderOwnership` is supplied:

```text
Movement manifest root
Correction file
```

It then derives another semantic dependency through physical placement:

```lean
let reversalFile := correctionFile.withFileName "actual-reversals.loam"
```

The Correction semantic rule is real: it must know whether the target or proposed
replacement participates in retained Reversal evidence, and missing Reversal
authority currently fails closed.

But this code couples that semantic dependency to the proposition:

```text
Reversal authority == sibling file named actual-reversals.loam
```

Those are not the same statement.

Classification:

```text
ActualReversal semantic dependency        EARNED
known-empty vs unavailable distinction    EARNED
specific sibling filename                 PHYSICAL REPRESENTATION PRESSURE
```

## Finding 2 — CapacityEffective is semantically independent but physically path-derived

`CapacityEffective` is independently observable. Observation 243 supplies a
current-production witness: the same Capacity movement with a different effective
coordinate changes a windowed Entitlement answer.

Physical discovery is nevertheless derived from the Capacity filename:

```lean
def capacityEffectivePathForMemory (capacityPath) :=
  capacityPath.toString ++ ".effective"
```

Production reviews repeat this shape by starting from `capacity.loam` and deriving
`capacity.loam.effective`.

Again the semantic law and the filename law are different:

```text
Capacity movement and its effective coordinate are distinct retained meanings

-/->

they require two independently named physical authorities
```

## Finding 3 — the two Capacity files already share one writer-ownership boundary

`CapacityPublisher.publish` takes only the Capacity path and acquires writer
ownership on that path.

Inside that one ownership window it:

1. derives the `.effective` companion path;
2. re-reads both images;
3. requires evidence completeness in both directions;
4. allocates one fresh movement identity across both images;
5. writes effective evidence first;
6. writes Capacity movement authority second.

The stated crash rule is:

```text
publish dependent effective evidence
    -> publish activating Capacity movement
```

A crash after step 5 may leave dangling effective evidence, but it remains inert
because the activating movement has not appeared. Later writes detect incomplete
evidence and fail closed.

This means the important safety boundary is already expressed as:

```text
one writer ownership domain
+ one activation order
```

not as two independent concurrent writer domains.

The current two-file shape is one implementation of that law.

## Finding 4 — Reversal uses the same activation-point pattern

Actual reversal publication similarly retains two facts:

```text
ActualReversal relation
inverse Actual Event
```

It publishes the relation first and selects the Movement generation containing
the inverse Event second. A dangling relation is inert; an inverse Event without
its provenance would already change physical quantity.

So both Capacity and Reversal exhibit the same deeper shape:

```text
dependent evidence
    -> activation anchor
```

PR #692 / Observation 240 is independently extracting that publication law from
current writers. If that law survives review, it is further evidence that the
safety principle is more general than the current filenames carrying it.

## Finding 5 — physical topology is visible above persistence

The pressure is not confined to codecs.

Production read/review code constructs paths such as:

```text
dataDir / "capacity.loam"
dataDir / "actual-routing.loam"
dataDir / "corrections.loam"
dataDir / "scheduled.loam"
```

and then derives companion evidence paths where required.

The TUI similarly passes these concrete paths into sessions and reloaders.

That means physical layout participates in application/runtime wiring. A later
change from two files to one image, one directory, or another authority layout
therefore fans out into callers even when the retained semantic basis is
unchanged.

This is exactly the condition worth testing under #693:

> Has physical persistence topology become an accidental source of application
> architecture?

## What is already supported

The current evidence supports these narrower conclusions:

1. semantic-family count is not file count;
2. `ActualReversal` known-empty/unavailable semantics do not by themselves prove
   a dedicated `actual-reversals.loam` file;
3. `CapacityEffective` indispensability does not by itself prove a `.effective`
   companion file;
4. Capacity's two physical files currently share one writer-ownership domain;
5. important crash safety is stated in terms of dependent evidence and activation
   order;
6. filenames and companion-path conventions are visible above the persistence
   layer and therefore create real change fanout.

## What is not yet supported

Do **not** infer yet that:

- `capacity.loam` and `capacity.loam.effective` should be merged;
- Reversal should be embedded in Correction or Movement;
- every authority should become one household file;
- one universal manifest or repository abstraction is needed;
- fewer files are automatically safer or simpler.

A merged image changes atomicity and corruption/failure scope. Those properties
still need explicit witnesses.

## Next physical-topology test

After the semantic indispensability table is sufficiently closed, compare at
least these representations while holding retained meaning constant:

```text
A. current companion sidecars
B. one atomic family image with typed sections
C. independently named files selected through one explicit authority descriptor
```

For each candidate measure:

```text
Q-observable semantic parity
crash-prefix closure
known-empty vs unavailable preservation
stale-writer behavior
corruption blast radius
independent update requirements
recovery complexity
number of physical-layout assumptions visible above persistence
```

The last metric matters. If two representations preserve the same semantics and
safety but one forces many application modules to know filenames, that fanout is
real architectural cost even when byte count is tiny.

## Working hypothesis

The emerging pressure is not simply "LOAM has too many files".

It is more precise:

> Some independently retained meanings appear to have been given physical
> sidecars, and those sidecars then leaked upward as path-derived dependencies.
> The semantic distinction may be necessary while the resulting physical and
> architectural distinction is not.

This remains a hypothesis until the topology comparison preserves all current
observable and failure properties.
