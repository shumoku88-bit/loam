# Application 018: Primary practical protocol cost map

## Pressure

Application 016 found that obvious mechanical duplication explains only a small
fraction of LOAM's CLI size. Application 017 then separated the 308,002-byte
`Loam/Cli*` source set and found that 209,151 bytes belong to the current primary
practical CLI closure.

The next question is narrower:

```text
what kind of work occupies that 209,151-byte primary closure?
```

The purpose is not to reward the shortest source. The purpose is to locate the
cost that would have to change for a *meaningful* production compression while
keeping authority and failure behavior visible.

The production source measured here is still the fixed `main` snapshot:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

and this application is stacked after Application 017 at:

```text
99e835335692f441ffca71e46f0913541ddad814
```

No production source or household data is changed.

## Method: module-dominant cost, not false lexical precision

A single CLI file can contain prompts, projection, validation, identity
allocation, and publication. Assigning every source byte to one semantic action
would require arbitrary line-level accounting and would overstate precision.

This observation therefore uses a deliberately coarse unit:

```text
whole CLI module
-> dominant runtime contract
```

The classifications are:

1. **mutation / admission / recovery dominant** — the module's main contract is
   to admit, correct, complete, retire, or otherwise publish canonical evidence;
2. **read / projection / presentation dominant** — the module loads retained
   evidence and derives or renders a view without publishing canonical facts;
3. **shell / dispatch dominant** — the module mainly exposes commands and
   delegates to narrower entrances;
4. **mixed** — the module intentionally contains both a meaningful writer and a
   meaningful read/workbench path, so forcing it into one side would be
   misleading.

The resulting percentages are source-location facts, not a claim that every byte
inside a mutation-dominant module is mutation logic.

## Primary closure snapshot

Application 017 established the exact 14-module primary closure:

```text
Loam/Cli.lean                              12,262
Loam/Cli/MovementCli.lean                  29,456
Loam/Cli/CapacityCli.lean                  14,534
Loam/Cli/DailyQuantityCli.lean             19,917
Loam/Cli/OpenScheduledCli.lean             10,782
Loam/Cli/ReviewCli.lean                    11,786
Loam/Cli/CorrectionCli.lean                23,897
Loam/Cli/ActualValidityCorrectionCli.lean  11,085
Loam/Cli/EffectiveCli.lean                  6,256
Loam/Cli/CorrectionIntegrityCli.lean        3,501
Loam/Cli/QuantityBasisCorrectionCli.lean    8,754
Loam/Cli/ScheduledCli.lean                 38,659
Loam/Cli/ScheduledLifecycleCli.lean        14,034
Loam/Cli/ScheduledBalanceCli.lean           4,228
                                             -------
                                             209,151 bytes
```

## Mutation / admission / recovery dominant modules

The following six modules are dominated by canonical mutation and its safety
protocol rather than by read-only presentation:

```text
MovementCli.lean                  29,456
CorrectionCli.lean                23,897
ActualValidityCorrectionCli.lean  11,085
QuantityBasisCorrectionCli.lean    8,754
ScheduledCli.lean                 38,659
ScheduledLifecycleCli.lean        14,034
                                  -------
                                  125,885 bytes
                                  60.2% of primary CLI closure
```

This is already a majority before counting any writer logic in the mixed
Capacity and DailyQuantity modules.

The three largest files alone are:

```text
ScheduledCli + MovementCli + CorrectionCli
= 92,012 bytes
= 44.0% of the entire primary CLI closure
```

So the present size is not principally explained by the review screen, command
dispatch, or display formatting.

## Why these writer modules are expensive

The source inspection shows a recurring safety shape, but with different
semantic authority in each writer:

```text
preflight retained evidence
-> collect human draft without holding writer ownership
-> re-read authoritative evidence under ownership
-> reserve identities against all relevant retained streams
-> admit the proposed semantic facts
-> publish supporting evidence in a safe order
-> publish the activating authority last when required
-> leave earlier residue inert and resumable on interruption
```

The important finding is that the cost is not merely `save file` boilerplate.
It is the explicit representation of what partial publication means.

### Movement fan-out

The current practical Movement publisher may publish, in order:

```text
ActualValidity
-> optional EventDescription
-> optional RelationUnit evidence
-> optional RelationDischarge evidence
-> EventMemory authority
```

The Event is intentionally last. If description, relation, or discharge
publication fails, earlier evidence remains inert because the Event has not
activated it. Event identity allocation also reserves identities appearing in
raw relation/discharge residue so later unrelated movements cannot accidentally
activate an interrupted publication.

### Scheduled completion fan-out

Scheduled completion may publish:

```text
ScheduledCompletion relation
-> ActualValidity
-> optional EventDescription
-> EventMemory authority
```

The implementation also distinguishes human draft from authority, supports
retained evidence from an interrupted completion, and re-reads current state
under writer ownership before activation.

`ScheduledLifecycleCli` adds another cross-authority condition: Scheduled
ownership is acquired before EventMemory ownership, terminal completion and
retirement evidence must remain compatible, and a stale human draft must not
cross a concurrent cancellation.

### Correction fan-out

Event correction publishes:

```text
EventCorrection relation
-> optional replacement ActualValidity
-> replacement Event
```

A dangling correction relation remains resumable rather than acquiring authority
from arrival order. The replacement Event is last so a relation or date alone
cannot make a partially evidenced replacement current.

### Other mutation examples

`ActualValidityCorrectionCli` is physically simpler because it publishes one
validity-history stream, but it still constructs append-only replacement facts
and correction relations and admits one current validity frontier before write.

`QuantityBasisCorrectionCli` publishes the correction relation before the
replacement basis. A failed later basis publication leaves a relation that is
inactive until its referenced replacement appears.

These are different household protocols even though they share a crash-safety
family resemblance. Application 016's rule still applies:

```text
same control-flow silhouette != same semantic operation
```

## Read / projection / presentation dominant modules

Four modules are primarily read-side:

```text
ReviewCli.lean               11,786
EffectiveCli.lean             6,256
CorrectionIntegrityCli.lean   3,501
ScheduledBalanceCli.lean      4,228
                              ------
                              25,771 bytes
                              12.3% of primary CLI closure
```

`ReviewCli` explicitly constructs transient presentation records and never uses
them for writer admission. `EffectiveCli` delegates quantity semantics to the
Application inspection boundary and refuses unsupported correction frontiers
before printing a partial result.

This does not mean the read side is free of meaningful safety. It still performs
whole-view admission and fail-closed rendering. But even deleting every one of
these modules would leave most of the primary CLI source intact.

That falsifies a tempting explanation:

```text
primary CLI size ~= terminal presentation bulk
```

The current source does not support that claim.

## Shell / dispatch dominant module

`Loam/Cli.lean` occupies:

```text
12,262 bytes
5.9% of primary CLI closure
```

It exposes practical and low-level commands and delegates correction, review,
Scheduled lifecycle, and other operations to narrower modules. It still contains
some low-level Event utilities, so this is not a claim that all 12,262 bytes are
pure command parsing. The dominant role is nevertheless shell/dispatch.

A large framework rewrite of this file cannot explain or remove the majority of
current production cost.

## Mixed modules

Three files intentionally combine more than one live role:

```text
CapacityCli.lean       14,534
DailyQuantityCli.lean  19,917
OpenScheduledCli.lean  10,782
                       ------
                       45,233 bytes
                       21.6% of primary CLI closure
```

### CapacityCli

Capacity contains both:

- a dated Capacity writer with identity reservation, effective-evidence
  completeness, writer ownership, and effective-evidence-before-authority
  publication;
- read-only entitlement projections for all history and explicit date windows.

### DailyQuantityCli

DailyQuantity contains both:

- the starting QuantityBasis writer;
- current/balance projections over basis, basis correction, basis cut, Event,
  and Event correction evidence.

It also delegates append-only basis correction to
`QuantityBasisCorrectionCli`.

### OpenScheduledCli

OpenScheduled derives the current open Scheduled set and renders the workbench,
but the interactive workbench delegates Add, Complete, and Cancel to the
Scheduled writer modules. It is therefore neither a pure projection nor an
independent writer.

## Module-dominant protocol cost map

The complete primary CLI partition is:

```text
mutation/admission/recovery dominant  125,885 bytes   60.2%
read/projection/presentation dominant  25,771 bytes   12.3%
shell/dispatch dominant                12,262 bytes    5.9%
mixed                                   45,233 bytes   21.6%
                                      -----------     -----
total                                   209,151 bytes  100.0%
```

The important interpretation is directional rather than falsely precise:

```text
60.2% is already located in mutation-dominant modules
+
part of the 21.6% mixed slice is also mutation protocol
```

Therefore publication/admission/recovery is the strongest current explanation
for primary CLI bulk.

## A stronger correlation: evidence-stream fan-out

The largest mutation paths are also the paths that coordinate several separately
persisted evidence streams.

Current examples include:

```text
Movement completion      up to 5 publication streams
Scheduled completion     up to 4 publication streams
Event correction         up to 3 publication streams
Capacity movement        2 publication streams
QuantityBasis correction 2 publication streams
```

Each additional stream is not merely another encoder call. Once a household
operation spans separately persisted authorities, the writer must answer:

```text
which evidence is supporting?
which evidence activates meaning?
what order is crash-safe?
what residue is legal after interruption?
how is that residue recognized on retry?
which identities must remain reserved while residue is inert?
```

This suggests that physical evidence topology is a more promising compression
pressure than terminal helper duplication.

It does **not** yet prove that the current multi-stream topology is wrong.
Semantic separation between Event, validity, description, relation, discharge,
Scheduled completion, and correction remains valuable. Physical co-location and
semantic identity are different questions.

## What compression is actually available now?

This observation does not overturn Application 016's small safe refactor:
`promptLine`, EventDescription input, and trivial list selection may still be
shared or deleted as hygiene.

But that work cannot materially change the size profile.

For a large reduction, at least one of the following would have to become true:

1. a currently explicit recovery rule can be derived from retained evidence and
   deleted;
2. a fresh-identity reservation rule can be simplified without permitting
   orphan residue to bind to a later fact;
3. several physical publications can share one crash boundary while semantic
   facts remain separately typed;
4. a practical operation can be represented by fewer canonical evidence streams
   without losing an independently meaningful fact.

Only (1) or (4) are directly semantic compression. (2) and (3) are protocol or
physical-storage compression. They should not be conflated.

## Next pressure: physical publication topology

The strongest next observation is therefore not a generic CLI framework. It is:

```text
Does LOAM need several physical files to preserve several semantic fact families?
```

A useful future comparison would keep the current semantic facts fixed and vary
only the physical publication mechanism, for example:

```text
A. current separate streams + ordered publication
B. one append-only typed fact stream, semantic families still distinct
C. separate streams plus one explicit commit/bundle boundary
```

Then compare, under interruption and retry:

- atomic visibility;
- inert residue;
- identity reservation requirements;
- append-only provenance;
- independent correction frontiers;
- recovery code required by practical writers;
- ability to inspect or migrate one fact family independently.

Because this is a crash/interleaving question, TLA+ or a small state-transition
model may be a better instrument than source inspection alone if that comparison
is pursued.

No candidate is selected by Application 018.

## What this does and does not earn

Application 018 earns three conclusions:

1. primary CLI size is not mainly a terminal-presentation problem;
2. the majority of source is located in modules dominated by mutation,
   admission, and recovery, with additional writer code in the mixed slice;
3. the largest writer protocols correlate with cross-stream ordered publication
   and explicit interrupted-state semantics.

It does not earn:

- a generic writer framework;
- a global identity allocator;
- merging semantic fact families;
- one universal persistence file;
- deletion of recovery checks;
- a production refactor in this PR.

## Qualification

No new household law is proposed here, so no new formal Observation number is
required.

Qualification consists of:

- the exact primary CLI closure fixed by Application 017;
- Git blob sizes on the same `main` snapshot;
- direct source inspection of the primary mutation and read paths;
- explicit publication-order inspection in Movement, Scheduled completion,
  Event correction, Capacity, and QuantityBasis correction;
- preserving Application 016's semantic-abstraction guard;
- no production, persistence, canonical fact, executable behavior, or private
  household data changes.
