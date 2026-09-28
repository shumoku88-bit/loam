import Loam.Observations.Observation011
import Loam.Observations.Observation029
import Loam.Observations.Observation078
import Loam.Observations.Observation159
import Loam.Observations.Observation183
import Loam.Observations.Observation184
import Loam.Observations.Observation186
import Loam.Observations.Observation191
import Loam.Observations.Observation192
import Loam.Observations.Observation193
import Loam.Observations.Observation194
import Loam.Observations.Observation195
import Loam.Observations.Observation250
import Loam.Observations.Observation253
import Loam.Observations.Observation255
import Loam.Observations.Observation256
import Loam.Observations.Observation257
import Loam.Observations.Observation258
import Loam.Observations.Observation259
import Loam.Observations.Observation260
import Loam.Observations.Observation261
import Loam.Observations.Observation262
import Loam.Observations.Observation270
import Loam.Observations.Observation282
import Loam.Observations.Observation283
import Loam.Observations.StructuralS003
import Loam.Observations.StructuralS008
import Loam.Observations.Observation284
import Loam.Observations.Observation285
import Loam.Observations.Observation287
import Loam.Observations.Observation288
import Loam.Observations.Observation289
import Loam.Observations.Observation290
import Loam.Observations.Observation291
import Loam.Observations.Observation292
import Loam.Observations.Observation293
import Loam.Observations.Observation295
import Loam.Observations.Observation296
import Loam.Observations.Observation297
import Loam.Observations.Observation298
import Loam.Observations.Observation299
import Loam.Observations.Observation300
import Loam.Observations.Observation301
import Loam.Observations.Observation302
import Loam.Observations.Observation303
import Loam.Observations.Observation304
import Loam.Observations.Observation305
import Loam.Observations.Observation306
import Loam.Observations.Observation307
import Loam.Observations.Observation308
import Loam.Observations.Observation309
import Loam.Observations.Observation310
import Loam.Observations.Observation311
import Loam.Observations.Observation312
import Loam.Observations.Observation313
import Loam.Observations.Observation314
import Loam.Observations.Observation315
import Loam.Observations.Observation316
import Loam.Observations.Observation317
import Loam.Observations.Observation318
import Loam.Observations.Observation325
import Loam.Observations.Observation331
import Loam.Observations.Observation334
import Loam.Observations.Observation335
import Loam.Observations.Observation336
import Loam.Observations.Observation337
import Loam.Observations.Observation343
import Loam.Observations.Observation345
import Loam.Observations.Observation346
import Loam.Observations.Observation347
import Loam.Observations.Observation348
import Loam.Observations.Observation349
import Loam.Observations.Observation350
import Loam.Observations.Observation351
import Loam.Observations.Observation352
import Loam.Observations.Observation354
import Loam.Observations.Observation355
import Loam.Observations.Observation356
import Loam.Observations.Observation357
import Loam.Observations.Observation358
import Loam.Observations.Observation363
import Loam.Observations.Observation368
import Loam.Observations.Observation369
import Loam.Observations.Observation380

/-!
Research compaction notes:

- 2026-09-26: Observations 320, 322–324, 326–330 (except 325), 332,
  338, and 339 retired from the live witness umbrella after later terminal
  proofs, production promotion, proof-carrying production types, and retained
  research prose took over their roles.
- 2026-09-28: Observation 271 retired after the admitted Actual read image was
  promoted to `AdmittedActualImage`; its current Event / validity correspondence
  obligations now live directly in production proof fields and qualification
  tests.
- 2026-09-28: Observations 276 and 278 retired after their conservation
  scaffolds became direct production laws. `BalancedMovement` carries exact
  zero-total proof with the value, while `ActualReversal.coordinateNetZero_of_exactPhysicalInverse`
  and `ActualReversalBalance` own the stronger Event/Effect and per-Measure
  reversal cancellation results.
- 2026-09-28: Observation 275 retired after its signed unrouted-Actual row
  boundary was promoted into `ActualRoutingInspection.UnroutedActualRow` and
  `CurrentCoverageReview.ActualRoutingFrontier`, with production regressions
  covering temporal routing, Expense classification, and unresolved roles.
- 2026-09-28: Observation 286 retired after its midpoint-adoption specimen
  became a direct composition of production quantity-support laws:
  `CurrentQuantityAnchor` owns the observed-current cut, `RoleBalanceReview`
  keeps support coordinate-local, and zero-origin / bounded-history evidence
  remain separate completeness claims.
- 2026-09-28: Observation 321 retired after Transactions Flow made
  `rowTotal` a direct derived view of `rowActivity.net`. Its Event-local
  coordinate-fold correspondence is subsumed by the stronger live sparse
  HashMap proof in Observation 325.
- 2026-09-28: Observation 333 retired after its one-quantity-per-current-Event
  scan was promoted by #1323 and later narrowed by #1399: current Stock-Flow
  keeps one fail-closed window scan while historical start reconstruction is
  owned separately by `HistoricalBalanceReview`.
- 2026-09-28: Observation 353 retired after its provisional-date refinement
  specimen became ordinary production behavior: `ActualValidityPublisher`
  appends date-revision evidence while preserving the Event/Effects, and focused
  tests pin repeated correction and current-truth `ActualReview` placement.
- 2026-09-28: Observation 130 and its migration-era qualification note retired
  after `EventDescription` became a production Core evidence family. The Core
  type now owns Event-scoped uniqueness, lookup, and neutrality; the old 558-row
  migration pressure and candidate comparison remain available in Git history.
- 2026-09-28: Observations 129 and 135 plus their one-shot historical-admission
  notes retired after the migration-specific multi-stream PREPARED/receipt and
  snapshot-archive candidates never became current authority. Normalized
  `actual.loam` now publishes one fully admitted image through staged typed
  re-decode and a single atomic rename; migration provenance remains Git history.
- 2026-09-28: Observations 179 and 180 retired after Observation 191 generalized
  their finite wallet/food preservation-polarity and double-closure fixtures into
  the current observation-independent quotient/factorization theorem. The live
  downstream users depend only on Observation 191's generic machinery; the
  representative normalization and minimal-basis field trials remain in Git history.
- 2026-09-28: Observation 008 retired after its reusable recovery laws moved
  into Observation 029's vocabulary-relative summary boundary. The old Boolean
  coordinate fixtures and dedicated prose were discovery scaffolds; current
  summary-fiber and future-context work now builds on Observations 029, 192,
  297, and 307.
- 2026-09-28: Observation 294 retired after Observation 295 retained its
  user-created durable-subject pressure inside the stronger domain-indexed
  StableSubjectId witness. The live specimen now covers empty pre-provenance,
  populated, and retargeted payloads while preserving lineage and aliases.
- 2026-09-28: Observations 340, 342, and 344 retired after their travel
  evidence candidates became production boundaries. ExchangeEvidence and
  OriginalAmountEvidence now live in Core, their correction-aware admission
  lives in Application frontiers, and normalized Actual regression tests own
  duplicate/positivity, correction, reversal, and wire-roundtrip behavior.
  Observation 343 remains live against those production APIs as the independent
  Measure-symmetry witness.
- 2026-09-28: Observation 341 retired after its negative Relation/Discharge
  cross-Measure card witness was overtaken by the promoted Settlement boundary.
  `SettlementCommitment` now owns independent settlement Measure/Quantity,
  `SettlementEffectCorrespondence` names the exact later Event/Effect/quantity,
  and `SettlementFrontier` enforces the current admission laws with a focused
  cross-Measure card regression. `RelationDischarge` remains intentionally
  narrower rather than carrying settlement meaning.
- 2026-09-28: Observation 319 retired after its Locus-only
  ZeroOriginCoverage counterexample became a direct production boundary.
  `ZeroOriginCoverage` retains exact `EffectCoordinate` membership, preserving
  the Locus × Measure distinction, while `ZeroOriginQuantity` owns the
  covered/uncovered fail-closed inspection theorems. Product correctness no
  longer depends on the historical finite JPY/USD witness.
- 2026-09-28: Observations 277 and 279–281 retired after the
  Movement idempotency research sequence became direct production behavior.
  `EventMemory` keeps structural EventId uniqueness separate from semantic retry
  identity; `MovementOperationEvidenceMemory` retains a one-to-one
  `MovementOperationId -> EventId` relation; and
  `MovementPublisher.publishDraftIdempotent` performs lookup and first
  publication under one Actual writer ownership, returning the original EventId
  on replay without treating draft equality as identity. The finite precursor
  models and duplicate-draft pressure remain in Git history.
- 2026-09-28: Observations 359 and 360 retired after the settlement family
  reached production. Their delayed cross-Measure commitment, exact later-Effect
  correspondence, and "keep OpenRelation source-bounded" conclusions are now
  owned by Core.Settlement, Application.SettlementFrontier, the durable
  settlement boundary note, and focused production regressions.
- 2026-09-28: Observations 361 and 362 retired after exact correspondence
  quantity, partial/multi-target allocation, aggregate safety, retained
  correspondence version identity, generic replacement-frontier correction, and
  atomic settlement batch publication became production behavior. Observation
  363 remains live because complete-allocation publication is still an optional
  semantic promise distinct from incremental reconciliation.
- 2026-09-28: Observations 364–367 and 370 retired after bidirectional endpoint
  sign admission, explicit netting contexts/members, zero-net outcomes without
  synthetic Effects, member-row revision, and composed direct/net conservation
  became production settlement laws with focused regressions. Observations 368
  and 369 remain live because as-finalized publication and correction of finality
  evidence are intentionally outside the current production family.

Retired source remains available in Git history.
-/

/-!
# Selected live Lean research witnesses

This module gathers historical Lean observations that still justify keeping an
executable regression witness in the current repository. Practical code should
import `Loam.Core` instead.

This umbrella is **not** the durable kernel-proof trust surface. Some selected
observations intentionally use `native_decide` for finite executable witnesses.
Long-lived theorem assets selected for stronger checker/axiom qualification are
indexed separately by `Loam.DurableProofs`.

Superseded observations may graduate from this umbrella once their question,
witness, and conclusion remain recorded in research prose and Git history and a
later production invariant or observation has taken over their practical role.
-/
