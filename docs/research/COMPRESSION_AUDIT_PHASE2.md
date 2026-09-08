# Compression audit Phase 2 — retained meaning

Status: **COMPLETE — CURRENT SEMANTIC BASIS INVENTORY**

Baseline for this pass: current PR merge against main `43ac786ced90eac685148992105f87d906d79b7b` (`fix(cli): route Scheduled wrapper through Movement manifest (#536)`).

Phase 1 established that physical/runtime size is real: 21,226 lines across 134 executable-reachable practical Lean files. Phase 2 deliberately stops treating files, structures, and helper types as concept counts.

The unit of audit is split into three axes:

```text
fact kind          independently retained household meaning or policy

authority instance physical/current source that decides which retained image is selected

mechanism          reusable algebra, admission, selection, memory, codec, or publication behavior
```

One fact kind may have several authority instances. One authority image may contain several semantically distinct fact kinds. One mechanism may implement several fact kinds without merging their meaning.

## Rules for counting meaning

Do **not** count these as independent fact kinds merely because they have their own Lean types/files:

- identity wrappers;
- `Memory` containers whose only added law is collection uniqueness;
- read-only projections such as current/effective/conflict views;
- algebraic carriers used by several semantic families;
- persistence codecs;
- UI-local state;
- authority packaging such as a manifest or complete-image frame.

A fact kind counts only when removing it would erase an independently observable household distinction that cannot be reconstructed from the remaining retained evidence.

## Current retained fact/policy families

The current production basis has **18 retained fact/policy families** under this audit definition:

| # | Family | Retained meaning | Current physical relation |
| ---: | --- | --- | --- |
| 1 | Event | one observed Actual occurrence with detailed signed Effects | Movement manifest family |
| 2 | Actual validity provenance | occurrence-valid coordinate facts plus append-only validity correction provenance | Movement manifest family |
| 3 | Event description | Event-scoped human recognition text | Movement manifest family |
| 4 | RelationUnit | directional open-relation candidate anchored to observed Effect | Movement manifest family |
| 5 | RelationDischarge | exact fulfillment quantity from later Event to retained relation | Movement manifest family |
| 6 | Locus admission | current finite vocabulary permitted for new quantity-bearing writes | Movement manifest policy family |
| 7 | EventCorrection | explicit original -> replacement interpretation relation | independent correction authority coordinated with Movement publication |
| 8 | Actual routing assertion | Locus routing to Purpose over effective coordinates | independent Actual-routing authority |
| 9 | Zero-origin coverage | explicit coordinates whose selected retained history is complete from zero | independent coverage authority |
| 10 | Capacity movement | allocation/spending-authority movement, distinct from physical holdings | independent Capacity authority |
| 11 | Capacity effective coordinate | effective day attached to Capacity movement | adjacent independent authority |
| 12 | Attention item | household matter needing possible action, including three-way due meaning | Attention complete image |
| 13 | Attention closure | explicit resolved/dropped lifecycle evidence with knowledge coordinate | same Attention complete image, distinct meaning |
| 14 | Scheduled occurrence | expected balanced movement at scheduled coordinate | Scheduled lifecycle image |
| 15 | Scheduled completion | explicit Scheduled -> Actual realization correspondence | Scheduled lifecycle image |
| 16 | Scheduled retirement | explicit evidence that expectation is no longer future-open | Scheduled lifecycle image |
| 17 | Scheduled replacement | explicit Scheduled -> Scheduled supersession provenance | Scheduled lifecycle image |
| 18 | Scheduled routing assertion | ScheduledId × LocusId routing to Purpose over effective dates | independent Scheduled-routing authority |

This is a statement about the **current production semantic basis**, not a metaphysical minimum for all future household systems. Later audit phases may still show that a fact family is obsolete or that a stronger representation reconstructs it without information loss.

### EventCorrection is current authority, not only historical vocabulary

The first pass left EventCorrection unresolved because it is not inside the Movement manifest world. Current `CorrectionPublisher`, however, explicitly loads a separate `EventCorrectionMemory`, prepares a replacement Movement generation, publishes a fresh correction relation first, and then switches Movement `CURRENT`. A single interrupted relation-first publication is resumable.

Therefore EventCorrection is independently retained current evidence and belongs in the production fact basis even though its physical authority is separate from the Movement manifest.

The older line-oriented correction CLI still contains sidecar-era behavior, and the practical shell menu refuses several of those actions when manifest authority is selected. That is a later implementation-surface question, not evidence that the correction fact itself is obsolete.

## Current physical authority instances

The 18 semantic families are currently selected through approximately **9 physical authority instances**:

1. Movement manifest `CURRENT`, containing Event, ActualValidity, EventDescription, RelationUnit, RelationDischarge, and LocusAdmission families;
2. EventCorrection authority;
3. Actual routing authority;
4. zero-origin coverage authority;
5. Capacity movement authority;
6. Capacity effective-coordinate authority;
7. Attention complete image;
8. Scheduled lifecycle complete image;
9. Scheduled routing authority.

This count is deliberately about selected physical authority, not files. Content-addressed Movement objects, inner codecs, staging files, and manifest sections do not each become another authority instance.

The compression pattern is already mixed:

```text
Movement: 6 meanings -> 1 selected authority
Scheduled lifecycle: 4 meanings -> 1 selected authority
Attention: 2 meanings -> 1 selected authority
Capacity: 2 meanings -> 2 authorities
Routing: shared mechanics -> 2 semantic authorities
Correction: 1 meaning -> separate authority coordinated with Movement
```

Phase 3 must ask which of these differences are earned by atomicity/semantic requirements and which are implementation history.

## Why Event and Effect are not counted separately here

`Effect` is retained detailed content inside an `Event`; current Event persistence preserves every Effect so aggregate quantities can be recomputed. The audit therefore treats Event-with-Effects as one retained occurrence family rather than inflating the count by nested identity/value types.

## Why Movement manifest is not one semantic fact

The current Movement manifest switches six typed family images together:

```text
Event
ActualValidity
EventDescription
RelationUnit
RelationDischarge
LocusAdmission
```

The authority module explicitly says the physical bundle does not merge those meanings into one semantic family. One atomic authority switch is therefore **one authority mechanism over six fact/policy families**, not one fact and not six publication mechanisms by definition.

## Why Scheduled lifecycle is four meanings but one physical image

Observation 226 selected one complete physical image containing Scheduled occurrence, completion, retirement, and replacement evidence. Its persistence module explicitly keeps the four fact families semantically distinct. Scheduled routing remains a separate authority because no observed requirement couples routing publication atomically to lifecycle publication.

This is a useful compression success already present in main:

```text
4 semantic fact kinds
1 lifecycle authority image
1 thin outer persistence frame
```

It demonstrates the target distinction: preserve semantic multiplicity while compressing physical mechanics.

## Four-question retention check

Every retained family was challenged against the Phase-2 questions.

### Actual / Movement family

- **Event**: without retained signed Effects, the observed physical quantity change itself disappears. It is base evidence, not a projection.
- **Actual validity provenance**: Event structure does not determine occurrence-valid coordinates, and later date correction requires retained provenance rather than mutation.
- **Event description**: human recognizer text is not derivable from quantities, identities, routing, or dates.
- **RelationUnit**: directional household open-relation meaning is not inferable from an Effect's sign or coordinate alone.
- **RelationDischarge**: exact partial fulfillment cannot be reconstructed from a later Event-to-relation association without the discharged quantity.
- **Locus admission**: historically observed Loci do not determine which Loci are currently permitted for new writes.
- **EventCorrection**: original and replacement Events alone do not identify that one corrects the other; the explicit relation carries that provenance.

### Routing / completeness

- **Actual routing**: historical Purpose assignment is not derivable from Locus spelling, Effect sign, current display state, or Event history.
- **Zero-origin coverage**: a finite Event history does not prove that an absent earlier quantity history is exactly zero; completeness evidence is independent.
- **Scheduled routing**: the ScheduledId × LocusId subject preserves intent that Actual Locus routing cannot reconstruct. It uses the same `RoutingHistory` mechanics without sharing semantic authority.

Actual and Scheduled routing therefore remain **two semantic fact families sharing one generic routing mechanism**. Combining them into one physical stream or tagged subject universe could preserve information in principle, but no current requirement earns that authority coupling. Phase 2 counts semantic distinctions, not generic type constructors.

### Capacity

- **Capacity movement**: allocation/spending authority is independently observable from physical holdings even though both reuse exact balanced movement algebra.
- **Capacity effective coordinate**: movement content alone does not determine when that capacity authority becomes effective.

### Attention

- **Attention item**: a household matter may exist before any financial Event, and its `dueOn / noDueDate / dueUndetermined` distinction cannot be reconstructed from financial evidence.
- **Attention closure**: relation provenance does not imply closure, and resolved vs dropped plus `knownOn` is independent lifecycle evidence.

### Scheduled lifecycle

- **Scheduled occurrence**: expected movement is not Actual evidence.
- **Scheduled completion**: matching date/amount/Locus shape does not identify which Actual realizes which Scheduled occurrence.
- **Scheduled retirement**: absence from an open view does not explain that an expectation was explicitly retired.
- **Scheduled replacement**: two Scheduled occurrences alone do not preserve which one superseded which earlier expectation.

All 18 therefore still pass the current independent-information test. Phase 2 found no semantic family that can be deleted solely from reconstructability arguments already available in main.

## Types not counted as additional retained meaning

### Derived/current projections

The following remain derived views or result vocabulary:

- `ActualValidityMemory`: admitted current one-valid-coordinate-per-Event view derived from raw `ActualValidityHistory` provenance;
- `RoutingStatus` and `RoutingEffective`: selection/result or coordinate vocabulary around retained routing assertions;
- `CorrectedEvent`, `UnresolvedCorrection`, `ResolvedCorrection`: correction-frontier projections;
- Application `*Inspection` and `*Frontier` result structures;
- balance, consumption, commitment, remaining/headroom, and report-shaped answers when reconstructed from upstream evidence.

### Reusable mechanics/algebra

These are not household facts merely because they are Core modules:

- `Quantity` / `Amount` exact arithmetic;
- `BalancedMovement` and `MovementChange` zero-total algebra;
- collection uniqueness carried by `*Memory` wrappers;
- `RelationAdmission` reference checks;
- `CorrectionQuantity` effective quantity calculation;
- `RoutingHistory` latest-visible selection mechanics.

Phase 3 must now measure whether these mechanics are sufficiently shared or repeatedly reimplemented around each semantic family.

## Qualified vocabulary without current production authority

Three executable-reachable Core families do **not** enter the 18-family current authority basis:

### EventResolution

`EventResolution` / `EventResolutionMemory` remain active Core and referential-admission vocabulary for explicit multi-parent correction-frontier settlement. No current `EventResolutionPersistence` module or selected production authority was found. It reaches executables through shared correction/relation admission dependencies, not through a current persistence/writer path.

Classification: **qualified semantic/projection capability, not current retained production authority**.

### AttentionRelation

`AttentionRelation` remains qualified Core provenance vocabulary, but current Attention persistence stores only items and closures, and current Attention inspection intentionally excludes relation provenance from lifecycle calculation.

Classification: **qualified but currently unwired provenance capability**.

### RelationRevision

`RelationRevision` remains Core vocabulary, while current open-relation persistence explicitly says it persists RelationUnit values only and does not persist RelationRevision.

Classification: **qualified but currently unwired revision capability**.

These types may still be useful laws or future pressure. Their existence must not inflate the current retained-fact count. Phase 4 may later ask whether their production-location cost is still earned.

## AccountingRole is qualified but not current executable authority

`AccountingRole` describes a partial `LocusId -> AccountingRole` classification and its source text calls this a current production boundary. A matching persistence codec exists.

However Phase 1 established that:

- `Loam/Core/AccountingRole.lean` is practical-library-only, not reached by any executable;
- `Loam/Persistence/AccountingRolePersistence.lean` is reached by neither an executable nor a practical library entrance.

Therefore the current repository has a **documentation/placement mismatch**: the concept is qualified and persistence-capable, but not part of the present executable household authority closure.

Classification for this audit: **qualified report/classification candidate, not current production fact basis**.

`Rate`, `Allocation`, and `RecipientAssignment`, which share the same practical-library-only Core status, are calculation kernels rather than retained authority and likewise do not enter the semantic fact count.

## Practical Core umbrella mismatch

`Loam.Core` presents itself as the practical Core entry point, yet it imports the four library-only modules above while executable-reachable Scheduled Core modules enter production through direct Application/Persistence/frontend imports and are not imported by the umbrella.

The umbrella is therefore not a faithful description of the executable semantic closure.

This is a structural audit finding. Phase 4 can later decide whether to shrink the umbrella, widen it, relocate qualified-but-unwired modules, or make another explicit boundary. Phase 2 does not prescribe that change.

## Phase 2 findings

### F2.1 — memory/file multiplication substantially overstates meaning

Examples such as:

```text
CapacityMovement
CapacityMemory
CapacityPersistence
CapacityPublisher
CapacityInspection
```

are not five independent household concepts. Capacity currently contributes two retained meanings: movement authority and effective coordinate. Memory, persistence, publisher, and inspection are implementation roles around them.

Likewise:

```text
ActualValidityHistory -> raw retained provenance
ActualValidityMemory  -> current admitted projection
```

is one provenance family plus a derived current view, not two canonical facts.

### F2.2 — semantic multiplicity is real but much smaller than file multiplicity

The current audit basis is:

```text
18 retained fact/policy families
9 physical authority instances
134 executable-reachable practical files
21,226 executable-reachable practical lines
```

The semantic basis is therefore far smaller than the implementation surface, even before any Phase-3 refactoring claim.

### F2.3 — some semantic partitions are intentionally preserved across shared mechanics

The strongest current examples are:

- Actual vs Scheduled routing: one `RoutingHistory` algebra, separate subject meaning and authority;
- physical Event vs Capacity movement: one balanced movement algebra where applicable, distinct semantic coordinates;
- Scheduled lifecycle: four meanings, one physical image;
- Movement manifest: six meanings, one selected generation.

This supports the existing principle:

```text
share algebra and mechanics
preserve semantic authority
```

but does **not** show that the surrounding implementation is already maximally factored.

### F2.4 — the next pressure is mechanism multiplication, not primitive count alone

Phase 2 did not find a 134-concept ontology hiding behind 134 executable-reachable files. It found a current retained basis in the tens.

The next question is therefore sharp:

> Why do 18 retained fact/policy families and roughly 9 selected physical authorities require 134 executable-reachable Lean files and more than 21k lines?

Possible answers include necessary fail-closed codecs, authority-specific publication laws, frontend/runtime adapters, proof-bearing admission, or accidental repeated mechanics. Phase 3 must distinguish them rather than guessing.

## Exit rule

**Satisfied.** The current production semantic basis can be stated without relying on module count, current-authority status has been separated from qualified-but-unwired vocabulary, routing-family sharing has been classified, and AccountingRole's documentation/reachability mismatch is explicit.

No production deletion or genericization has been performed in Phase 2.

The audit now advances to **Phase 3 — mechanics multiplication**.
