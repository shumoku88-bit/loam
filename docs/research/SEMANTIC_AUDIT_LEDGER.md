# LOAM semantic audit ledger

Status: **ACTIVE CHECKPOINT LEDGER**

Original audit baseline: `3227fcf59ae1fa15191378be84ab5527dd57e29c`

Current production checkpoint: `0338ed7964a0acbee70eb03c1b7063b95813af72`

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
| #724 | shared ActualValidity ordinary stage/write/rename through `SiblingStage` | share physical replacement mechanics while keeping semantic admission local |
| #726 | unified three fail-closed Actual-consumption folds | share one validity-required accumulation law while preserving routing/window query boundaries |
| #728 | unified duplicated CurrentCoverage arithmetic/view assembly | share pure post-acquisition arithmetic while preserving routing-specific composition boundaries |
| #730 | shared fresh Scheduled occurrence construction across Creation/Replacement | share pure construction mechanics while keeping operation authority and provenance explicit |

PR #720 is an important control for future work: a temporary Lean migration proof was allowed to grow while proving equivalence, then the proof scaffolding was retired after the runtime duplication was removed. Formal methods should justify subtraction, not permanently replace runtime duplication with proof duplication.

PR #722 is the corresponding low-risk dependency control: one broad import edge was removed with no replacement import required, and exact-head Production TUI completed 62/62 functional steps alongside successful Selected Lean Observations and Compression Audit runs.

PR #724 is the persistence-mechanics control: ActualValidity retained its V2/V3 existing-storage admission, wire encoding, fail-closed behavior, and migration semantics while deleting a private copy of the ordinary sibling-stage replacement sequence. Six exact-head workflows passed, including Shared ActualValidity Publisher, Practical Actual Validity Correction, Practical Readable Journal Export, and Practical Movement.

PR #726 is the Application-mechanics control: temporary Lean migration witnesses established by definitional equality that ordinary routing, initial-aware routing, and the CapacityWindow helper were specializations of the same validity-required fold. After qualification, the duplicate folds and proof scaffolding were retired. Final production delta was 3 files, +31 / -35, with fold implementations reduced from three to one. Twelve exact-head workflows passed, including Lean Application, Practical Slice A2, Actual Routing Persistence, Capacity Effective Window/Persistence, Budget Window, and Production TUI 62/62.

PR #728 completed the remaining SA-007 arithmetic candidate. Temporary Lean witnesses established by definitional equality that both CurrentCoverage public functions shared the same post-acquisition assembly. The witnesses were retired after cutover; one private `assembleCurrentCoverage` now owns Remaining, Headroom, and `CurrentCoverageView` construction while ordinary and `RoutingEffective` Consumption acquisition remain separate. Final production delta was 1 file, +17 / -22. Seven exact-head workflows passed, including Lean Application, Practical Slice B, and Production TUI 62/62.

PR #730 completed the narrow SA-008 candidate. Temporary Lean witnesses proved by definitional equality that Creation and Replacement used the same fresh-id choice, balanced JPY movement reconstruction, and `ScheduledOccurrence` construction. The witnesses and publisher-local copies were retired after qualification. A small `ScheduledOccurrenceConstruction` mechanic now owns only those pure operations; Creation and Replacement retain separate validation wording, source/current-open admission, terminal provenance, transition checks, writer ownership, receipts, and publication order. Final production delta was 3 files, +41 / -48. Shared Creation and Replacement publisher workflows, Selected Lean Observations, Compression Audit, and Production TUI 62/62 all passed.

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

Status: `IMPLEMENTED`

Record: `SEMANTIC_AUDIT_SA006_PERSISTENCE.md`

Verdict:

- keep semantic wire owners and family-specific admission/recovery policy explicit;
- keep shared `TokenSyntax`, `VersionedRows`, and `SiblingStage` mechanics;
- do not create a universal serializer or generic persistence repository.

Implemented by PR #724:

- removed private `actualValidityStagePath` and direct `writeFile` / `rename` duplication;
- delegated only the ordinary physical replacement to `SiblingStage.replaceTextViaSiblingStage`;
- retained ActualValidity V2/V3 existing-storage admission before replacement;
- retained V3 wire bytes, V2 migration-on-publication, malformed/retired storage refusal, missing-storage meaning, and `Bool` refusal semantics;
- exact-head Shared ActualValidity Publisher, Practical Actual Validity Correction, Practical Readable Journal Export, Practical Movement, Selected Lean Observations, and Compression Audit all passed.

Secondary backlog:

- prove the newline-free `VersionedRows` encode/decode round trip in Lean;
- review isolated `AmountPersistence` under low-level product topology, not semantic codec compression.

### SA-007 Application projection fanout

Status: `AUDIT_COMPLETE` / `IMPLEMENTED`

Record: `SEMANTIC_AUDIT_SA007_APPLICATION.md`

Completed since the audit:

- Candidate B, `QuantityInspection` success provenance and singleton algorithm duplication, was resolved by #717 through #720.
- Candidate A was resolved by #726. One `foldRecordedConsumptionWhere?` now owns the fail-closed validity-required accumulation law. Ordinary routing, `RoutingEffective`, coordinate-window selection, correction-frontier selection, and household-facing query names remain separate. Temporary migration witnesses proved the old folds definitionally equal to the shared specializations before cutover.
- Candidate C was resolved by #728. One private `assembleCurrentCoverage` now owns `Remaining = Entitlement - Consumption`, `Headroom = Remaining - managed Commitment`, and `CurrentCoverageView` construction. Both public CurrentCoverage functions and their routing-specific Consumption acquisition remain separate.

No current SA-007 implementation action. Reopen only if new concrete projection duplication appears.

### SA-008 Scheduled semantic amplification

Status: `AUDIT_COMPLETE` / `IMPLEMENTED`

Record: `SEMANTIC_AUDIT_SA008_SCHEDULED.md`

Verdict: Scheduled fanout is mostly healthy derived porcelain over a small retained basis.

Implemented by PR #730:

- one `ScheduledOccurrenceConstruction` module now owns first-unused Scheduled identity choice, balanced JPY movement reconstruction from Effects, and fresh `ScheduledOccurrence` construction;
- temporary Lean witnesses proved the former Creation and Replacement copies definitionally equal to the shared mechanic before cutover;
- publisher-local copies and migration witnesses were retired;
- Creation and Replacement remain separate publication authorities with operation-specific validation, provenance, transition checks, ownership, receipts, and publication order;
- no generic Scheduled publisher or lifecycle framework was introduced.

No current SA-008 implementation action. Reopen only if another concrete Scheduled mechanic earns sharing without collapsing operation authority.

### SA-009 Publisher / Authority / Review semantic echo

Status: `UNREVIEWED`
Priority: highest current audit priority

This is the largest remaining broad audit region.

Question:

> Which `*Publisher`, `*Authority`, and `*Review` modules own independent crash/recovery/authority laws, and which repeat the same publication protocol with only semantic adapters?

Use operational criteria, not type isomorphism. When interrupted publication, retry, writer ownership, or recovery is involved, prefer an explicit transition model or TLA+ over a purely structural refactor.

Do not start by extracting a universal `Publisher<T>`.

### SA-010 Revision-only identity principle

Status: `AUDIT_COMPLETE` / `KEEP`

Record: `SEMANTIC_AUDIT_SA010_IDENTITY.md`

The principle already produced two successful reductions:

- #715 removed `EventCorrectionId` because endpoint identity was sufficient;
- #716 removed `ActualValidityCorrectionId` while retaining independent revision identity only for actual revisions.

The remaining production census found no further redundant identity justified for deletion.

Keep:

- `EventId`, `ScheduledId`, `CapacityMovementId`, `AttentionId`, and `RelationUnitId` because independently referable occurrences/entities have external reference or multiplicity reasons;
- `ActualValidityRevisionId` because later retained revisions require exact correction provenance while the Event-rooted base fact already carries no extra identity;
- `EffectKey` because distinct same-coordinate Effects may coexist and later relation provenance refers to one exact Effect;
- `LocusId`, `MeasureId`, `PurposeId`, and `ExternalEndpointId` because they are semantic coordinates rather than persistence-row identities.

The neighboring evidence families already demonstrate the desired rule by carrying no extra independent ID when subject/endpoints suffice: Event Correction, Actual Reversal, ActualValidity Correction edges, Scheduled Terminal, Attention Closure, Capacity Effective, RoutingEntry, and Relation Discharge.

This is a negative audit verdict. Reopen one identity only if new semantics remove its current external-reference, multiplicity, coordinate, or revision-provenance reason.

No current SA-010 implementation action.

## 5. Next work queue

This is the default order after current production checkpoint `0338ed7964a0acbee70eb03c1b7063b95813af72`. Re-check actual main and open PRs before every item.

### P0 - narrow, low-risk subtractions

No current P0 item. The qualified low-risk queue was exhausted by #722 and #724.

### P1 - proof-first mechanical compression

No current P1 item. The qualified mechanical queue was exhausted by #726, #728, and #730.

### P2 - next conceptual audits

1. **SA-009:** audit Publisher / Authority / Review protocol echo, using transition reasoning for crash/retry/recovery behavior.

### P3 - reopen only with concrete pressure

2. **SA-001:** further finite-keyed carrier sharing.
3. `VersionedRows` newline-free round-trip theorem.
4. isolated Amount / low-level product-topology usefulness review.

If a candidate stops being net-negative once proof/adapters are included, mark it `KEEP` and move on. The ledger is allowed to record negative results.

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
