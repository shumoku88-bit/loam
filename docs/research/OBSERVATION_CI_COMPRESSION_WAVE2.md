# Observation CI Compression — Wave 2

Status: **candidate consolidation after Compression Checkpoint 226**

Analysis baseline: `c765cd37a8e1edcc4cc0eac9f12d0aeb1dce0e0b`
Synchronized main: `726909ecf35243f3df50e0e828b0a5a2edf0dd9e`

## Question

Which named observation workflows still contribute an independently observable verification capability, and which merely rebuild Lean proof modules already owned by the selected observation umbrella?

The governing distinction is:

```text
historical research result
!= dedicated live CI runner
```

A workflow earns independent retention when it still runs a distinct observation instrument or checks a distinct operational boundary. Examples include Alloy, TLA+, SPIN, J, Scheme, fixture parity, or other explicit witnesses not reproduced by building `Loam.Observations`.

A workflow does not earn independent retention merely because the proof once had its own observation number.

## Shared Lean owner

`Loam/Observations.lean` explicitly selects the Lean proofs that remain live obligations. `.github/workflows/selected-lean-observations.yml` is the CI owner for that umbrella.

Therefore a per-observation workflow is redundant when all of the following hold:

1. its proof module is already imported by `Loam.Observations`;
2. its only independent verification action is `lake build` of that module;
3. it does not execute an external solver, a distinct fixture/integration check, or another independent witness.

## Retired duplicate runners in this wave

The following 28 workflows satisfy that rule and are retired without deleting their Lean proof sources:

```text
observation-147-actual-validity-root-compression.yml
observation-148-compact-identity-rekeying.yml
observation-149-canonical-persistence-topology.yml
observation-150-unified-actual-generation.yml
observation-151-unified-actual-wire-shape.yml
observation-152-typed-section-codec.yml
observation-159-free-abelian-projection-boundary.yml
observation-161-statement-alignment-contract.yml
observation-162-statement-contract-field-trial.yml
observation-163-definition-drift-boundary.yml
observation-164-independent-statement-surface.yml
observation-179-preservation-galois-polarity.yml
observation-180-observational-closure.yml
observation-181-budget-window-derived-projection.yml
observation-183-conservative-same-day-funding.yml
observation-184-multiday-conservative-funding.yml
observation-185-typed-hypothetical-decision-support.yml
observation-186-scheduled-suppression-overlay.yml
observation-188-description-vs-decision-role.yml
observation-189-separate-choice-commitment-funding.yml
observation-191-observational-quotient-factorization.yml
observation-192-future-context-equivalence.yml
observation-193-correction-future-context.yml
observation-194-fail-closed-future-definedness.yml
observation-195-semantic-result-observation.yml
observation-196-budget-window-selection-pressure.yml
structural-s003-split-merge-invariance.yml
structural-s008-correction-chain-length.yml
```

The corresponding Lean modules remain selected by `Loam.Observations` and therefore remain executable proof obligations.

## Explicit KEEP controls

This wave deliberately preserves workflows whose names may look historical but whose CI still performs a distinct observation:

- Observation 001: Alloy structure exploration plus J projection;
- Observation 003: TLA+ model checking for history-sensitive futures;
- Observation 011: Alloy bounded witness/check;
- Observation 183 discharge-target identity: SPIN safe/unsafe identity-reservation models.

The same rule applies to other remaining workflows: tool identity alone is not enough, but independent observable verification is.

## Separate fan-out issue

Many early per-observation workflows still include broad paths such as:

```text
.github/workflows/observation-*.yml
```

That causes one observation-workflow edit to start unrelated historical checks. This wave does not rewrite those solver-bearing workflows while also deleting the Lean-only duplicates. Removing cross-workflow trigger fan-out is the next independent CI-compression step.

## Safety criterion

This wave is successful only if the exact-head `Selected Lean Observations` workflow builds `Loam.Observations` successfully. No Core, Application, Persistence, writer, authority, TUI, or canonical-data semantics are changed here.
