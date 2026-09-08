# LOAM Observation Map

Status: **CURRENT COMPRESSED CHECKPOINT THROUGH OBSERVATION 227**

This file is the current integrated map of LOAM's household research. It is deliberately not an observation-by-observation ledger. Detailed questions, witnesses, solver results, implementation probes, and historical wording remain in `experiments/`, `docs/research/`, and Git history.

The earlier detailed map through Observation 084 remains available in Git history. Replacing it with this shorter checkpoint is intentional: the map should describe the current terrain, not force every retired research apparatus to remain live forever.

The current compression audit is recorded in:

- `docs/research/COMPRESSION_AUDIT_CHECKPOINT_226.md`;
- `docs/research/COMPRESSION_AUDIT_PHASE1.md` through `COMPRESSION_AUDIT_PHASE6.md`.

## 1. Persistent design law

The recurring LOAM question is:

```text
What is the smallest independently observable information
from which the household answers we currently need
can still be reconstructed?
```

This does not mean smallest file count, shortest source, or fewest type names.

The project distinguishes three things:

```text
retained meaning      independently observable household information or policy
physical authority    the selected source that publishes that retained information
mechanism             algebra, admission, lookup, codec, publication, or UI machinery
```

One mechanism may serve several meanings. Several meanings may share one physical authority. Similar-shaped meanings do not automatically deserve one authority or one generic ontology.

The corresponding implementation rule is:

```text
share algebra and mechanics
preserve semantic authority
```

## 2. Research arc, compressed

### 001–084: observable distinctions before product ontology

The first arc established the neutral quantity/event vocabulary and several laws that continue to constrain later work:

- exact signed quantity is distinct from its application interpretation;
- Event/Effect identity is not a Locus × Measure coordinate;
- correction and resolution are explicit provenance rather than mutation by list position;
- valid time and learned time can differ;
- physical placement and application classification are different information;
- summaries are sufficient only relative to the later questions they must answer;
- private shadow observations may use run-local identity only when the query is invariant under identity renaming.

Accounting, planning, reporting, and privacy pressure were used as falsification tools rather than as permission to import conventional product nouns wholesale.

### 085–145: practical household boundaries and authority pressure

The next arc pushed the neutral vocabulary into real household operations. It established or refined:

- explicit origin evidence rather than pretending that every opening quantity is an Event;
- Scheduled evidence as distinct from Actual evidence;
- correction-aware quantity and balance projections;
- Purpose routing as retained historical policy rather than spelling-derived meaning;
- destructive authority cutover rules and fail-closed publication boundaries;
- the principle that compatibility scaffolding may be removed after a quiescent single-version cut.

Some mechanisms from this era were later superseded. In particular, the current household no longer needs the old QuantityBasis/BasisCut production path after historical reconstruction and explicit zero-origin coverage.

### 146–196: practical routing, Capacity, Attention, relation, and replacement structure

This arc increased real household capability while repeatedly refusing unnecessary canonical state.

Important surviving distinctions include:

- physical quantity movement vs Capacity authority movement;
- Actual routing vs Scheduled routing, sharing `RoutingHistory` mechanics while keeping separate semantic subjects;
- open relation vs exact discharge quantity;
- Attention item vs Attention closure;
- Scheduled occurrence vs completion, retirement, and replacement provenance;
- generic replacement-frontier mechanics reused without collapsing domain meanings.

The important compression successes are not only deletions. They include several meanings sharing small mechanics without becoming one semantic kind.

### 197–226: authority consolidation and zero-origin cut

The later production arc reduced historical scaffolding while strengthening fail-closed authority boundaries.

Key results include:

- historical Actual reconstruction made the current household's retained QuantityBasis rows semantically unnecessary;
- explicit finite `ZeroOriginCoverage` preserves the distinction between known zero origin and unknown missing history;
- Movement publication moved to a selected generation/manifest authority rather than routine sidecar mutation;
- Scheduled occurrence, completion, retirement, and replacement were consolidated into one complete lifecycle image;
- missing Scheduled lifecycle authority is not interpreted as an explicitly empty lifecycle;
- ScheduledRouting remains a separate authority because lifecycle publication has not earned atomic coupling to routing.

Observation 226 therefore selected:

```text
one complete Scheduled lifecycle image
+ independent ScheduledRouting authority
```

rather than optional lifecycle sidecars, one giant Scheduled monolith, or a universal manifest framework.

### 227: Scheduled Capacity pressure without a new eligibility fact

Observation 227 asks which Scheduled coordinates should exert Capacity pressure. Positive quantity alone is too coarse: an expected Asset receipt and an expected Expense do not have the same pressure meaning.

The selected bounded rule reuses existing evidence:

```text
explicit ScheduledRouting
+ sign
+ partial AccountingRole
```

and keeps unresolved classification visible.

For positive unrouted coordinates:

```text
Expense / Liability      -> pressure
Asset / Income / Equity  -> resolved non-pressure
missing AccountingRole   -> unresolved eligibility
```

An explicit Scheduled route selects pressure even when role evidence is absent. No retained `CommitmentEligibility`, fixed-cost authority, or new canonical eligibility bit was earned.

`AccountingRole` here is a partial classification input to a qualified projection. Its use must not be confused with a claim that every Locus has a role, or that role alone determines Scheduled pressure.

## 3. Current retained household basis

The compression audit counts retained household meaning rather than files, wrappers, or result types.

At checkpoint 226 the selected production basis was 18 retained fact/policy families:

1. Event with signed Effects;
2. Actual validity provenance;
3. Event description;
4. RelationUnit;
5. RelationDischarge;
6. Locus admission policy;
7. EventCorrection;
8. Actual routing assertion;
9. Zero-origin coverage;
10. Capacity movement;
11. Capacity effective coordinate;
12. Attention item;
13. Attention closure;
14. Scheduled occurrence;
15. Scheduled completion;
16. Scheduled retirement;
17. Scheduled replacement;
18. Scheduled routing assertion.

This list is not a metaphysical minimum and it is not a list of all Core types. It records independently retained household information at that checkpoint.

Observation 227 changes a Scheduled pressure projection by reusing `AccountingRole`; it does not by itself earn a nineteenth eligibility fact. Whether a classification is retained, supplied by a caller, or later receives a selected production authority remains a separate authority question.

## 4. Current practical vocabulary

The practical code uses a larger vocabulary than the retained-fact list because representation and proof require algebra, identity, admission, and derived views.

Current important Core areas include:

- exact `Quantity` / `Measure` arithmetic;
- `Event`, `Effect`, stable identities, and memories;
- balanced movement algebra;
- Actual validity and correction provenance;
- relation endpoints, admission, and discharge;
- Purpose and historical routing mechanics;
- Capacity and Attention vocabulary;
- Scheduled occurrence/lifecycle/replacement/routing vocabulary;
- explicit zero-origin coverage;
- partial `AccountingRole` classification;
- human Event description.

`Rate`, `Allocation`, `RecipientAssignment`, `QuantityBasis`, `QuantityBasisCorrection`, and `BasisCut` are not current Practical Core production modules after the compression audit. Their historical research role remains visible in earlier commits and experiment prose.

Result vocabulary such as balance views, current-open Scheduled views, Commitment/Headroom answers, replacement frontiers, and unresolved eligibility is not automatically retained canonical state.

## 5. Current authority shape

The exact physical topology may continue to change, but the current design prefers a small number of explicit selected authorities over a forest of optional sidecars.

Important current shapes include:

```text
Movement selected generation
  -> Event
  -> ActualValidity
  -> EventDescription
  -> RelationUnit
  -> RelationDischarge
  -> LocusAdmission

Scheduled lifecycle image
  -> Scheduled occurrence
  -> completion
  -> retirement
  -> replacement

independent policy/evidence authorities
  -> EventCorrection
  -> ActualRouting
  -> ZeroOriginCoverage
  -> Capacity
  -> Attention
  -> ScheduledRouting
```

Bundling several fact families into one atomic physical image does not merge their meanings.

Missing authority also does not automatically mean empty evidence. Fail-closed handling is part of the semantic boundary whenever the distinction is observable.

## 6. What has been deliberately retired

The compression audit established that deletion is part of production design, not merely cleanup after design.

The first retirement wave removed:

- unused `ScheduledCompletionUi` presentation shell;
- unwired numeric kernels `Rate`, `Allocation`, and `RecipientAssignment`;
- the production-retired QuantityBasis/BasisCut implementation cluster;
- superseded live Lean probes whose practical role had been taken over by later invariants;
- dedicated CI workflows whose only remaining purpose was to keep retired production APIs executable;
- unwired AccountingRole persistence/test machinery from that checkpoint.

Historical questions and conclusions remain in prose and Git history. Retiring executable research apparatus is not the same as erasing the research result.

## 7. Research and CI lifecycle

Formal experiments are encouraged while a question is open. They are not required to remain permanent live infrastructure.

The current lifecycle is:

```text
ACTIVE RESEARCH
  dedicated model/probe/CI is allowed

INTEGRATED LAW
  current production invariant/test takes responsibility

SUPERSEDED HISTORY
  preserve prose + Git history
  graduate obsolete executable probe / dedicated CI
```

This rule prevents the repository from confusing accumulated research equipment with the size of the current household system.

Historical Lean observations that remain in `Loam.Observations` are selected live proof obligations, not a promise that every proof ever written must stay in the umbrella forever.

## 8. Compression guardrails

LOAM should resist both forms of accidental growth:

```text
semantic inflation
  adding a retained fact because a familiar noun sounds useful

mechanical inflation
  repeating the same representation machinery around many meanings
```

But mechanical sharing is earned only when it stays smaller than the distinction it replaces. The compression audit rejected large generic `Memory`, serializer, transaction, identity-service, revision-framework, and authority-framework designs.

The narrow sharing candidates are representation mechanics such as:

- lookup plus permutation-invariance helpers;
- versioned line-image framing;
- stage-and-rename file replacement;
- deterministic opaque-ID candidate search.

These are candidates, not mandates.

## 9. What this map is for

This map is the compressed current answer to:

> What did the observations teach us that still matters to the system now?

It is not the archive of every route taken to that answer.

When a later compression checkpoint changes the current semantic basis, authority topology, or major integrated law, this file should be rewritten to the new current terrain rather than extended indefinitely. The previous map remains recoverable from Git history.

That is the intended asymmetry:

```text
research may accumulate
current explanation must compress
```
