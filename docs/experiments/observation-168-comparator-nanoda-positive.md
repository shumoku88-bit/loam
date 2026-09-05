# Observation 168 — Comparator + Nanoda positive field trial

## Question

After Observations 165–167 established Comparator acceptance, statement-drift rejection, and axiom-policy rejection, can the same reviewed proof also be accepted by an independent Lean kernel implementation through Comparator's Nanoda integration?

## Trial

`Challenge.lean` and `Solution.lean` expose the same small concrete integer statement used in the earlier Comparator field trials. The Solution proves it by reflexivity.

CI builds Comparator and lean4export at the same pinned v4.33.0 revisions used in Observations 165–167, and builds `robsimmons/nanoda_lib` at commit `68d5ca9db226849b41a6fff59d796ff19d0a8840`, a pin used by current Lean verification infrastructure.

Comparator runs with `enable_nanoda: true`, so an accepted solution must pass both Comparator's Lean-kernel replay and Nanoda's independent checker.

## Temporary axiom allowance

This trial permits `propext` even though the target proof itself is reflexive. Current Comparator/Nanoda integration has a known primitive-export issue in which exported builtin targets can make Nanoda observe `propext` even when the target theorem does not use it directly. Observation 168 records that compatibility allowance rather than pretending the empty-axiom trial still applies unchanged.

## Boundary

This tests checker diversity, not human-intent alignment. The trusted Challenge remains human-reviewed. It also still uses Comparator's `fake-landrun.sh` development shim, so success does not establish adversarial build sandboxing.

## Expected result

Comparator accepts the exact Challenge/Solution statement and both the Lean kernel and Nanoda accept the exported proof environment.

## Stop condition

Do not make Nanoda mandatory across LOAM from this one trial. First establish that the pinned integration runs cleanly and understand any compatibility allowances it requires.
