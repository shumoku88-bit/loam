# Observation 165 — Comparator field trial

## Question

After Observation 164 separated a reviewed statement surface from LOAM's implementation vocabulary, does running the upstream Lean Comparator add a useful mechanical boundary without introducing a LOAM-specific verification framework?

## Trial

The isolated project under `verification/observation165/` contains:

- `Challenge.lean`: the trusted reviewed statement, using only concrete integer observables;
- `Solution.lean`: a proof candidate with the exact same theorem name and statement;
- `config.json`: one theorem target and an empty permitted-axiom set;
- a Lean 4.33.1 toolchain and pinned Comparator / lean4export v4.33.0 dependencies.

CI invokes the upstream `leanprover/comparator` executable. Comparator is expected to reject statement mismatch or unpermitted axioms and replay the accepted solution through the Lean kernel.

## Deliberate boundary

This first field trial uses Comparator's `fake-landrun.sh` development shim. Therefore a successful run is evidence for statement comparison, axiom restriction, and kernel replay in this trusted repository workflow, but **not** evidence of adversarial solution sandboxing.

Nanoda is also deliberately absent. Independent-kernel diversity is a later question.

The trusted Challenge remains human-reviewed. Comparator cannot establish that the Lean statement captures human intent.

## Expected result

The exact reviewed statement and proof candidate qualify with no permitted axioms.

## Stop condition

Do not build a LOAM-specific comparator clone, generic contract framework, or broad verification policy from this observation alone. First determine whether the upstream tool runs cleanly and whether its additional boundary is useful in practice.
