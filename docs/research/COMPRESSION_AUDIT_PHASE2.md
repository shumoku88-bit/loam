# Compression audit Phase 2 — retained meaning

Status: **IN PROGRESS — FIRST SEMANTIC PASS**

Baseline for this pass: current PR merge against main `43ac786ced90eac685148992105f87d906d79b7b` (`fix(cli): route Scheduled wrapper through Movement manifest (#536)`).

Phase 1 established that physical/runtime size is real: 21,226 lines across 134 executable-reachable practical Lean files. Phase 2 deliberately stops treating files, structures, and helper types as concept counts.

The unit of audit is now split into three axes:

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

## First confirmed fact/policy families

The table below is intentionally conservative. It lists meanings whose own source text or current authority boundary explicitly says the evidence is independently retained. It does not yet claim this list is minimal.

| Family | Retained meaning | Current physical relation |
| --- | --- | --- |
| Event | one observed Actual occurrence with detailed signed Effects | Movement manifest family |
| Actual validity provenance | occurrence-valid coordinate facts plus append-only validity correction provenance | Movement manifest family |
| Event description | Event-scoped human recognition text | Movement manifest family |
| RelationUnit | directional open-relation candidate anchored to observed Effect | Movement manifest family |
| RelationDischarge | exact fulfillment quantity from later Event to retained relation | Movement manifest family |
| Locus admission | current finite vocabulary permitted for new quantity-bearing writes | Movement manifest policy family |
| Actual routing assertion | Locus routing to Purpose over effective coordinates | independent Actual-routing authority |
| Zero-origin coverage | explicit coordinates whose selected retained history is complete from zero | independent coverage evidence |
| Capacity movement | allocation/spending-authority movement, distinct from physical holdings | independent Capacity authority |
| Capacity effective coordinate | effective day attached to Capacity movement | adjacent independent evidence stream |
| Attention item | household matter needing possible action, including three-way due meaning | Attention complete image |
| Attention closure | explicit resolved/dropped lifecycle evidence with knowledge coordinate | same Attention complete image, distinct meaning |
| Scheduled occurrence | expected balanced movement at scheduled coordinate | Scheduled lifecycle image |
| Scheduled completion | explicit Scheduled -> Actual realization correspondence | Scheduled lifecycle image |
| Scheduled retirement | explicit evidence that expectation is no longer future-open | Scheduled lifecycle image |
| Scheduled replacement | explicit Scheduled -> Scheduled supersession provenance | Scheduled lifecycle image |
| Scheduled routing assertion | ScheduledId × LocusId routing to Purpose over effective dates | independent Scheduled-routing authority |

This produces a **first-pass upper inventory of 17 retained fact/policy kinds**, not a claim that LOAM's minimal semantic basis is 17. Phase 2 must still challenge each row for reconstructability and overlap.

### Why Event and Effect are not counted separately here

`Effect` is retained detailed content inside an `Event`; the current Event persistence explicitly preserves every Effect so aggregate quantities can be recomputed. The audit therefore treats Event-with-Effects as one retained occurrence family for this first pass rather than inflating the count by every nested identity/value type.

### Why Movement manifest is not one semantic fact

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

### Why Scheduled lifecycle is four meanings but one physical image

Observation 226 selected one complete physical image containing Scheduled occurrence, completion, retirement, and replacement evidence. Its persistence module explicitly keeps the four fact families semantically distinct. Scheduled routing remains a separate authority because no observed requirement couples routing publication atomically to lifecycle publication.

This is a useful compression success already present in main:

```text
4 semantic fact kinds
1 lifecycle authority image
1 thin outer persistence frame
```

It demonstrates the kind of distinction this audit wants: preserve semantic multiplicity while compressing physical mechanics.

## Types currently not counted as additional retained meaning

### Derived/current projections

The following are currently treated as derived views or result vocabulary, not independent retained fact kinds:

- `ActualValidityMemory`: admitted current one-valid-coordinate-per-Event view derived from raw `ActualValidityHistory` provenance;
- `RoutingStatus` and `RoutingEffective`: selection/result or coordinate vocabulary around retained routing assertions;
- `CorrectedEvent`, `UnresolvedCorrection`, `ResolvedCorrection`: correction-frontier projections;
- Application `*Inspection` and `*Frontier` result structures;
- balance, consumption, commitment, remaining/headroom, and report-shaped answers when reconstructed from upstream evidence.

This classification must be revised if any current publisher persists one of these answers as authority.

### Reusable mechanics/algebra

These are not counted as household facts merely because they are Core modules:

- `Quantity` / `Amount` exact arithmetic;
- `BalancedMovement` and `MovementChange` zero-total algebra;
- collection uniqueness carried by `*Memory` wrappers;
- `RelationAdmission` reference checks;
- `CorrectionQuantity` effective quantity calculation;
- `RoutingHistory` latest-visible selection mechanics, considered separately from each concrete routing authority.

Phase 3 will ask whether these mechanics are factored enough or still reimplemented under domain-specific wrappers.

## Active Core vocabulary that is not yet current-authority fact inventory

Several executable-reachable Core declarations remain deliberately outside the 17-row inventory until their current authority role is resolved:

- `EventCorrection` / `EventCorrectionMemory`;
- `EventResolution` / `EventResolutionMemory`;
- `AttentionRelation`;
- `RelationRevision`.

Reasons differ. Event correction has a retained/persisted historical practical path but is not part of the current Movement manifest world. Event resolution is active Core/projection vocabulary but is not among the executable-reachable persistence modules reported by the semantic-candidate scan. `AttentionRelation` is qualified Core vocabulary, while the current Attention persistence image stores only items and closures and the current inspection intentionally ignores relation provenance. `RelationRevision` is present in Core, while current open-relation persistence explicitly stores raw `RelationUnit` values only and states that revisions are not persisted.

These are high-value Phase 2 questions because they can reveal either:

- genuine semantic capability waiting for an authority path;
- reusable theorem/projection vocabulary that belongs outside the production fact basis;
- or production-surface residue that later phases should retire or relocate.

No conclusion is made yet.

## Practical Core umbrella mismatch

Phase 1 reachability found a useful structural mismatch.

`Loam.Core` imports and presents itself as the practical Core entry point, but currently includes four modules that no executable reaches:

- `AccountingRole`
- `Allocation`
- `Rate`
- `RecipientAssignment`

At the same time, executable-reachable Scheduled Core modules are not imported by `Loam.Core` at all; they enter production through direct Application/Persistence/frontend imports.

This means the umbrella is not currently a faithful description of the production semantic closure.

The four library-only modules are not equivalent cases:

- `Rate`, `Allocation`, and `RecipientAssignment` are calculation kernels and explicitly describe intermediate/runtime calculation rather than retained household authority;
- `AccountingRole` describes a partial Locus classification relation and calls itself a current production boundary, but its persistence module and Core module are not reached by any current executable. That documentation/reachability tension must be resolved before it is counted as current production meaning.

This mismatch is an audit finding, not yet a deletion or import-expansion recommendation.

## Early semantic compression findings

### F2.1 — memory/file multiplication substantially overstates meaning

Examples:

```text
CapacityMovement
CapacityMemory
CapacityPersistence
CapacityPublisher
CapacityInspection
```

are not five independent household concepts. The confirmed retained meaning is the Capacity movement family; memory, persistence, writer, and inspection are different implementation roles around it. `CapacityEffective` adds one genuinely independent coordinate fact, so Capacity currently has at least two retained meanings rather than one per file.

Likewise:

```text
ActualValidityHistory -> raw retained provenance
ActualValidityMemory  -> current admitted projection
```

is one provenance family plus a derived current view, not two independent canonical facts.

### F2.2 — some semantic multiplicity is intentional and cannot be erased by genericization

Scheduled completion, retirement, and replacement are structurally small relations but answer different historical questions. Routing uses shared `RoutingHistory` mechanics while Actual and Scheduled retain separate subject spaces and physical authorities. Current evidence therefore supports shared mechanics without merged semantic authority.

### F2.3 — current complexity is not only a large ontology

The first pass finds far fewer retained meaning families than executable-reachable files. Even the provisional 17-family upper inventory is an order of magnitude below 134 runtime files.

That shifts some pressure toward Phase 3:

> If the retained information basis is roughly in the tens rather than the hundreds, why does realizing it require 134 executable-reachable Lean files and more than 21k lines?

This does not prove accidental complexity. It makes mechanism multiplication the next thing that must be measured.

## Remaining Phase 2 work

Before closing this phase:

1. resolve the current-authority status of EventCorrection, EventResolution, AttentionRelation, and RelationRevision;
2. test every one of the 17 provisional fact/policy kinds against the four audit questions: household answer, reconstructability, semantic distinguishability, and state-vs-projection;
3. determine whether Actual and Scheduled routing are one fact kind with two authority instances or should remain two fact kinds in the final semantic basis count;
4. classify `AccountingRole` as current production meaning, qualified-but-unwired future/report meaning, or residue;
5. produce a final finite semantic basis statement without relying on module names.

No production deletion or genericization belongs in Phase 2.
