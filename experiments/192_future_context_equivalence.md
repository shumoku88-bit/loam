# Observation 192 — future-context equivalence

## Question

Observation 029 made retained-state sufficiency relative to a future question vocabulary, and Observation 191 showed that selected observations induce an observational quotient with a factorization/closure reading.

Does the old LOAM phrase

```text
future vocabulary
  -> observable distinctions
  -> sufficient retained state
```

remain a purely static observation quotient, or do allowed future operations induce a stricter dynamic quotient?

## Candidate

For deterministic state transition

```text
step : State -> Operation -> State
```

and selected terminal questions, define:

```text
left ~future right
iff
for every finite operation continuation c
and every selected question q,
answer(run(left, c), q) = answer(run(right, c), q)
```

This is intentionally a Nerode-style / behavioural-equivalence candidate rather than a claim that LOAM is a finite automaton.

## Lean result

`Loam/Observations/Observation192.lean` proves generically that `FutureEquivalent`:

- is reflexive, symmetric, and transitive;
- refines Observation 029 current observational equivalence by the empty continuation;
- remains equivalent after applying the same next operation to both sides;
- is itself current-observation-sound and step-stable;
- contains every other relation that is both current-observation-sound and step-stable.

Thus it is the greatest relation, by inclusion, satisfying those two requirements.

## Bridge to Observations 029 and 191

Lift the question language from:

```text
Question
```

to:

```text
List Operation × Question
```

where the observation first runs the continuation and then asks the terminal question.

Lean proves:

```text
FutureEquivalent
  iff
Observation029.Equivalent on contextual questions
```

and also:

```text
FutureEquivalent
  iff
Observation191.IndistinguishableBy on contextual questions
```

So Observation 191's quotient/factorization machinery does not need a new mathematical core to handle future contexts. The dynamic extension appears by enriching what counts as an observation.

## Strict witness

A two-bit state retains:

```text
visible
hidden
```

The only current question asks for `visible`. One allowed operation `reveal` copies `hidden` into `visible`.

Two states

```text
(false, false)
(false, true)
```

are currently observationally equivalent, but after one `reveal` operation they become distinguishable.

Therefore current equivalence can be strictly coarser than future-context equivalence.

## Sufficiency consequence

Encoding only the current `visible` bit is sufficient for the current Observation-029 vocabulary.

It is not future-context sufficient, because it collapses the two states above while an allowed continuation later distinguishes them.

This gives the old LOAM sufficiency question a dynamic form:

```text
retained summary may collapse states
only if no allowed future continuation + selected question can distinguish them
```

## External mathematical comparison

The result is deliberately described as **Nerode-style**.

Classical Myhill-Nerode theory characterizes language equivalence by indistinguishability under all future suffixes and obtains a right congruence. LOAM's field trial has arbitrary states, arbitrary deterministic operations, and multiple terminal questions instead of strings and one acceptance predicate.

Coalgebraic behavioural equivalence is a broader comparison for state-based systems and minimization, but Observation 192 does not introduce a coalgebra abstraction or claim that LOAM correction, authority, time, and publication already form one coalgebra.

## Boundary

No production Core, Application, Persistence, CLI, TUI, manifest/publication stack, household data, correction semantics, routing semantics, time semantics, recommendation policy, generic state-machine framework, coalgebra library, minimization algorithm, or quotient representation changes.

This observation does not claim a new mathematical theorem. It tests whether LOAM's independently developed vocabulary-relative sufficiency and observational quotient arcs meet a familiar dynamic-equivalence structure.
