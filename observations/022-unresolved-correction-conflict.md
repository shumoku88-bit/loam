# Observation 022: Can Correction Conflict Remain Unresolved?

## Question

Observation 021 found that repeated Correction can remain append-only and unambiguous when only the current interpretation tip may be corrected.

This observation removes that admission rule deliberately.

If two Corrections both target the same current interpretation, must chronology choose one winner, or can the branch itself become a truthful current state?

## Tool choice

Alloy + TLA+ only.

- Alloy observes the static distinction between a linear correction chain and a branching correction relation.
- TLA+ observes both arrival orders and checks whether the same conflict projection is reached without making order authoritative.
- J is not needed because no quantitative array shape is under comparison.
- Lean is not yet earned because no new general theorem is being preserved.
- miniKanren is not needed because no inverse synthesis question is being asked.

## Structural model

The linear shape from Observation 021 is:

```text
c0 <- kA <- kB
```

The deliberately weakened shape is:

```text
c0 <- kA
c0 <- kB
```

`kA` and `kB` carry distinct meanings.

The current candidates are the terminal interpretations. A branch with more than one terminal candidate is projected as unresolved.

## Alloy 6.2.0 + Sat4j

Executed result:

```text
branchingAmbiguity          SAT
WeakBranchIsUnresolved      UNSAT
LinearChainHasUniqueTip     UNSAT
LinearChainTipIsKB          UNSAT
```

Interpretation:

- weak branching is reachable and leaves both `kA` and `kB` terminal;
- under that shape, no counterexample was found to the claim that the current interpretation is unresolved;
- the linear shape still has one unique tip;
- in the concrete linear shape, that tip is `kB`.

So branching does not require inventing a chronological winner merely to obtain a representable current state.

## Temporal model

The TLA+ history begins at:

```text
<<c0>>
```

and may append `kA` and `kB` in either order.

The current projection is intentionally order-insensitive:

```text
kind       = conflict
candidates = {kA, kB}
```

when both Corrections have appeared.

An operation that requires exactly one current meaning is enabled only when the candidate set has cardinality one.

## TLA+ tools 1.7.4 / TLC 2.19

Positive complete-state exploration:

```text
1 initial state
5 states generated
5 distinct states found
0 states left on queue
complete state graph depth: 3
```

No error was found for:

- history type safety;
- conflict never silently enabling a single-meaning operation;
- both Corrections projecting to the complete candidate set;
- arrival order not changing the conflict view;
- append-only prefix growth.

Separate expected invariant failures demonstrated both histories are genuinely reachable:

```text
<<c0, kA, kB>>
<<c0, kB, kA>>
```

Both project to the same unresolved candidate set.

The first TLA+ CI attempt did not evaluate these semantics because the module omitted `Naturals` while using natural-number comparisons. After importing `Naturals`, the same model and question completed as above.

## Finding

A correction conflict can itself be a derived current state.

More precisely:

```text
append-only correction facts
          |
          v
terminal interpretation set
          |
          +-- one candidate  -> settled
          |
          +-- many candidates -> conflict
```

Arrival chronology can remain provenance without becoming authority.

The observation therefore does not need either:

```text
first correction wins
```

or:

```text
last correction wins
```

as an automatic conflict rule.

When conflicting terminal interpretations coexist, the truthful current result can instead be:

```text
unresolved {kA, kB}
```

and operations requiring one current meaning can remain unavailable.

## Boundary

This observation does **not** establish how conflict should be resolved.

It does not model:

- a Resolution event;
- merging two Corrections;
- choosing one Correction explicitly;
- partial compatibility between patches;
- distributed identity or network ordering;
- correction of already-reversed commitments;
- whether all household operations must stop while one interpretation is unresolved.

Those are separate questions.

## Next pressure

The next useful question is no longer whether conflict can be represented.

It can.

The pressure now moves to resolution:

> Can a later append-only relation resolve a conflict without deleting either conflicting Correction and without pretending one of them never existed?
