# Compression audit Phase 5 — research and CI graduation

Status: **COMPLETE — FIRST GENERATION GRADUATED**

Phases 1–4 established a distinction that the repository did not previously enforce strongly enough:

```text
historical evidence != current production dependency
historical proof source != forever-live CI obligation
```

LOAM has intentionally accumulated many observations. That was useful while the semantic basis was unknown. It becomes accidental complexity when an observation that has already been superseded requires obsolete production modules to remain compilable on every future pull request.

## Graduation rule

A historical Observation may graduate out of live CI when all of the following hold:

1. its question, witness/counterexample, and conclusion remain recorded in durable research prose;
2. Git history retains the exact historical executable/model source and its previously successful CI state;
3. a later observation or current production invariant subsumes the practical decision for which the old probe was needed;
4. no current executable, authority, current library contract, or active research branch needs the historical implementation boundary;
5. deleting the old executable probe does not erase a currently unique theorem required by production.

Graduation means:

```text
KEEP   the research markdown and integrated conclusion
KEEP   Git history as the exact historical proof artifact
REMOVE superseded executable probe source when it depends on retired APIs
REMOVE its dedicated always-live workflow
REMOVE production residue that existed only to keep that historical probe compiling
```

This is not deletion of history. It is stopping the historical laboratory apparatus after its result has been recorded.

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

Their corresponding prose records remain. Observation 218's reusable result is additionally embodied in current `ReplacementFrontier`; its QuantityBasis branch is not the only surviving evidence for that mechanic.

The dedicated workflows tied to these probes are therefore candidates for graduation rather than continued execution against every future production change.

## Why this generation is safe to graduate

The important current meanings survive elsewhere:

- zero-origin completeness is explicit `ZeroOriginCoverage` production evidence;
- Event correction still uses current `ReplacementFrontier` mechanics;
- ActualValidity correction still uses current frontier mechanics;
- Scheduled replacement still uses current frontier mechanics;
- current balance readers use the current zero-origin path;
- Observation 219 markdown records the real household parity and negative controls;
- later production-boundary research records that QuantityBasis/BasisCut is no longer on the household production path.

What disappears is the obligation to keep a retired basis ontology executable merely so historical probes continue to compile.

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
superseded history     -> prose + Git history, dedicated CI retired
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
