# Observation 166 — Comparator negative statement drift

## Question

After Observation 165 established that upstream Comparator accepts an exact trusted Challenge/Solution pair, will it mechanically reject a solution theorem whose statement has drifted while remaining independently provable?

## Trial

The trusted challenge states two concrete coordinate equalities:

- wallet: `-100 = -100`
- food: `100 = 100`

The deliberately drifted solution keeps the same theorem name and a provable wallet equality, but replaces the food statement with `50 = 50`.

Both modules compile independently. The expected observation is that Comparator rejects the pair because theorem statements differ.

## Expected result

The CI job is green only when Comparator exits nonzero for the drifted pair. If Comparator accepts the pair, the job fails.

This turns rejection into the observed success condition rather than committing a permanently red workflow.

## Boundary

This trial tests statement mismatch rejection only. It does not add Nanoda, does not test axiom-policy violations, and still uses Comparator's fake-landrun development shim rather than claiming hostile-build sandboxing.

## Next pressure

If the negative rejection is stable, the next useful question is whether enabling Nanoda adds independent checker diversity without expanding the trusted semantic surface.
