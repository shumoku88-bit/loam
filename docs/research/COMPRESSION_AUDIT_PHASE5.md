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

## Follow-up graduation - QuantityBasis Application CI 008-009

Applications 008 and 009 were bounded candidate probes from the old starting-quantity design arc. Both Lean files are self-contained under `import Std` and define their own experiment-local basis vocabulary rather than exercising the current production boundary. Their prose explicitly presents the names and production placement as not yet established.

The later QuantityBasis/BasisCut generation was subsequently implemented, audited against real household data, and retired in favor of explicit zero-origin coverage. Keeping these earlier candidate probes alive on `lakefile.lean`, toolchain, or manifest changes therefore no longer protects a current implementation or theorem.

Keep the two Lean probes and their research prose as historical design evidence. Graduate only their dedicated CI lanes:

```text
.github/workflows/application-008-starting-quantity-basis.yml
.github/workflows/application-009-append-only-basis-revision.yml
```

A renewed starting-quantity question should earn a new active probe against the current zero-origin model rather than perpetually recompiling this superseded candidate ontology.

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
