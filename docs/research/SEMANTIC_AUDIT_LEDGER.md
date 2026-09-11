# LOAM semantic audit ledger

Status: **ACTIVE CHECKPOINT LEDGER**

Original audit baseline: `3227fcf59ae1fa15191378be84ab5527dd57e29c`

Current production checkpoint: `3d33500368ed26d79827bbf5724de273d328ffdd`

This file is the current navigation ledger for structural compression work. Detailed evidence stays in the dedicated `SEMANTIC_AUDIT_SA*.md` records and PR history. This ledger should stay short enough to answer two questions quickly:

1. what has already been decided or removed?
2. where should the next audit or subtraction begin?

An entry here is not permission to delete a semantic distinction merely because it looks similar to another one. Production changes still pass the implementation gate below.

## 1. Governing rule

LOAM should retain only distinctions that earn independent meaning, information, authority, lifecycle, provenance, or safety.

The target is not the fewest files, types, or lines. The target is:

> the fewest independent implementation principles that preserve every independently observable household distinction.

Before deleting or merging a distinction, ask:

> Can two household worlds agree on the proposed compressed representation but require different correct answers?

If yes, the distinction stays visible somewhere.

Before retaining duplicated implementation, ask:

> Do several semantic families enforce the same structural law with independently copied code?

If yes, test the smallest shared mechanic that preserves family-specific meaning and authority.

## 2. Ledger states

- `UNREVIEWED`: registered but not investigated.
- `UNDER_REVIEW`: evidence gathering or formal probing is active.
- `AUDIT_COMPLETE`: a verdict exists; see the dedicated audit record.
- `KEEP`: independent meaning or high-value shared primitive is justified.
- `KEEP_WRAPPER`: semantic wrapper remains useful while mechanics may be shared.
- `SHARE_MECHANICS`: meanings stay separate but implementation law can be shared.
- `DERIVED`: no independent retained information; compute from admitted evidence.
- `MOVE`: meaning is valid but its current architectural layer is wrong.
- `COMPRESS`: fewer implementation mechanisms appear sufficient.
- `DELETE`: no current independent meaning, behavior, compatibility, or recovery reason remains.
- `IMPLEMENTATION_READY`: audit and formal gates are satisfied for a concrete change.
- `IMPLEMENTED`: qualified production change has merged.

## 3. Current checkpoint

The earlier six-phase compression audit and Issue #535 are historical checkpoints, not the current work queue. Since the semantic ledger was created, the production audit continued and removed several previously retained or historical distinctions.

Recent completed compression:

| PR | Result | Principle |
| --- | --- | --- |
| #707 | retired unselected `EventResolution` / `RelationAdmission` surface | research-qualified capability is not production-selected capability |
| #713 | retired unselected `RelationRevision` capability | keep only the relation semantics current production actually selects |
| #714 | retired unselected `AttentionRelation` vocabulary | lifecycle evidence does not earn an extra relation ontology without consumers |
| #715 | removed redundant `EventCorrectionId` | endpoint relation already supplies identity needed by selected semantics |
| #716 | removed redundant `ActualValidityCorrectionId`; V3 endpoint-only persistence | revision identity remains only where an independent revision lifecycle exists |
| #717 | retired Core `CorrectionQuantity` | derived quantity projection belongs with its Application consumer |
| #718 | retired legacy correction tip/next/sibling projections | historical projection generations are not current authority |
| #719 | refused self-correction as a cycle | no singleton exception outside frontier semantics |
| #720 | unified all nonempty Correction quantity projection on `CorrectionFrontier` | correction count carries no semantic authority |
| #722 | removed broad `Loam.Core` import from Scheduled Routing TUI | aggregation umbrellas are convenience, not feature-level semantic dependencies |

PR #720 is an important control for future work: a temporary Lean migration proof was allowed to grow while proving equivalence, then the proof scaffolding was retired after the runtime duplication was removed. Formal methods should justify subtraction, not permanently replace runtime duplication with proof duplication.

PR #722 is the corresponding low-risk dependency control: one broad import edge was removed with no replacement import required, and exact-head Production TUI completed 62/62 functional steps alongside successful Selected Lean Observations and Compression Audit runs.

Canonical household data was not changed by this sequence.

## 4. Audit matrix

### SA-001 Finite keyed semantic memories

Status: `SHARE_MECHANICS` / `KEEP_WRAPPER`
Priority: low unless new duplication pressure appears

Current decision:

- keep domain memories as semantic wrappers;
- keep using `FiniteKeyed` for lookup/permutation mechanics;
- do not introduce a public generic household `Memory` carrier merely because representations are isomorphic.

Reopen only if another concrete helper removes more production/proof surface than its adapters add.

### SA-002 Two-endpoint relation mechanics

Status: `AUDIT_COMPLETE` / `KEEP`

Record: `SEMANTIC_AUDIT_SA002_TWO_ENDPOINT.md`

Verdict:

- keep `ActualReversalMemory` and `ScheduledTerminalMemory` explicit;
- no generic `BiMap`, `PartialInjection`, `TwoEndpointMemory`, or household relation carrier was earned;
- Scheduled raw cross-kind conflict observability prevents a family-blind globally source-unique carrier.

No current implementation action.

### SA-003 Temporal / effective evidence

Status: `AUDIT_COMPLETE` / `KEEP` / `KEEP_WRAPPER`

Record: `SEMANTIC_AUDIT_SA003_TEMPORAL_EVIDENCE.md`

Verdict:

- keep independently observable `ActualValidity`, `CapacityEffective`, and historical routing evidence;
- keep routing `initial | dated` meaning;
- keep sharing `FiniteKeyed` and `RoutingHistory` mathematics;
- do not invent `TemporalMap`, `TimeEvidence`, or a generic temporal revision ontology.

No current implementation action.

### SA-004 CorrectionQuantity placement

Status: `IMPLEMENTED` / `DERIVED`

Resolved by PRs #717 and #720.

Result:

- Core `CorrectionQuantity` was removed;
- quantity calculation is owned by Application;
- the historical distinct-singleton algorithm was proven equivalent to generic `CorrectionFrontier` calculation and then deleted;
- `QuantityInspectionAnswer.singleCorrectionEffective` was deleted;
- all nonempty correction sets now use one fail-closed frontier path.

Reopen only if Correction authority itself changes.

### SA-005 Practical Core public surface

Status: `IMPLEMENTED`

Record: `SEMANTIC_AUDIT_SA005_CORE_SURFACE.md`

Verdict:

- `Loam/Core.lean` is a build/aggregation convenience, not a concept inventory or semantic authority;
- production features should prefer narrow Core imports;
- deleting or completing the umbrella is not justified.

Implemented by PR #722:

- removed broad `import Loam.Core` from `Loam/Tui/ScheduledRouting.lean`;
- existing narrow imports were sufficient with no replacement dependency;
- exact-head Production TUI passed all 62 functional steps;
- Selected Lean Observations and Compression Audit also passed;
- household behavior, persistence, and canonical data were unchanged.

Reopen only for another concrete broad-import edge, not as a project to abolish the umbrella itself.

### SA-006 Persistence semantic echo

Status: `AUDIT_COMPLETE` / `IMPLEMENTATION_READY`

Record: `SEMANTIC_AUDIT_SA006_PERSISTENCE.md`

Verdict:

- keep semantic wire owners and family-specific admission/recovery policy explicit;
- keep shared `TokenSyntax`, `VersionedRows`, and `SiblingStage` mechanics;
- do not create a universal serializer or generic persistence repository.

**Next concrete candidate:** `ActualValidityPersistence` still owns its own `.loam-stage` path plus write/rename sequence. Preserve its existing-storage V2/V3 admission guard, but delegate the ordinary physical replacement to the already-earned `SiblingStage` primitive.

Current implementation-readiness evidence:

- `actualValidityStagePath` is private and has no external production reference;
- the duplicated physical operation is exactly `.loam-stage` + `writeFile` + `rename`;
- `SiblingStage.replaceTextViaSiblingStage` owns exactly that ordinary physical operation and explicitly does not absorb semantic admission or stronger recovery claims;
- ActualValidity's V2/V3 existing-storage admission remains local before replacement;
- relevant qualification includes ActualValidity publication paths and practical journal/export persistence coverage.

Secondary backlog:

- prove the newline-free `VersionedRows` encode/decode round trip in Lean;
- review isolated `AmountPersistence` under low-level product topology, not semantic codec compression.

### SA-007 Application projection fanout

Status: `AUDIT_COMPLETE`, partially implemented

Record: `SEMANTIC_AUDIT_SA007_APPLICATION.md`

Completed since the audit:

- Candidate B, `QuantityInspection` success provenance and singleton algorithm duplication, was resolved by #717 through #720.

**Remaining candidate A:** share one fail-closed Actual-consumption fold across `ConsumptionInspection`, `ActualRoutingInspection`, and `CapacityWindowInspection`. `CapacityWindowInspection.consumptionAtRecordedWhere?` remains the most general current shape. Prove the current public functions observationally equal to specializations before replacing duplicated folds.

**Remaining candidate C:** after the consumption fold is settled, test a tiny shared arithmetic constructor for the repeated CurrentCoverage law:

```text
Remaining = Entitlement - Consumption
Headroom  = Remaining - managed Commitment
```

Do not create a generic Inspection/Projection framework.

### SA-008 Scheduled semantic amplification

Status: `AUDIT_COMPLETE`

Record: `SEMANTIC_AUDIT_SA008_SCHEDULED.md`

Verdict: Scheduled fanout is mostly healthy derived porcelain over a small retained basis.

**Residual candidate:** `ScheduledCreationPublisher` and `ScheduledReplacementPublisher` repeat pure fresh-occurrence construction mechanics. Share only the admitted occurrence construction if Lean/regression evidence shows identical fresh-id choice, balanced movement, occurrence bytes, and refusal behavior. Keep source selection, terminal provenance, transition checks, receipts, publication order, and authority operation-specific.

Do not build a generic Scheduled publisher or lifecycle framework.

### SA-009 Publisher / Authority / Review semantic echo

Status: `UNREVIEWED`
Priority: high after the narrow qualified candidates above

This is the largest remaining broad audit region.

Question:

> Which `*Publisher`, `*Authority`, and `*Review` modules own independent crash/recovery/authority laws, and which repeat the same publication protocol with only semantic adapters?

Use operational criteria, not type isomorphism. When interrupted publication, retry, writer ownership, or recovery is involved, prefer an explicit transition model or TLA+ over a purely structural refactor.

Do not start by extracting a universal `Publisher<T>`.

### SA-010 Revision-only identity principle

Status: `UNDER_REVIEW`, partially implemented
Priority: medium-high

The principle has already produced two successful reductions:

- #715 removed `EventCorrectionId` because endpoint identity was sufficient;
- #716 removed `ActualValidityCorrectionId` while retaining independent revision identity only for actual revisions.

Next step is a repository-wide identity census, one family at a time:

1. list remaining `*Id` values attached to base facts, revisions, relations, and publications;
2. ask whether two base facts for one subject must coexist;
3. ask whether anything externally references the fact independently of its subject/endpoints;
4. ask whether persistence/recovery requires stable independent identity;
5. only then attempt proof-first deletion.

Do not generalize the revision-only rule to facts with genuine multiplicity or provenance.

## 5. Next work queue

This is the default order after current main `3d33500368ed26d79827bbf5724de273d328ffdd`. Re-check actual main and open PRs before every item.

### P0 - narrow, low-risk subtractions

1. **SA-006:** replace ActualValidity's duplicated ordinary stage/write/rename mechanic with `SiblingStage` while preserving the V2/V3 existing-storage guard and bytes.

### P1 - proof-first mechanical compression

2. **SA-007 A:** prove and share the fail-closed Actual-consumption fold.
3. **SA-007 C:** only after item 2, test shared CurrentCoverage arithmetic if the net source/proof delta is negative.
4. **SA-008:** prove whether Creation/Replacement can share fresh Scheduled occurrence construction without sharing publication authority.

### P2 - next conceptual audits

5. **SA-010:** continue the remaining identity census and attack only independently proven redundant identities.
6. **SA-009:** audit Publisher / Authority / Review protocol echo, using transition reasoning for crash/retry/recovery behavior.

### P3 - reopen only with concrete pressure

7. **SA-001:** further finite-keyed carrier sharing.
8. `VersionedRows` newline-free round-trip theorem.
9. isolated Amount / low-level product-topology usefulness review.

If a P0/P1 candidate stops being net-negative once proof/adapters are included, mark it `KEEP` and move on. The ledger is allowed to record negative results.

## 6. Formal-method selection

Use the smallest instrument that answers the claim.

### Lean

Prefer for:

- derivability and observational equivalence;
- representation round trips;
- pure fold/helper extraction;
- permutation independence;
- preservation of fail-closed admission;
- proof-first identity deletion.

### Alloy

Prefer for:

- two worlds that collapse under a proposed semantic merge but require different answers;
- bounded illegal combinations introduced by state-space compression;
- identity or relation necessity when the issue is relational rather than algorithmic.

### TLA+ / transition models

Prefer for:

- interrupted publication;
- retry/recovery;
- writer ownership;
- multi-step persistence/publication protocols.

Do not add a formal artifact merely because formal methods are available.

## 7. Implementation gate

Before a candidate becomes production work, answer all of these:

```text
[ ] independently observable information preserved
[ ] invalid-state admission is no weaker
[ ] household-visible behavior preserved or intentionally changed
[ ] canonical/wire bytes impact known
[ ] migration requirement known
[ ] crash/retry/recovery impact known where relevant
[ ] semantic authority remains correctly separated
[ ] appropriate proof/counterexample search completed
[ ] production source/mechanism delta is plausibly net simpler
[ ] relevant exact-head CI qualification identified
```

A proof can be migration evidence rather than permanent production machinery. If proof scaffolding is only needed to justify a one-time cutover, retire it after qualification unless the theorem has ongoing explanatory or regression value.

## 8. Update rule

After every structural-compression merge:

1. update `Current production checkpoint`;
2. add the PR to the completed-compression table if it removed or unified a distinction;
3. update the affected SA status and residual candidate;
4. remove completed items from the Next work queue;
5. promote the next smallest qualified candidate;
6. record negative results instead of repeatedly reopening them without new evidence.

The ledger should remain the navigation surface. Detailed proof history belongs in dedicated audit records, PRs, and Git history rather than being duplicated here.
