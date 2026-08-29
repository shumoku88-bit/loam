# Observation 021: Can repeated correction remain a chain?

## Question

Observation 020 showed that one append-only Correction can change the effective interpretation of an earlier Commit without rewriting it.

What happens when the same meaning is corrected again?

Is `last correction wins` a primitive conflict-resolution rule, or can it emerge from a smaller structural law?

## Tool choice

Alloy + TLA+.

Alloy asks whether weak correction structure can branch and whether a linear chain has a unique terminal interpretation.

TLA+ asks whether repeated correction remains coherent through time when a new Correction may target only the current chain tip.

No J, Lean, or miniKanren is needed for this question.

## Structural observation

The Alloy model compares:

```text
weak:
  c0 <- k0
  c0 <- k1

chain:
  c0 <- k0 <- k1
```

Executed with Alloy 6.2.0 + Sat4j:

```text
branchingAmbiguity         SAT
LinearChainHasUniqueTip    UNSAT
LinearChainTipIsK1         UNSAT
```

The weak shape admits two terminal corrections that disagree about meaning. Nothing in that shape chooses one as authoritative.

The linear shape has one terminal interpretation.

## Temporal observation

The TLA+ model begins with:

```text
<<c0>>
```

and admits a Correction only when its target is the current tip.

The complete reachable state graph was:

```text
1 initial state
4 states generated
4 distinct states found
0 states left on queue
complete state graph depth: 4
```

No invariant or temporal property failed.

The checked properties include:

- exactly one correction-chain tip,
- tip equals the mutable oracle tip,
- effective Purpose and quantity equal the oracle,
- the latest appended interpretation equals the chain tip,
- every Correction targets an earlier interpretation,
- an admissible Correction replaces exactly the current tip,
- history only extends.

A separate expected invariant failure demonstrated the full repeated-correction path:

```text
<<c0>>
<<c0, k0>>
<<c0, k0, k1>>
<<c0, k0, k1, k2>>
```

with effective meaning changing at each tip:

```text
c0: p0 / 1
k0: p1 / 1
k1: p2 / 2
k2: p1 / 1
```

## Finding

> `Last correction wins` need not be a primitive rule when correction admission preserves one linear chain.

A smaller candidate law is:

> A new Correction may correct only the current interpretation tip.

Under that law, the most recently appended Correction is the current meaning as a consequence of the chain structure.

Without such a law, append-only Correction can branch, and chronology alone becomes an extra conflict-resolution authority.

## Boundary

This observation deliberately does not decide:

- concurrent corrections,
- merging correction branches,
- distributed arrival order,
- correction of already-reversed commitments,
- whether all corrections should be full replacements or field patches,
- whether a legitimate correction may reveal a state that violates a current admission rule.

Those questions may require a richer relation than a single linear chain.
