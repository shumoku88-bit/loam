# Observation 029 — Does Sufficiency Descend With Vocabulary?

## Question

Observation 028 showed a finite quotient pattern:

```text
1 2 3 4 4 8
```

A richer future vocabulary sometimes refined memory and sometimes did not. The important `4 -> 4` step came from adding a question whose answer was already recoverable from existing answers.

This observation asks for the general shape behind that example:

> If one future vocabulary is contained in another, what must happen to observational equivalence and summary sufficiency?

## Tool choice

Lean only.

Observation 028 already enumerated the complete finite quotient table in J. The remaining question is no longer about finding another bounded witness. It is whether two inclusion laws hold for arbitrary types of histories, questions, answers, and summaries.

Alloy would restate a bounded instance. TLA+ is unnecessary because no temporal transition system is involved. miniKanren is unnecessary because no backward synthesis problem is being asked.

## Definitions

For a question type `Question`, a vocabulary is a predicate:

```text
Vocabulary Question = Question -> Prop
```

For an answer function

```text
answer : History -> Question -> Answer
```

two histories are observationally equivalent under a vocabulary when every question admitted by that vocabulary receives the same answer.

A retained summary

```text
encode : History -> Summary
```

is sufficient for a vocabulary when a single decoder can recover the answer to every admitted question from the encoded summary.

## General laws

Lean proves:

### 1. Richer equivalence refines poorer equivalence

If `small` is included in `large`, then

```text
Equivalent answer large h1 h2
```

implies

```text
Equivalent answer small h1 h2
```

So extending future vocabulary may keep an observational partition unchanged or split classes, but it cannot merge classes that the smaller vocabulary already distinguished.

### 2. Sufficiency descends along vocabulary inclusion

If a summary is sufficient for `large`, and `small` is included in `large`, the same summary and decoder are sufficient for `small`.

Forgetting future questions cannot require additional retained memory.

### 3. Equal sufficient summaries are invisible to the vocabulary

If two histories have the same encoding under a summary sufficient for a vocabulary, then every question in that vocabulary receives the same answer on those histories.

This gives a direct bridge between summary collision classes and observational equivalence.

## Observation 028 boundary cases in Lean

The concrete vocabulary is reconstructed over three neutral provenance marks:

```text
A
B
Hidden
```

with questions:

```text
Either(A,B)
A
B
Both(A,B)
Hidden
```

### Redundant extension

`V3` sees `Either`, `A`, and `B`.

`V4` additionally sees `Both(A,B)`.

Lean proves that `V3` and `V4` induce exactly the same observational equivalence relation. `Both(A,B)` is recoverable from already-visible `A` and `B`, so the richer syntax adds no new distinction.

### Genuine extension

`V5` additionally sees `Hidden`.

Lean exhibits two origins that agree under every `V4` question but disagree under `V5` solely because their Hidden marks differ.

Thus inclusion permits strict refinement but does not require it.

## Summary boundary

The concrete summary

```text
(A, B)
```

is sufficient for `V4`, including the derived `Both(A,B)` question.

Lean also proves that the same summary is not sufficient for `V5`: two origins with identical `(A,B)` summaries but different Hidden marks would otherwise have to be observationally equivalent under `V5`, contradicting the Hidden answer.

## Finding

The pattern from Observation 028 survives generalization:

> Future-vocabulary inclusion is monotone with respect to observational distinction.
>
> Richer vocabularies can preserve or refine a memory quotient, never coarsen it. A summary sufficient for a richer vocabulary remains sufficient for every sub-vocabulary.

The concrete boundary is equally important:

> Syntactically new questions do not force new memory when their answers factor through what is already retained. New memory becomes necessary only when the future vocabulary exposes a distinction that the current summary collapses.

This is stronger than counting vocabulary entries. What matters is the observational distinction induced by the questions.

## Limits

This does not say that one globally minimal summary exists.

Sufficiency remains relative to a chosen future vocabulary. If that vocabulary later exposes a distinction previously forgotten, a formerly sufficient summary may cease to be sufficient.

The result also does not prescribe which questions a household system should permit. It only constrains how changing that question set changes the information boundary.
