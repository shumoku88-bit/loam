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

## Finding 6 — physical absence has no single semantic meaning

A census of current production boundaries shows that `file does not exist` is
not one stable semantic operation in LOAM.

| Family / source | Selected current encoding | Missing behavior in representative current operation |
| --- | --- | --- |
| Movement generation | `movement-authority/CURRENT` + selected objects | selected authority unavailable; no sidecar fallback |
| EventCorrection | optional `corrections.loam` | Balance, current coverage and Correction publication construct explicit empty correction history |
| ActualReversal | `actual-reversals.loam` | Correction/Reversal publication refuses because Reversal independence is unavailable |
| ZeroOriginCoverage | `zero-origin-coverage.loam` | Balance loader constructs empty coverage; selected covered questions then report missing coverage |
| Capacity | `capacity.loam` | all-retained Capacity review/publisher may initialize empty; current-coverage review requires the file |
| CapacityEffective | derived `capacity.loam.effective` | publisher may start from empty companion evidence; current-coverage review requires the file and complete pairing |
| ActualRouting | `actual-routing.loam` | writer may initialize empty history; administration/current-coverage review requires the file |
| Scheduled lifecycle | `scheduled.loam` typed complete image | missing image is unavailable, not empty household lifecycle |
| ScheduledRouting | `scheduled-routing.loam` | publisher/current coverage require explicit authority |
| AccountingRole | `accounting-role.loam` | publisher/reviews require explicit authority |
| Attention | optional `attention.loam` | review returns explicit source `unavailable`, not empty Attention lifecycle |

This is not automatically a bug. Different questions can legitimately require
different evidence strength.

But it proves an important audit fact:

```text
physical absence
    != one semantic bottom value
```

and even one family can have operation-relative behavior. For example, a missing
Capacity file is an empty all-retained history for the simple Capacity review but
is unavailable to the stronger current-coverage query.

Therefore the audit must not encode semantic state as `pathExists` itself.
Physical absence is one current representation input whose meaning is selected by
the operation contract.

### Topology-neutral Q rule

This prevents a circular audit.

The current operation vocabulary must retain distinctions such as:

```text
known empty
unavailable
incomplete
malformed
available with evidence
```

when a household/safety operation independently observes them.

It must **not** automatically retain representation observations such as:

```text
file X exists
file X has this sibling name
this exact path is missing
this exact error string mentions a filename
```

Otherwise the present topology would prove its own necessity.

## Finding 7 — current semantic count and physical file count already diverge

The exact current mapping is useful because it demonstrates that LOAM already
contains several different authority styles.

A working census of currently retained household meaning gives approximately 18
semantic families before the #693 indispensability audit closes every row:

```text
Movement selected image:
  Event
  ActualValidity
  EventDescription
  RelationUnit
  RelationDischarge
  LocusAdmission

independent/current meanings:
  EventCorrection
  ActualReversal
  ActualRouting
  ZeroOriginCoverage
  CapacityMovement
  CapacityEffective
  AccountingRole

Scheduled lifecycle image:
  ScheduledOccurrence
  ScheduledCompletion
  ScheduledRetirement
  ScheduledReplacement

independent ScheduledRouting
```

`Attention` is not currently present in `loam-data`; the production Attention
reader therefore observes source unavailability rather than selected retained
Attention evidence. It should not be counted as current retained household state
merely because Core/Application support exists.

The current selected/current **existing evidence-file** footprint is roughly 15
files, excluding configuration, request transport, documentation and off-authority
recovery roots:

```text
8 root evidence files
  accounting-role.loam
  actual-reversals.loam
  actual-routing.loam
  capacity.loam
  capacity.loam.effective
  scheduled.loam
  scheduled-routing.loam
  zero-origin-coverage.loam

7 Movement selected artifacts
  movement-authority/CURRENT
  + six CURRENT-selected object images
```

`corrections.loam` contributes a semantic empty Correction authority while being
physically absent in the current snapshot.

So even before any redesign:

```text
semantic family count != physical file count
```

and the ratios vary sharply:

```text
6 Movement meanings  -> 7 selected files
4 Scheduled meanings -> 1 file
2 Capacity meanings  -> 2 files
1 empty Correction meaning -> 0 files
```

This destroys any simple argument from semantic distinctness to file count.

### Adjacent but non-canonical physical state

The Movement authority also currently retains two off-authority recovery manifest
files. They are not selected household fact authority, but they are operational
recovery roots consumed by the Doctor/recovery path and therefore belong in a
later safety-topology audit rather than being counted as semantic facts.

The current `config/` directory contains five replaceable configuration/metadata
files. Those are similarly outside the retained household-fact count unless a
historical query earns their past values.

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
   layer and therefore create real change fanout;
7. missing-file behavior is an encoding convention, not a universal semantic
   state;
8. current semantic families already map many-to-one, one-to-many, and even
   one-to-zero onto physical files.

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
