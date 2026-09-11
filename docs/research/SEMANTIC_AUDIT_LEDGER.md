# LOAM semantic audit ledger

Status: **ACTIVE CHECKPOINT LEDGER**

Original audit baseline: `3227fcf59ae1fa15191378be84ab5527dd57e29c`

Current production checkpoint: `9d43f788579f8320defea2eef9822853f1726941`

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

## 3. Recent completed compression and formal consolidation

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
| #736 | unified admitted Capacity publication tail | prove the common construction, preserve different admission, then share only publication mechanics |
| #738 | made `VersionedRows` framing law explicit and retired legacy `String.splitOn` | retain one permanent round-trip law where shared persistence mechanics justify proof surface |
| #740 | retired standalone `LOAM-AMOUNT` persistence and `amount show` | low-level objects earn permanence by participating in a useful compositional path |

### Proof-first controls

PR #720 established the migration pattern: allow a temporary Lean witness to grow, prove equivalence, cut over runtime code, then retire one-time proof scaffolding.

PR #726 repeated that pattern for three validity-required Consumption folds. The final production delta was 3 files, +31 / -35, with three fold implementations reduced to one.

PR #730 proved Creation and Replacement used the same fresh Scheduled identity choice, balanced JPY movement reconstruction, and occurrence construction. The proof witnesses were retired after cutover. Final delta: 3 files, +41 / -48.

PR #734 centralized the EventCorrection family contract `missing -> empty`, `valid -> decoded`, `malformed existing bytes -> refusal`. It deliberately did not introduce a generic missing-storage policy. Final delta: 12 files, +40 / -109. Twelve exact-head workflows passed, including Production TUI 62/62.

PR #736 demonstrated both sameness and difference. Binary and balanced Capacity validation/admission are not interchangeable, but Lean proved binary movement construction is the two-change specialization of the balanced constructor under binary admission conditions. Only the post-admission publication tail was shared. Final delta: 1 file, +41 / -45; Shared Capacity Publisher, Selected Lean Observations, Compression Audit, and Production TUI 62/62 passed.

PR #738 completed the `VersionedRows` formal backlog. A proof-first migration established that the former trailing `++ "\n"` bytes equal an explicit final empty frame row and that Lean's modern single-character split recovers newline-free frames exactly. Production now uses `String.split '\n'` instead of legacy `String.splitOn`, keeps the required trailing-newline behavior and exact wire bytes, and retains one permanent theorem: newline-free `encodeVersionedRows` output decodes exactly to its rows. Temporary migration witnesses and compilation probes were retired. No family wire schema, typed row parser, semantic admission rule, or canonical household data changed.

PR #740 closed the low-level Amount topology backlog that SA-006 had intentionally deferred. Reachability showed that `AmountPersistence.save?` had no production caller and `load?` existed only for the read-only `amount show` command, while retained Event plumbing forms a compositional Event -> EventMemory path. `SomeAmount` remains a live Core value inside Effects; only the standalone `LOAM-AMOUNT` wire surface, command, tests, and CI were retired. Final candidate delta: 4 files, +1 / -138, net -137. All six triggered workflow families passed, including Practical Writer Ownership on Ubuntu and macOS. Detailed evidence is recorded in `SEMANTIC_AUDIT_AMOUNT_TOPOLOGY.md`.

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

Status: `AUDIT_COMPLETE` / `IMPLEMENTED`
Record: `SEMANTIC_AUDIT_SA006_PERSISTENCE.md`
Amount topology follow-up: `SEMANTIC_AUDIT_AMOUNT_TOPOLOGY.md`

Keep semantic wire owners and family-specific admission/recovery explicit. Keep shared `TokenSyntax`, `VersionedRows`, and `SiblingStage` mechanics. Do not create a universal serializer/repository.

Completed backlog:
- #724 shared ActualValidity ordinary stage/write/rename through `SiblingStage` while retaining its V2 overwrite policy locally;
- #738 proved the newline-free `VersionedRows` encode/decode round trip and retired legacy `String.splitOn` from that shared frame;
- #740 completed the deferred low-level topology review and retired standalone Amount persistence while keeping Core `SomeAmount` and Event/Movement quantity semantics.

No current SA-006 residual candidate.

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
- binary and balanced Capacity validation/admission are not equivalent;
- do not collapse them merely because `Draft.toBalancedDraft` exists;
- the proof earned only the shared movement/publication mechanic beneath those distinct entrances.

No current SA-009 residual candidate.

### SA-010 Revision-only identity principle

Status: `AUDIT_COMPLETE` / `KEEP`
Record: `SEMANTIC_AUDIT_SA010_IDENTITY.md`

#715 and #716 removed redundant relation/correction identities. The remaining production census found no further redundant identity justified for deletion.

Keep entity/occurrence identities (`EventId`, `ScheduledId`, `CapacityMovementId`, `AttentionId`, `RelationUnitId`), true revision identity (`ActualValidityRevisionId`), nested Effect identity (`EffectKey`), and semantic coordinate identities (`LocusId`, `MeasureId`, `PurposeId`, `ExternalEndpointId`). Neighboring relation/evidence families already avoid extra IDs when endpoints/subjects suffice.

## 5. Next work queue

Default order after production checkpoint `9d43f788579f8320defea2eef9822853f1726941`. Re-check actual main and open PRs before every item.

### P0 - narrow, low-risk subtractions

No current P0 item.

### P1 - proof-first mechanical compression

No current P1 item. The qualified mechanical queue through SA-009 and the `VersionedRows` formal backlog is exhausted.

### P2 - conceptual audits

No broad conceptual audit currently remains open in SA-001 through SA-010.

### P3 - reopen only with concrete pressure

No currently qualified concrete candidate.

SA-001 finite-keyed carrier sharing remains intentionally dormant. Reopen it only if a specific new helper can remove more production/proof surface than its adapters add. Do not search for a generic memory abstraction merely to keep the compression campaign moving.

The structural compression campaign is therefore at a natural checkpoint: known concrete candidates in SA-001 through SA-010 plus the deferred `VersionedRows` and standalone Amount follow-ups have either been implemented or received an explicit KEEP/negative verdict.

New work should begin from observed product pressure, duplicated mechanics, or a newly identified independently unnecessary distinction, not from a requirement to keep deleting.

If any future candidate stops being net-negative once proof/adapters are included, mark it `KEEP` and move on. Negative results are first-class audit outcomes.

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
2. add the PR to completed compression when it removed/unified a distinction or consolidated a shared formal law;
3. update affected SA status and residual candidate;
4. remove completed queue items;
5. promote the next smallest qualified candidate;
6. record negative results instead of repeatedly reopening them without new evidence.

The ledger should remain the navigation surface. Detailed proof history belongs in dedicated audit records, PRs, and Git history rather than being duplicated here.
