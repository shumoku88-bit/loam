# Observation 167 — Comparator axiom-policy rejection

## Question

After Observation 165 established Comparator acceptance and Observation 166 established statement-drift rejection, does upstream Comparator also reject a proof whose theorem statement matches exactly but whose proof depends on an axiom outside the configured allowlist?

## Trial

The trusted `Challenge.lean` and untrusted `Solution.lean` expose the same theorem statement.

The Solution introduces `Observation167.unpermitted_fact` as an axiom and proves the target theorem only through that axiom. Comparator is configured with an empty `permitted_axioms` list.

Both modules should compile independently. The observation succeeds only when Comparator exits nonzero and names the unpermitted axiom in its rejection output.

## Expected result

Comparator rejects the Solution because `Observation167.unpermitted_fact` is reachable from the target proof but absent from `permitted_axioms`.

## Boundary

This observation tests axiom-policy enforcement only. It still uses Comparator's `fake-landrun.sh` development shim and therefore does not establish adversarial build sandboxing. It also does not add an external kernel such as Nanoda.

## Stop condition

Do not generalize Comparator into a mandatory LOAM-wide framework from this observation alone. First establish the smallest positive/negative evidence for the guarantees LOAM actually needs.
