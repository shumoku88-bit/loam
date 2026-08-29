# Observation 023: Can Resolution Be Append-Only?

## Question

Observation 022 showed that two conflicting Corrections can remain append-only facts while the current projection truthfully reports an unresolved frontier.

This observation asks the next question:

> Can that conflict be resolved without deleting either Correction and without pretending one branch never existed?

## Tool choice

Alloy + TLA+ only.

- Alloy observes the static frontier geometry of full versus partial resolution.
- TLA+ observes the temporal path from settled, through conflict, back to settled while preserving append-only history.
- J is not needed because no quantitative array shape is under comparison.
- Lean is not yet earned because no new general theorem is being preserved.
- miniKanren is not needed because no inverse synthesis question is being asked.

## Structural model

The unresolved frontier from Observation 022 is:

```text
c0 <- kA
c0 <- kB

frontier = {kA, kB}
```

Observation 023 introduces a new Interpretation `r0`.

A full-frontier Resolution is:

```text
kA \
    r0
kB /
```

where:

```text
r0.parents = {kA, kB}
```

A deliberately partial Resolution names only one branch:

```text
kA -> r0
kB
```

The current frontier is always derived from interpretations that have no later seen child.

## Alloy 6.2.0 + Sat4j

Executed result:

```text
conflictBeforeResolution              SAT
fullResolutionSettles                 SAT
partialResolutionLeavesConflict       SAT
WholeFrontierResolutionSettles        UNSAT
WholeFrontierResolutionHasUniqueTip   UNSAT
PartialResolutionDoesNotSettle        UNSAT
```

Interpretation:

- the two-Correction conflict is reachable;
- appending `r0` with the whole conflict frontier as its parents produces one frontier tip, `r0`;
- appending `r0` with only `kA` as parent leaves `kB` terminal, so the frontier remains `{kB, r0}`;
- no counterexample was found to full-frontier Resolution settling the frontier;
- no counterexample was found to the resulting frontier being unique;
- no counterexample was found to partial Resolution leaving the unresolved branch visible.

So merely appending a node called Resolution is not sufficient. The relation it records matters.

A Resolution that settles this conflict must cover the current conflicting frontier, not merely one convenient branch.

The first Alloy CI attempt did not evaluate model semantics because `before` was used as a predicate parameter name and Alloy 6 treats it as temporal syntax. Renaming that parameter to `prior` was the only correction; the same model question then produced the result above.

## Temporal model

The TLA+ history begins at:

```text
<<c0>>
```

Corrections may arrive in either order. Resolution `r0` is appendable only when:

```text
Corrections are both already present
and
current frontier = {kA, kB}
```

The two complete histories are therefore:

```text
<<c0, kA, kB, r0>>
<<c0, kB, kA, r0>>
```

No earlier fact is removed.

## TLA+ tools 1.7.4 / TLC 2.19

Positive complete-state exploration:

```text
1 initial state
7 states generated
7 distinct states found
0 states left on queue
complete state graph depth: 4
```

No error was found for:

- event-history type safety;
- conflict remaining unresolved before Resolution;
- Resolution being enabled only for the whole current conflict frontier;
- resolved history projecting to frontier `{r0}`;
- resolved current state being single-meaning again;
- both conflicting Corrections remaining in provenance after Resolution;
- arrival order not changing the resolved current view;
- append-only prefix growth.

Separate expected invariant failures demonstrated both complete histories are genuinely reachable:

```text
<<c0, kA, kB, r0>>
<<c0, kB, kA, r0>>
```

Both reach the same resolved frontier.

## Finding

A correction conflict can be resolved append-only in this bounded vocabulary.

More precisely:

```text
correction frontier
   {kA, kB}
       |
       | append r0 with both as parents
       v
resolved frontier
      {r0}
```

The old alternatives are not erased:

```text
history contains c0, kA, kB, r0
```

but they cease to be current frontier candidates because a later Interpretation explicitly receives them.

This suggests a small interpretation graph:

```text
Correction = a new Interpretation with one parent
Conflict   = more than one frontier Interpretation
Resolution = a new Interpretation with the whole conflict frontier as parents
Current    = the frontier projection
```

For the bounded model, chronology is still provenance rather than authority. `r0` settles both arrival orders because its authority comes from the relation to the whole frontier, not from which Correction arrived last.

## Important distinction

This observation does **not** say that `r0` is automatically correct.

It only establishes a structural possibility:

> if a Resolution is admitted, it can preserve all prior facts while replacing a conflicting frontier with one new current Interpretation.

The model deliberately does not answer where the meaning carried by `r0` comes from.

That is a different question from whether append-only resolution is structurally possible.

## Boundary

This observation does not model:

- who or what is allowed to create a Resolution;
- evidence required to justify a Resolution;
- how the resulting meaning of `r0` is chosen;
- automatic merging of compatible Corrections;
- partially overlapping correction patches;
- multiple successive Resolution events;
- correcting a Resolution later;
- resolving a conflict that spans multiple independent source observations;
- distributed identity or network consensus.

## Next pressure

The structural question now moves from **whether** a conflict can be resolved append-only to **what makes a Resolution admissible**.

A useful next observation is:

> Does a Resolution need new authority or evidence beyond the conflicting frontier itself?

If two identical histories can admit different `r0` meanings, then the graph structure alone does not determine Resolution meaning. That would separate provenance structure from the source of authority that chooses a new interpretation.
