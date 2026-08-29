# Observation 015 — Commitment identity summary

## Question

Observation 014 established that active commitment can be projected from an intentional Declare/Release history rather than stored as primitive `Unit -> Purpose` state.

Can that derived active relation itself be compressed further when the current physical placement is already available?

The candidate compression is:

```text
active commitment : Unit -> Purpose

becomes

committed Units    : set Unit
current placement  : Unit -> Purpose
```

with the active Purpose reconstructed from placement for each committed Unit.

## Why this is plausible

Observation 014's commitment law requires an active commitment to be honored by the Unit's physical placement at the observation point. Therefore the Purpose coordinate is not independent at that point:

```text
committed Unit + current placement
              -> active Unit -> Purpose
```

The remaining question is whether retaining only Unit identity is sufficient, and whether an even coarser aggregate such as the number of committed Units loses something future-visible.

## Alloy observation

Alloy 6.2.0 / Sat4j executed the model with exactly:

```text
5 Time
2 Purpose
4 Unit
```

Results:

```text
samePhysicalSameCountDifferentCommittedIdentity  SAT
PhysicalTraceDeterminesCommittedUnits             SAT
CommittedCountDeterminesPermission                 SAT
CommittedUnitsPlusPlacementReconstructsActive      UNSAT
CommittedUnitsDetermineActiveGivenPhysicalTrace    UNSAT
CommittedUnitsDeterminePermission                  UNSAT
CommittedUnitsDetermineReleaseEnabled              UNSAT
```

The two SAT checks are counterexamples to the corresponding determinability claims.

### Count loses the identity axis

Alloy found two worlds with the same complete physical trace and the same number of committed Units, but different committed Unit identities. It selected `Unit3` and `Purpose1` for a visible permission difference.

So this summary is too coarse:

```text
# committed Units
```

Knowing that one Unit is committed does not say which Unit is constrained.

This repeats the pattern first exposed by Observation 004: information can be present along the wrong identity axis.

### Unit identity plus placement reconstructs Purpose

No counterexample was found to:

```text
reconstructedActive[w, present]
  = activeCommitment[w, present]
```

where reconstruction is:

```text
for each committed Unit u:
  active Purpose = current physical Purpose of u
```

The same compressed summary also preserved current reassignment permission and prospective Release enabledness in the bounded Alloy universe.

## TLA+ behavioral observation

The TLA+ model keeps two representations in the same state:

```text
oracle:   active    : Unit -> (Purpose or none)
summary:  committed : set Unit
physical: place     : Unit -> Purpose
```

It explores the finite operation vocabulary:

```text
Declare
Release
Reassign
Use
```

The summary updates in parallel with the oracle relation. Invariants require:

```text
committed = {u | active[u] is present}
active = reconstruct(committed, place)
```

and require both representations to agree on enabledness for every operation in the chosen vocabulary.

TLC 2.19 completed the reachable-state search:

```text
4 initial states
100 states generated
36 distinct states found
0 states left on queue
depth 3
no error
```

Thus the compressed summary remained sufficient throughout every reachable behavior in this deliberately finite model.

## Finding

Observation 013 said commitment-bearing information cannot be recovered from physical history alone.

Observation 014 said active commitment need not itself be primitive state because Declare/Release history can project it.

Observation 015 now removes another coordinate:

```text
intentional history
      |
      | Observation 014
      v
active Unit -> Purpose
      |
      | Observation 015
      v
committed Unit identity
      +
current physical placement
      |
      v
active Unit -> Purpose
```

For the current laws and operation vocabulary, the Purpose coordinate of active commitment is redundant on the intentional side. Physical placement already supplies it.

The intentional summary must still retain identity. Replacing `set Unit` with only its count loses future-visible permission distinctions.

A useful sharper statement is therefore:

> The boundary between physical and intentional state need not duplicate coordinates that a law already couples, but it must preserve the identity distinctions the future vocabulary can address.

## Boundary

This does **not** prove that `set Unit` is the unique or globally minimal representation of commitment information.

Observation 008 already showed that sufficient representations can use different coordinate systems. Another encoding could preserve the same collision classes without literally storing a Unit set.

The result is also conditional on the current commitment law. If a future vocabulary allows a commitment to name a Purpose different from current placement, records provenance independently, permits partially honored commitments, or asks about why/by whom a commitment was made, then Unit identity plus placement may no longer be sufficient.

The TLA+ result is exhaustive only for its finite universe of two Units, two Purposes, and the four modeled operations.

## Next pressure point

The remaining word `committed` is now suspicious in a more precise way.

Is the identity-bearing membership itself the future-observable equivalence class induced by the current operation vocabulary, or is it merely one convenient coordinate system for that class?

That question would distinguish:

```text
what information must survive
```

from:

```text
what field or relation happens to store it
```
