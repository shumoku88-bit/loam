# Observation 005 — Vocabulary-Induced State

## Question

Does a larger future operation vocabulary induce a correspondingly richer retained state?

Observation 004 fixed one history-sensitive question about `U0` and found that one targeted bit was sufficient for that vocabulary. Observation 005 adds a second independent question about `U1`.

The selected future vocabulary asks:

- has `U0` remained continuously at `Target` since observation began?
- has `U1` remained continuously at `Target` since observation began?

The question is not whether two bits are a generally good household representation. It is whether these two future distinctions create four observably different history classes even when the current placement is identical.

## Alloy lens

`model/005_vocabulary_induced_state.als` asks Alloy 6.2.0 / Sat4j for four histories, all with the same final complete placement, whose continuity signatures are:

```text
(U0Stayed, U1Stayed)
H00 = (0, 0)
H10 = (1, 0)
H01 = (0, 1)
H11 = (1, 1)
```

The command is SAT with exactly 3 Times, 2 Purposes, and 2 Units.

The concrete witness is:

```text
          Time 0   Time 1   Time 2
H00 U0    Other    Target   Target
H00 U1    Other    Other    Target

H10 U0    Target   Target   Target
H10 U1    Target   Other    Target

H01 U0    Target   Other    Target
H01 U1    Target   Target   Target

H11 U0    Target   Target   Target
H11 U1    Target   Target   Target
```

All four histories finish at the identical current placement:

```text
U0 -> Target
U1 -> Target
```

but the continuity sets are all four possibilities:

```text
H00 Stayed = {}
H10 Stayed = {U0}
H01 Stayed = {U1}
H11 Stayed = {U0, U1}
```

So the chosen future vocabulary sees four distinct history classes behind one identical current placement.

## TLA+ lens

`tla/VocabularyInducedState.tla` retains both:

- the full `Stayed` set as an oracle summary;
- two Boolean projections, `u0Stayed` and `u1Stayed`.

Initial placement ranges over every `Units -> Purposes` function. Each transition may choose any new complete placement. The full set and the two bits are then updated incrementally.

TLC checks:

1. both bits remain exact projections of the full `Stayed` set;
2. the actual `ENABLED` result for the `U0` continuity-sensitive operation is identical through the full set and through `u0Stayed`;
3. the same holds independently for `U1`.

TLC 2.19 completed the full reachable-state search with:

```text
11 states generated
7 distinct states found
0 states left on queue
depth 2
no error
```

## Finding

For this fixed two-question vocabulary, there are four future-visible equivalence classes behind one identical current placement.

Therefore a representation that preserves both Boolean distinctions must itself be able to distinguish at least four cases. Two Boolean summary bits provide exactly four codes and are sufficient in the explored TLA+ transition system.

This is deliberately narrower than a universal state-minimization theorem. The important observation is not "two questions always require two bits." It is:

> Retained state is shaped by the distinctions the future vocabulary is allowed to observe.

The full history contains much more information than the selected future vocabulary can see. A sufficient state representation may therefore be understood as a quotient of history by future-observable equivalence.

## What changed from Observation 004

Observation 004 showed that compression quality depends on alignment with the future question, not merely on summary size.

Observation 005 adds a second independent question and observes that the number of future-visible classes expands from two to four.

The emerging sequence is:

```text
history
  -> future operation vocabulary
  -> observable equivalence classes
  -> sufficient retained state
```

rather than:

```text
history
  -> invent a convenient cache
  -> hope it is enough
```

## Next question

Can the sufficient summary be derived from the operation vocabulary instead of proposed by hand?

That question may justify introducing miniKanren: treat a candidate summary relation as an unknown and search for a representation that preserves all distinctions made by a small operation vocabulary. Alloy can continue generating structural counterexamples, while TLA+ can test candidate summaries through reachable behaviors.

Lean 4 is still premature because no general theorem has yet been isolated beyond the finite experimental setting.
