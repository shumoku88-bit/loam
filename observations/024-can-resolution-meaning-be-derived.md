# Observation 024: Can Resolution Meaning Be Derived?

## Question

Observation 023 found that a correction conflict can be resolved structurally without deleting either branch when a later Resolution receives the whole current frontier as its parents.

That leaves a different question open.

If two worlds have the same conflicting Corrections, the same prior meanings, and the same full-frontier Resolution relation, does that structure determine what the Resolution means?

## Tool choice

Alloy only.

- Alloy is enough to ask whether the same fixed conflict structure admits multiple Resolution meanings.
- TLA+ is not needed because no temporal ordering or liveness question is under comparison.
- J is not needed because no quantitative projection is involved.
- miniKanren is not needed because no inverse synthesis question is being asked.
- Lean is not yet earned because no new general law is being preserved.

## Fixed conflict structure

Both worlds share:

```text
c0 meaning = M0
kA meaning = MA
kB meaning = MB

kA -> c0
kB -> c0

kA \
    r0
kB /
```

The graph and all prior meanings are fixed. Only `r0`'s meaning may differ between worlds.

The observation deliberately does not add an Evidence, Authority, Decision, merge rule, or selection rule. If the conflict structure alone is sufficient, none of those should be needed to determine the result.

## Alloy 6.2.0 + Sat4j

Executed result:

```text
sameConflictDifferentResolutionMeaning   SAT
sameConflictSameResolutionMeaning        SAT
parentMeaningResolution                   SAT
thirdMeaningResolution                    SAT
ConflictHistoryDeterminesResolutionMeaning SAT
ResolutionMeaningMustBeParentMeaning      SAT
ResolutionMeaningMustBeNewMeaning         SAT
WholeFrontierResolutionStillSettles       UNSAT
```

For the three checked semantic assertions, `SAT` means Alloy found a counterexample.

So the fixed conflict history does not determine one Resolution meaning. The same structure admits worlds in which the Resolution meanings differ, and also worlds in which they agree.

Neither of these semantic policies follows from the structure:

```text
Resolution must inherit one parent meaning
Resolution must introduce a new meaning
```

Both are independently refuted by counterexamples.

At the same time, the structural result from Observation 023 survives: no counterexample was found to the claim that the full-frontier Resolution leaves `r0` as the unique frontier tip.

## Finding

The conflict graph determines what the Resolution receives, but not what meaning the Resolution is justified in carrying.

More compactly:

```text
full conflicting frontier
          |
          v
      Resolution
          |
          +-- structurally settles the frontier
          |
          `-- resulting meaning remains underdetermined
```

Observation 023 and Observation 024 therefore separate two questions that can otherwise look like one:

```text
What was resolved?              -> named by the parent frontier
What is the resulting meaning?  -> not derived from that relation alone
```

This does not imply that an arbitrary Resolution meaning should be accepted. It says only that the current structural vocabulary contains no law that can distinguish a justified result from another structurally compatible result.

## Boundary

This observation is bounded to the finite Alloy scope used here.

It does not model:

- evidence supporting a Resolution;
- who or what may create one;
- a deterministic merge or selection rule;
- compatibility between parent meanings;
- provenance for why one resulting meaning was chosen;
- whether a Resolution may reuse one parent's meaning in a real household vocabulary;
- temporal arrival of facts that could justify a later result.

Those concepts should not be introduced merely to fill the gap. The next experiment should first ask what additional information or law is actually sufficient to remove the underdetermination.

## Next pressure

The next question is no longer whether the conflict graph itself determines the result.

It does not in this model.

The useful pressure is now:

> What is the smallest additional distinction that makes a Resolution meaning recoverable rather than arbitrary?
