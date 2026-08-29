# Observation 007 — Composed Summary Observers

## Question

Can a sufficient retained-state representation be constructed from primitive observers instead of selected from a list of finished summary candidates?

Observation 006 searched among completed candidates such as `u0`, `u1`, `count`, and `pair`. Observation 007 removes `pair` from the candidate vocabulary.

## Grammar

The bounded expression grammar contains only three primitive observers and one composition form:

```text
observe u0
observe u1
observe count
combine <observer> <observer>
```

For this observation, expressions contain either one primitive observer or one `combine` node containing two distinct primitive observers. Permutation duplicates are canonicalized away.

The history universe remains the four classes exposed in Observation 005:

```text
h00 = u0 false, u1 false
h10 = u0 true,  u1 false
h01 = u0 false, u1 true
h11 = u0 true,  u1 true
```

`count` observes how many of `u0` and `u1` are true, yielding `zero`, `one`, or `two`.

## Executed environment

GitHub Actions executed:

- Racket 9.3 (CS, full, x64)
- the Racket `minikanren` package resolving to `takikawa/minikanren` commit `51a18cf82834fb1af7a0dc41af4b7894099a3d05`

## Executed result

The relation returned:

```text
u0-only / one observer: ((observe u0))
u1-only / one observer: ((observe u1))
both / one observer: ()

both / two observers:
  ((combine (observe u0) (observe u1))
   (combine (observe u0) (observe count))
   (combine (observe u1) (observe count)))
```

So no single primitive observer preserves both independent future questions, while three distinct two-observer expressions do.

## Finding

A future operation vocabulary can determine an information requirement without determining a unique state representation.

The direct representation is:

```text
u0 + u1
```

but these are equally sufficient in this four-history universe:

```text
u0 + count
u1 + count
```

Why? If `u0` and the number of true continuity bits are known, `u1` is recoverable. Symmetrically, `u1 + count` recovers `u0`.

The important distinction is therefore not primarily between field names. It is between representations that preserve the same future-visible partition of histories.

This suggests a stronger reading of the previous observations:

> retained state may be better characterized by the distinctions it preserves than by one canonical set of stored fields.

## What changed from Observation 006

Observation 006 asked which finished summary candidate was sufficient.

Observation 007 instead constructs summary expressions from smaller observational parts. The result exposes alternative sufficient encodings that the completed-candidate list in Observation 006 did not name.

This is the first loam observation where relational composition discovers more than a yes/no choice among pre-named state shapes.

## Boundary

This remains bounded relational synthesis.

- the primitive observer vocabulary is supplied by hand;
- expression size is bounded to one or two primitive observers;
- the history universe has only four classes;
- `count` has its special meaning only because this experiment contains exactly two Boolean continuity observations.

The result does not establish a unique minimal representation, arbitrary program synthesis, or a universal household-state theorem.

## Next question

The three sufficient representations appear to carry the same future-visible information while using different coordinates.

Can that notion of **observationally equivalent state representations** be stated as a general law rather than another bounded search result?

That is the first point where Lean 4 may have a distinct job: prove a small law about when one summary can decode the observations required by a future vocabulary, while Alloy, J, TLA+, and miniKanren retain their existing exploratory roles.
