# Compression audit Phase 5 — research and CI graduation

Status: **COMPLETE — FIRST GENERATION GRADUATED**

Phases 1–4 established a distinction that the repository did not previously enforce strongly enough:

```text
historical evidence != current production dependency
historical proof source != forever-live CI obligation
```

LOAM has intentionally accumulated many observations. That was useful while the semantic basis was unknown. It becomes accidental complexity when an observation that has already been superseded requires obsolete production modules to remain compilable on every future pull request.

## Graduation rule

A historical Observation may graduate out of the current working tree or live CI when all of the following hold:

1. the surviving current decision, invariant, and prohibited simplifications are distilled into living Product rationale, a current proof/test, or compressed current documentation;
2. Git history retains the exact historical executable/model/prose source and its previously successful CI state;
3. a later observation, current production invariant, or intentional semantic change subsumes or retires the practical decision for which the old probe was needed;
4. no current executable, authority, current library contract, or active research branch needs the historical implementation boundary;
5. deleting the old executable probe or prose does not erase a currently unique theorem or counterexample required by production.

Graduation means:

```text
KEEP   living Product rationale and current proof/test ownership
KEEP   Git history as the exact historical proof and exploration archive
REMOVE superseded executable probe source when its current meaning has moved
REMOVE distilled historical prose when it no longer owns unique current knowledge
REMOVE its dedicated always-live workflow
REMOVE production residue that existed only to keep that historical probe compiling
```

This is not deletion of knowledge. It is stopping the historical laboratory apparatus after its surviving result has been transferred to current owners.

## First graduation generation — QuantityBasis / BasisCut

Phase 4 classified the old QuantityBasis/BasisCut production cluster as retired. Current executable reachability is zero and Observation 219 on real household data qualified exact replacement of the household balance use by explicit finite zero-origin coverage.

The superseded production cluster is:

```text
Loam/Core/QuantityBasisMemory.lean
Loam/Core/QuantityBasisCorrectionMemory.lean
Loam/Application/QuantityBasisFrontier.lean
Loam/Application/CurrentQuantity.lean
Loam/Application/BasisCut.lean
Loam/Persistence/QuantityBasisPersistence.lean
Loam/Persistence/QuantityBasisCorrectionPersistence.lean
Loam/Persistence/BasisCutPersistence.lean
Loam/Cli/QuantityBasisCorrectionCli.lean
```

Historical executable probes still coupled to that cluster include:

```text
experiments/091_scoped_origin_projection.lean
experiments/102_balance_policy_projection.lean
experiments/103_replaceable_balance_config.lean
Loam/Observations/Observation145.lean
experiments/218_partial_injective_frontier.lean
experiments/219_zero_basis_elimination.lean
experiments/219_zero_basis_coverage_factorization.lean
experiments/220_origin_snapshot_factorization.lean
experiments/222_basis_cut_overlap_normalization.lean
```

Observation 218's reusable result is additionally embodied in current `ReplacementFrontier`; its QuantityBasis branch is not the only surviving evidence for that mechanic. Historical prose and probes that no longer own unique current knowledge may subsequently graduate to Git history after their conclusions are distilled.

The dedicated workflows tied to these probes are therefore candidates for graduation rather than continued execution against every future production change.

## Why this generation is safe to graduate

The important current meanings survive elsewhere:

- zero-origin completeness is explicit `ZeroOriginCoverage` production evidence;
- Event correction still uses current `ReplacementFrontier` mechanics;
- ActualValidity correction still uses current frontier mechanics;
- Scheduled replacement still uses current frontier mechanics;
- current balance readers use the current zero-origin path;
- `ZeroOriginCoverage` / `ZeroOriginQuantity` design rationale and `OBSERVATION_MAP.md` carry forward the qualified current decision and fail-closed boundary;
- Git history retains Observation 219's real-household parity, negative controls, and the exact retired QuantityBasis exploration;
- later production-boundary research records that QuantityBasis/BasisCut is no longer on the household production path.

What disappears is the obligation to keep a retired basis ontology executable, or its fully distilled exploration notes permanently present, merely so historical probes continue to compile or daily searches keep finding them.

## AccountingRole persistence

Phase 4 also classified `Loam/Persistence/AccountingRolePersistence.lean` as unwired production residue. Its only live code dependents are its dedicated test/workflow. However Core `AccountingRole` remains under active provisional report research, so Phase 5 must split the two:

```text
KEEP   Core AccountingRole research vocabulary for now
RETIRE AccountingRole persistence adapter
RETIRE persistence-only test/workflow
```

No claim is made yet that AccountingRole itself belongs in final production.

## CI policy after graduation

A future Observation should not automatically become a permanent PR workflow.

Default lifecycle:

```text
active question       -> dedicated CI allowed
qualified + integrated -> production invariant/test takes over when applicable
superseded history     -> current rationale + Git history; dedicated CI retired
```

Long-lived workflows should primarily protect current executable behavior, current authority formats/protocols, current reusable mechanics, and explicitly active research questions.

## Graduation executed — first generation results

Commit `d3ef447` executed the full graduation of the QuantityBasis/BasisCut generation and AccountingRole persistence residue:

- **10 production-residue files deleted (-1,063 lines)**:
  - `Loam/Core/QuantityBasisMemory.lean`
  - `Loam/Core/QuantityBasisCorrectionMemory.lean`
  - `Loam/Application/QuantityBasisFrontier.lean`
  - `Loam/Application/CurrentQuantity.lean`
  - `Loam/Application/BasisCut.lean`
  - `Loam/Persistence/QuantityBasisPersistence.lean`
  - `Loam/Persistence/QuantityBasisCorrectionPersistence.lean`
  - `Loam/Persistence/BasisCutPersistence.lean`
  - `Loam/Cli/QuantityBasisCorrectionCli.lean`
  - `Loam/Persistence/AccountingRolePersistence.lean`
- **10 historical dedicated workflows deleted (-480 lines)**:
  - `observation-091`, `observation-102`, `observation-103`, `observation-145`
  - `observation-218`, `observation-219` (both), `observation-220`, `observation-222`
  - `practical-accounting-role-persistence`
- **9 superseded Lean experiment/observation proofs deleted (-1,993 lines)**:
  - `Observation145.lean`
  - `experiments/091`, `experiments/102`, `experiments/103`, `experiments/218`
  - `experiments/219` (both), `experiments/220`, `experiments/222`
- **1 persistence unit test deleted (-114 lines)**:
  - `Loam/Tests/AccountingRolePersistence.lean`

**Total deletion: 30 files, 3,660 lines.**

All 16 practical Python tests continue to pass in ~4s; `lake build` builds cleanly with zero errors; and the candidate unreachable surface in practical Lean is now **exactly 0 files / 0 lines**.

## Follow-up graduation - foundational Observation CI 001-005

A later executable-roster change exposed another form of live-CI residue: changing `lakefile.lean` caused historical Observation 001-005 workflows to rerun even though those lanes execute only their original Alloy, J, or TLA+ probes and do not qualify the current production Lean boundary.

The five questions and conclusions are already durable in `observations/001-*.md` through `observations/005-*.md`, while the compressed `OBSERVATION_MAP.md` carries forward the surviving laws from the 001-084 arc. None of Observation 001-005 is a selected live Lean obligation in `Loam.Observations`.

The historical model, J, TLA+, and prose sources remain in the repository. Only these dedicated always-live workflows graduate:

```text
.github/workflows/observation-001.yml
.github/workflows/observation-002.yml
.github/workflows/observation-003.yml
.github/workflows/observation-004.yml
.github/workflows/observation-005.yml
```

This removes no current production test and no current theorem. It stops unrelated future changes to `lakefile.lean`, other observations, and broad research directories from repeatedly recomputing already-integrated foundational experiments.

If one of those old questions becomes active research again, a new dedicated lane may be reintroduced only for the renewed question. Historical existence alone does not make CI permanent.

## Follow-up graduation - Comparator field-trial CI 165-168

The verification checkpoint explicitly closes the focused 161-168 sequence and says Comparator, Nanoda, and a generic statement-contract framework are not mandatory product infrastructure. Further verification work is pressure-driven: hostile-solution sandboxing, upstream `propext` cleanup, or a genuinely production-relevant semantic claim must first make the question active again.

Despite that conclusion, the four field-trial workflows for Observations 165-168 still ran on every pull request and every push to `main`. Each rebuilt pinned Comparator tooling; Observation 168 additionally cloned and built Nanoda. These runs revalidated frozen verifier fixtures rather than any current LOAM production contract.

The trusted Challenge/Solution/config fixtures and the verification checkpoint remain in the repository. Only the four always-live workflows graduate:

```text
.github/workflows/observation-165-comparator-field-trial.yml
.github/workflows/observation-166-comparator-negative-statement-drift.yml
.github/workflows/observation-167-comparator-negative-axiom-policy.yml
.github/workflows/observation-168-comparator-nanoda-positive.yml
```

The immediately preceding exact-head CI for the foundational-lane graduation reran all four fixtures successfully before this retirement. Future Comparator or Nanoda CI must be earned by a concrete renewed verification pressure rather than historical existence alone.

## Follow-up graduation - QuantityBasis Applications 008-009

Applications 008 and 009 were bounded candidate probes from the old starting-quantity design arc. Both Lean files were self-contained under `import Std` and defined their own experiment-local basis vocabulary rather than exercising the current production boundary.

Their dedicated CI lanes had already graduated because recompiling the frozen candidate ontology no longer protected a current implementation. A later Phase 5 meaning-by-meaning audit then split the remaining probe obligations into two classes:

- **surviving current laws**: fail-closed zero-origin admission is owned by `inspectZeroOriginQuantity_covered` / `inspectZeroOriginQuantity_uncovered` (merged in #665), while generic supersession/frontier behavior is owned by `ReplacementFrontier`, selected `Observation043` theorems, and current replacement tests;
- **retired basis-specific laws**: arbitrary non-zero starting-basis snapshots, basis-coordinate preservation, basis-identity uniqueness, and Event-only fallback without origin evidence disappeared with the QuantityBasis ontology or were intentionally replaced by the stricter zero-origin contract.

The historical Markdown for these probes was already retired to Git history in #664 after its surviving rationale was distilled. With current proof ownership established, the executable probes themselves now graduate from the working tree as well:

```text
experiments/application_008_starting_quantity_basis.lean
experiments/application_009_append_only_basis_revision.lean
```

Git history preserves the exact historical source and qualified behavior. A renewed starting-quantity question should earn a new active probe against the current zero-origin model rather than resurrecting or perpetually recompiling the superseded candidate ontology.

## Follow-up graduation - foundational Observation CI 009-017, except 011

Observation workflows 009, 010, and 012-017 retained the same broad trigger shape as the already-graduated 001-005 generation. Changes anywhere under broad research trees, `Loam/Observations/**`, `Loam.lean`, `lakefile.lean`, the manifest, or the Lean toolchain could rerun Alloy, J, or TLA+ fixtures that only exercised their own historical observation source.

Their surviving conceptual results are already part of the compressed 001-084 arc in `OBSERVATION_MAP.md`, and none of 009, 010, or 012-017 is a selected live Lean obligation in `Loam.Observations`.

Keep all historical model, J, TLA+, and prose sources. Graduate these eight dedicated workflows:

```text
.github/workflows/observation-009.yml
.github/workflows/observation-010.yml
.github/workflows/observation-012.yml
.github/workflows/observation-013.yml
.github/workflows/observation-014.yml
.github/workflows/observation-015.yml
.github/workflows/observation-016.yml
.github/workflows/observation-017.yml
```

Observation 011 deliberately remains. Its workflow is narrowly triggered only by `model/011_derived_availability.als` or the workflow itself, and it preserves an independent Alloy witness/check rather than taxing unrelated production or research changes. Graduation is based on current execution role and trigger scope, not observation number.

## Follow-up graduation - provenance and correction Observation CI 018-024

Observations 018-024 continued the same broad-trigger pattern while exploring provenance, append-only correction, correction-chain ambiguity, conflict resolution, and the meaning of resolution. Each workflow executed only its own historical TLA+ and/or Alloy fixture, yet unrelated changes anywhere under the shared research trees, `Loam/Observations/**`, `Loam.lean`, `lakefile.lean`, the manifest, or toolchain could rerun the lane.

The surviving result has already moved into the current compressed law: correction and resolution are explicit provenance rather than list-position mutation. Later production work also reuses generic `ReplacementFrontier` mechanics across current domains without collapsing their meanings. None of Observations 018-024 is a selected live Lean obligation in `Loam.Observations`.

Keep all historical model, TLA+, and research prose sources. Graduate only these seven broad dedicated workflows:

```text
.github/workflows/observation-018.yml
.github/workflows/observation-019.yml
.github/workflows/observation-020.yml
.github/workflows/observation-021.yml
.github/workflows/observation-022.yml
.github/workflows/observation-023.yml
.github/workflows/observation-024.yml
```

A renewed correction or resolution question should earn a new probe against the current replacement/frontier boundary. Historical success alone does not require these early cross-tool fixtures to rerun on unrelated repository changes.

## Follow-up graduation and trigger narrowing - Observation CI 025-031

Observations 025-028 continued the historical resolution/provenance refinement arc. Their broad workflows reran frozen Alloy or J fixtures for resolution recoverability, offered-meaning acceptance, provenance compression, and future vocabulary refinement when unrelated research or production files changed. These four dedicated lanes graduate while their model/J/prose sources remain.

Observation 029 is a different case: it remains a selected live Lean proof obligation in `Loam.Observations`, and no dedicated `observation-029.yml` workflow exists on the current main. Its live responsibility is already carried by the selected Lean path rather than a historical one-observation CI lane.

Observations 030 and 031 also remain useful independent checks because their generic Event core and Locus-before-Account results still correspond directly to current Practical Core vocabulary. They therefore do not graduate. Instead, their trigger surface is narrowed from the broad shared research and production trees to only their own Alloy model or workflow file:

```text
KEEP + NARROW  observation-030 -> model/030_generic_event_core.als
KEEP + NARROW  observation-031 -> model/031_locus_before_account.als
```

This is the preferred distinction: a current independent check may stay live, but it should not claim responsibility for unrelated repository changes.

## Post-graduation surface comparison

| Metric | Checkpoint 226 baseline | Post-Phase 5 | Net change |
| --- | ---: | ---: | ---: |
| Candidate practical lines | 23,057 | **21,567** | **-1,490 lines (-6.5%)** |
| Candidate practical files | 151 | **137** | **-14 files (-9.3%)** |
| Unreachable practical lines | 1,155 | **0** | **-1,155 lines (-100%)** |
| Unreachable practical files | 11 | **0** | **-11 files (-100%)** |
| Practical-library-only lines | 676 | **341** | **-335 lines (-49.6%)** |
| Practical-library-only files | 6 | **3** | **-3 files (-50.0%)** |
| Dedicated CI workflows | ~90 | ~80 | **-10 workflows** |

## Exit rule

Phase 5 is **COMPLETE**:

1. The QuantityBasis/BasisCut historical probes and dedicated workflows have graduated;
2. All 10 retired practical production modules have been physically deleted with zero broken imports;
3. AccountingRole persistence residue is retired while Core `AccountingRole` remains available for provisional report research;
4. Integrated research documentation no longer treats QuantityBasis or retired numeric kernels as active Practical Core;
5. The repeatable graduation rule is established for all future observations.

Phase 6 (compare before/after complexity) may now proceed.

## Follow-up graduation - Observations 053-058 storage / relation foundation

A later repository-retirement pass revisited the early storage/relation experiments against current production ownership rather than observation age.

Observation 052 remains in the working tree because later provenance and falsification work still uses its Effect-identity counterexample as an active reference point. Observations 053-058 have a different status: their surviving laws have moved to current owners or their experimental surface has itself retired.

Current ownership is now explicit:

- Observation 053's rule that representation order is not semantic history is owned directly by `EventMemory`, including permutation-invariant lookup/quantity laws and the explicit representation-order contract;
- Observation 054's separation of logical fact meaning from physical storage topology is embodied by the current selected authority topology and compressed Observation Map rather than one global ordered fact log;
- Observation 055's distinction between raw publication topology and admitted semantic truth is now covered by current fail-closed authority/admission protocols;
- Observation 056's collection-identity pressure is owned by current memory/admission invariants rather than the old experiment-local relation collection;
- Observations 057-058 depended on the old `RelationAdmission` / `EventResolution` capability surface, which was later retired from production selection in #707.

No current workflow names any of the 053-058 experiment files as an executed fixture or path-owned verification source. Git history retains the exact Alloy models, prose, and prior qualified results.

The following historical laboratory apparatus therefore graduates from the working tree:

```text
experiments/053_storage_order_without_history.als
experiments/053_storage_order_without_history.md
experiments/054_canonical_fact_topology.als
experiments/054_canonical_fact_topology.md
experiments/055_publication_boundary.als
experiments/055_publication_boundary.md
experiments/056_relation_collection_identity.als
experiments/056_relation_collection_identity.md
experiments/057_derived_admission.als
experiments/057_derived_admission.md
experiments/058_relation_memory_append.als
experiments/058_relation_memory_append.md
```

This deliberately stops before Observation 059. The split-publication / recovery sequence still has dedicated operational SPIN coverage and therefore retains an independent current verification role.

## Follow-up graduation - intermediate Observation summaries 063-084

A repository-retirement pass found three intermediate research summaries that no longer own unique current knowledge:

```text
experiments/063_065_relation_family_audit.md
experiments/066_071_practical_core_audit.md
experiments/079_084_context_relative_sufficiency_audit.md
```

Their roles have been absorbed elsewhere:

- the 063-065 genericization stop point is covered by the current compressed design rule that similar relation-shaped meanings do not automatically earn one generic ontology, while the individual observations remain available;
- the 066-071 accounting/policy-pressure conclusion is summarized directly in the repository README and its surviving distinctions remain in individual experiments/current research;
- the 079-084 context-relative-sufficiency conclusion is part of the compressed 001-084 law in `OBSERVATION_MAP.md`, which explicitly replaced the earlier detailed map with current terrain.

None of these three filenames is referenced by a current workflow or current document. Their individual experiments, private dogfood checkpoints, current production laws, and Git history remain intact.

This graduation deliberately does not remove current private-source dogfood checkpoints such as the Series, refund-provenance, descriptive-context, or canonical-coverage audits. Those still record direct observations of the current private source boundary rather than merely an intermediate synthesis layer.

## Follow-up graduation - Observations 147-152 / 154 Actual wire research prose

The earlier repository-compression pass had already retired the executable Observation 147-152 apparatus and the Observation 154 fixture/workflow while deliberately leaving their research prose in place. A later retirement pass rechecked whether that prose still owns unique current knowledge.

It no longer does.

Current production has moved beyond the candidate arc:

- `Loam.ActualAuthority` now owns one canonical single-file normalized Actual authority (`actual.loam`);
- `NormalizedActualPersistence` owns the current normalized wire representation and fail-closed decode/encode admission;
- publication stages a complete candidate off-authority, re-decodes it, and switches authority with one atomic rename;
- the repository-compression census already classifies the 147-152 / 154 executable apparatus as graduated and closed.

The seven remaining experiment notes have no current filename references, no dedicated workflow, and no selected `Loam.Observations` proof module. Later documents that cite Observation numbers retain valid historical provenance through Git history.

The following distilled historical prose therefore graduates from the working tree:

```text
experiments/147_actual_validity_root_compression.md
experiments/148_compact_identity_rekeying.md
experiments/149_canonical_persistence_topology.md
experiments/150_unified_actual_generation.md
experiments/151_unified_actual_wire_shape.md
experiments/152_typed_section_codec.md
experiments/154_production_fixture_parity.md
```

Observation 153 is deliberately excluded because Scheduled routing subject semantics are a different research thread and were not part of the closed Actual identity/wire-shape retirement finding.

## Follow-up graduation - Observation 218 migration prose

Observation 218's theorem-heavy executable migration proof had already graduated to Git history after `ReplacementFrontier` became current production mathematics. The remaining Markdown record explicitly described itself as promoted historical evidence and pointed to current ownership beside the implementation.

A fresh ownership pass confirms that its surviving boundaries are no longer unique to that note:

- `Loam/Application/ReplacementFrontier.lean` owns the finite partial-successor-map mechanics and the current executable contract;
- `SEMANTIC_AUDIT_SA007_APPLICATION.md` explicitly keeps OpenRelation revision outside ReplacementFrontier;
- `OBSERVATION_MAP.md` retains the broader rule that similar-shaped meanings do not automatically earn one generic ontology;
- later Observation 274 / correspondence work owns stronger current theorem correspondence for the global-done implementation.

No current file refers to `experiments/218_partial_injective_frontier.md` by filename. Historical references to Observation 218 remain valid through Git history.

The final prose artifact therefore graduates from the working tree:

```text
experiments/218_partial_injective_frontier.md
```

## Follow-up graduation - Observation 212 Locus admission research apparatus

Observation 212 originally established that historically observed Locus identities are not sufficient authority for deciding which Loci may appear in new quantity-bearing canonical writes. Its selected result was one explicit current new-write admission vocabulary, independent from historical readability.

That law is now owned directly by current production:

- `Loam/Core/LocusAdmission.lean` states the Observation 212 boundary in its module contract and owns `LocusAdmissionVocabulary`;
- `Loam/Persistence/LocusAdmissionPersistence.lean` persists exactly that finite current vocabulary without deriving policy from Event history;
- `LocusAdmissionAuthority` owns the selected current policy authority;
- `MovementAdmission` enforces the vocabulary on quantity-bearing publication;
- later Generation-2 closure work extends the same current contract to newer quantity-bearing writers.

The original Alloy model and research note no longer own unique current knowledge, have no dedicated workflow, and are not referenced by filename from current documentation or code. Git history retains the exact model, witnesses, prose, and prior qualification.

The following historical apparatus therefore graduates from the working tree:

```text
experiments/212_locus_admission_vocabulary.als
experiments/212_locus_admission_vocabulary.md
```

Observation 213 remains. Alias / display / AccountingRole separation is a distinct follow-up question and is not implied by the Locus-admission production boundary.

## Follow-up graduation - Observations 216-217 AccountingRole report completeness

Observations 216-217 qualified two closely related reporting laws while AccountingRole was still research-only:

- missing AccountingRole evidence remains an unresolved classification witness rather than becoming an `UnknownRole`, zero, irrelevance, or a guessed role;
- exact role quantities may be published for classified evidence while unresolved evidence remains visible;
- numerical cancellation of unresolved evidence, including net zero, must not be used as a completeness proof;
- role totals are derived presentation values and must not erase the unresolved evidence frontier.

Those laws now have current production owners:

- `Loam/Core/AccountingRole.lean` owns the partial `LocusId -> AccountingRole` relation and explicitly treats missing role evidence as unresolved;
- `RoleFlowReview` preserves individual unresolved Effect witnesses so cancellation cannot masquerade as classification completeness;
- `RoleBalanceReview` keeps quantity-supported unresolved-role coordinates and quantity-unsupported coordinates as separate frontiers;
- Observation 275 proves that missing AccountingRole remains explicit unresolved metadata on a current routing answer;
- Generation-2 closure explicitly keeps unresolved Effect witnesses and rejects stored role totals as an independent semantic owner;
- current production tests exercise the unresolved-role and support-frontier behavior.

The original Alloy models and research notes have no dedicated workflows and no current filename references. Git history retains the exact bounded witnesses and qualification receipts.

The following historical apparatus therefore graduates from the working tree:

```text
experiments/216_partial_accounting_role_report.als
experiments/216_partial_accounting_role_report.md
experiments/217_partial_accounting_role_quantity.als
experiments/217_partial_accounting_role_quantity.md
```

Observations 214-215 remain. Their destructive migration / mixed legacy Locus questions are not equivalent to the currently qualified virgin-Locus AccountingRole publication boundary.

## Follow-up graduation - normalized Actual cutover research

A later retirement pass found two normalized-Actual research artifacts whose current-tree wording no longer matched production reality:

```text
docs/research/NORMALIZED_ACTUAL_WIRE.md
experiments/normalized_actual_cutover.als
```

The wire note still classified production migration as blocked and referenced a synthetic Python qualification tool that is no longer present. The cutover Alloy model describes the one-time old-runtime -> normalized-runtime transition, including quiesced selection and old-byte retirement.

That migration has since completed. Current ownership is explicit:

- PR #756 graduated Actual to one canonical `actual.loam` authority and retired legacy fallback readers and dual-format runtime behavior;
- `ActualAuthority` owns the single-file authority path, writer ownership, staged candidate verification, and atomic rename publication;
- `NormalizedActualPersistence` and `NormalizedActualAdmission` own the current wire and fail-closed semantic admission;
- `NormalizedActualPersistenceTest` exercises the production representation directly.

Neither retired artifact has a current filename reference or dedicated workflow. Git history retains the historical candidate wire, synthetic qualification, and exact cutover model.

The other normalized-Actual Alloy models remain for now. Effect identity promotion, Scheduled completion across independent authorities, and dependency-sensitive writer guarding still express distinct live questions not reduced to the completed one-time cutover.

