# LOAM semantic audit ledger

Status: **ACTIVE CHECKPOINT LEDGER**

Original audit baseline: `3227fcf59ae1fa15191378be84ab5527dd57e29c`

Current production checkpoint: `fa1542688a1680af0d3994f0f3d18b451368f85f`

This file is the current navigation ledger for structural compression work. Detailed evidence stays in the dedicated `SEMANTIC_AUDIT_SA*.md` records and PR history.

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
- `AUDIT_COMPLETE`: a verdict exists.
- `KEEP`: independent meaning or high-value shared primitive is justified.
- `KEEP_WRAPPER`: semantic wrapper remains useful while mechanics may be shared.
- `SHARE_MECHANICS`: meanings stay separate but implementation law can be shared.
- `DERIVED`: no independent retained information; compute from admitted evidence.
- `MOVE`: meaning is valid but its current architectural layer is wrong.
- `COMPRESS`: fewer implementation mechanisms appear sufficient.
- `DELETE`: no current independent meaning, behavior, compatibility, or recovery reason remains.
- `IMPLEMENTATION_READY`: audit and formal gates are satisfied for a concrete change.
- `IMPLEMENTED`: qualified production change has merged.

## 3. Recent completed compression

| PR | Result | Principle |
| --- | --- | --- |
| #707 | retired unselected `EventResolution` / `RelationAdmission` surface | research-qualified capability is not production-selected capability |
| #713 | retired unselected `RelationRevision` capability | keep only relation semantics current production selects |
| #714 | retired unselected `AttentionRelation` vocabulary | lifecycle evidence does not earn extra ontology without consumers |
| #715 | removed redundant `EventCorrectionId` | endpoint relation already supplies sufficient identity |
| #716 | removed redundant `ActualValidityCorrectionId`; V3 endpoint-only persistence | retain identity only for independently referable revisions |
| #717 | retired Core `CorrectionQuantity` | derived quantity belongs with its Application consumer |
| #718 | retired legacy correction tip/next/sibling projections | historical projection generations are not current authority |
| #719 | refused self-correction as a cycle | no singleton exception outside frontier semantics |
| #720 | unified all nonempty Correction quantity projection on `CorrectionFrontier` | correction count carries no semantic authority |
| #722 | removed broad `Loam.Core` import from Scheduled Routing TUI | aggregation umbrellas are convenience, not semantic dependencies |
| #724 | shared ActualValidity ordinary stage/write/rename through `SiblingStage` | share physical replacement mechanics while keeping semantic admission local |
| #726 | unified three fail-closed Actual-consumption folds | share validity-required accumulation while preserving query boundaries |
| #728 | unified duplicated CurrentCoverage arithmetic/view assembly | share pure post-acquisition arithmetic while preserving routing composition boundaries |
| #730 | shared fresh Scheduled occurrence construction across Creation/Replacement | share pure construction mechanics while keeping operation authority explicit |
| #734 | centralized EventCorrection absent-as-empty loading | share one family-specific optional-evidence contract without generic missing policy |
| #736 | unified admitted Capacity publication tail | use Lean to prove the common construction, preserve genuinely different admission, then share only fresh-id/append/publication mechanics |

### Proof-first controls

PR #720 established the migration pattern: allow a temporary Lean witness to grow, prove equivalence, cut over runtime code, then retire one-time proof scaffolding.

PR #726 repeated that pattern for three validity-required Consumption folds. The final production delta was 3 files, +31 / -35, with three fold implementations reduced to one.

PR #730 proved Creation and Replacement used the same fresh Scheduled identity choice, balanced JPY movement reconstruction, and occurrence construction. The proof witnesses were retired after cutover. Final delta: 3 files, +41 / -48.

PR #734 centralized the EventCorrection family contract `missing -> empty`, `valid -> decoded`, `malformed existing bytes -> refusal`. It deliberately did not introduce a generic missing-storage policy. Final delta: 12 files, +40 / -109. Twelve exact-head workflows passed, including Production TUI 62/62.

PR #736 is the strongest current example of formal methods discovering both sameness and difference. The initial audit found that binary and balanced Capacity entrances are **not** interchangeable: balanced validation additionally checks Purpose token syntax and balanced admission checks every changed Purpose against nonnegative entitlement, while the binary entrance retains its named-source rule. A temporary Lean theorem then proved that, under the binary positive-quantity and distinct-endpoint conditions, binary movement construction is exactly `Draft.toBalancedDraft` specialized through the balanced movement constructor. After that proof, the binary-only constructor and duplicated post-admission publication tail were removed. One private `publishAdmittedMovement` now owns fresh identity allocation, balanced movement construction, Capacity append, CapacityEffective append, effective-first publication, and activating Capacity publication. Both public entrances, validators, entitlement admission rules, receipts, writer ownership, crash residue, and recovery semantics remain separate. Final delta: 1 file, +41 / -45. Shared Capacity Publisher, Selected Lean Observations, Compression Audit, and Production TUI 62/62 all passed.

Canonical household data was not changed by this sequence.

## 4. Audit matrix

### SA-001 Finite keyed semantic memories

Status: `SHARE_MECHANICS` / `KEEP_WRAPPER`
Priority: low unless new duplication pressure appears

Decision:
- keep domain memories as semantic wrappers;
- keep `FiniteKeyed` for lookup/permutation mechanics;
- do not introduce a public generic household `Memory` carrier merely because representations are isomorphic.

Reopen only if another concrete helper removes more production/proof surface than its adapters add.

### SA-002 Two-endpoint relation mechanics

Status: `AUDIT_COMPLETE` / `KEEP`
Record: `SEMANTIC_AUDIT_SA002_TWO_ENDPOINT.md`

Keep `ActualReversalMemory` and `ScheduledTerminalMemory` explicit. No generic `BiMap`, `PartialInjection`, `TwoEndpointMemory`, or household relation carrier was earned.

### SA-003 Temporal / effective evidence

Status: `AUDIT_COMPLETE` / `KEEP` / `KEEP_WRAPPER`
Record: `SEMANTIC_AUDIT_SA003_TEMPORAL_EVIDENCE.md`

Keep independently observable `ActualValidity`, `CapacityEffective`, and historical routing evidence. Keep routing `initial | dated` meaning. Share only the already-earned `FiniteKeyed` and `RoutingHistory` mathematics.

### SA-004 CorrectionQuantity placement

Status: `IMPLEMENTED` / `DERIVED`
Resolved by #717-#720.

Core `CorrectionQuantity` and historical singleton/tip/next/sibling projection generations are gone. All nonempty correction sets now use one fail-closed Correction frontier path.

### SA-005 Practical Core public surface

Status: `IMPLEMENTED`
Record: `SEMANTIC_AUDIT_SA005_CORE_SURFACE.md`

`Loam/Core.lean` is a build/aggregation convenience, not a concept inventory. #722 removed one unnecessary broad import. Reopen only for another concrete broad-import edge.

### SA-006 Persistence semantic echo

Status: `IMPLEMENTED`
Record: `SEMANTIC_AUDIT_SA006_PERSISTENCE.md`

Keep semantic wire owners and family-specific admission/recovery explicit. Keep shared `TokenSyntax`, `VersionedRows`, and `SiblingStage` mechanics. Do not create a universal serializer/repository.

Residual backlog:
- prove the newline-free `VersionedRows` encode/decode round trip in Lean;
- review isolated `AmountPersistence` under low-level product topology, not semantic codec compression.

### SA-007 Application projection fanout

Status: `AUDIT_COMPLETE` / `IMPLEMENTED`
Record: `SEMANTIC_AUDIT_SA007_APPLICATION.md`

Resolved candidates:
- QuantityInspection historical duplication via #717-#720;
- validity-required Consumption fold via #726;
- CurrentCoverage post-acquisition arithmetic via #728.

No current SA-007 action.

### SA-008 Scheduled semantic amplification

Status: `AUDIT_COMPLETE` / `IMPLEMENTED`
Record: `SEMANTIC_AUDIT_SA008_SCHEDULED.md`

Scheduled fanout is mostly healthy derived porcelain over a small retained basis. #730 shared only pure fresh occurrence construction. Creation and Replacement remain separate publication authorities.

### SA-009 Publisher / Authority / Review semantic echo

Status: `AUDIT_COMPLETE` / `IMPLEMENTED` / `KEEP`
Record: `SEMANTIC_AUDIT_SA009_PROTOCOL_ECHO.md`

Broad verdict:
- keep publisher protocols explicit where crash residue, retry admission, writer-lock order, or atomicity differ;
- keep local Authority boundaries that hide one earned physical topology;
- keep Review boundaries named by household question;
- keep `WriterOwnership` as the shared physical exclusion primitive;
- do not introduce generic `Publisher<T>`, transaction, Authority, or Review frameworks.

Implemented narrow mechanics:
- #734: EventCorrection absent-as-empty family loading;
- #736: Capacity post-admission publication tail.

Important #736 negative result retained as design law:
- binary and balanced Capacity **validation/admission are not equivalent**;
- do not collapse them merely because `Draft.toBalancedDraft` exists;
- the proof earned only the shared movement/publication mechanic beneath those distinct entrances.

No current SA-009 residual candidate.

### SA-010 Revision-only identity principle

Status: `AUDIT_COMPLETE` / `KEEP`
Record: `SEMANTIC_AUDIT_SA010_IDENTITY.md`

#715 and #716 removed redundant relation/correction identities. The remaining production census found no further redundant identity justified for deletion.

Keep entity/occurrence identities (`EventId`, `ScheduledId`, `CapacityMovementId`, `AttentionId`, `RelationUnitId`), true revision identity (`ActualValidityRevisionId`), nested Effect identity (`EffectKey`), and semantic coordinate identities (`LocusId`, `MeasureId`, `PurposeId`, `ExternalEndpointId`). Neighboring relation/evidence families already avoid extra IDs when endpoints/subjects suffice.

## 5. Next work queue

Default order after production checkpoint `fa1542688a1680af0d3994f0f3d18b451368f85f`. Re-check actual main and open PRs before every item.

### P0 - narrow, low-risk subtractions

No current P0 item.

### P1 - proof-first mechanical compression

No current P1 item. The qualified mechanical queue through SA-009 is exhausted.

### P2 - conceptual audits

No broad conceptual audit currently remains open in SA-001 through SA-010.

### P3 - reopen only with concrete pressure / small formal backlog

1. `VersionedRows` newline-free encode/decode round-trip theorem in Lean.
2. SA-001 finite-keyed carrier sharing, only if a concrete net-negative helper appears.
3. isolated Amount / low-level product-topology usefulness review.

The `VersionedRows` theorem is the smallest current formal candidate. It should be treated first as a proof/audit item, not as permission for codec refactoring. If the theorem is trivial or already implied by existing implementation, keep the theorem only if it provides ongoing regression/explanatory value; otherwise record the result and do not grow proof surface.

If any candidate stops being net-negative once proof/adapters are included, mark it `KEEP` and move on. Negative results are first-class audit outcomes.

## 6. Formal-method selection

Use the smallest instrument that answers the claim.

### Lean
Prefer for:
- derivability and observational equivalence;
- representation round trips;
- pure fold/helper extraction;
- permutation independence;
- preservation of fail-closed admission;
- proof-first identity deletion;
- specialization claims such as #736.

### Alloy
Prefer for:
- two worlds that collapse under a proposed semantic merge but require different answers;
- bounded illegal combinations introduced by state-space compression;
- identity/relation necessity when the issue is relational rather than algorithmic.

### TLA+ / transition models
Prefer for:
- interrupted publication;
- retry/recovery;
- writer ownership;
- multi-step persistence/publication protocols.

Do not add a formal artifact merely because formal methods are available.

## 7. Implementation gate

Before a candidate becomes production work:

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

A proof can be migration evidence rather than permanent production machinery. Retire one-time proof scaffolding after qualification unless the theorem has ongoing explanatory or regression value.

## 8. Update rule

After every structural-compression merge:
1. update `Current production checkpoint`;
2. add the PR to completed compression when it removed/unified a distinction;
3. update affected SA status and residual candidate;
4. remove completed queue items;
5. promote the next smallest qualified candidate;
6. record negative results instead of repeatedly reopening them without new evidence.

The ledger should remain the navigation surface. Detailed proof history belongs in dedicated audit records, PRs, and Git history rather than being duplicated here.
