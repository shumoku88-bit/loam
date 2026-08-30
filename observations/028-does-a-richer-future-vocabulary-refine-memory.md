# Observation 028 — Does a Richer Future Vocabulary Refine Memory?

## Question

Observation 027 found that full Origin identity can be compressed to acceptance-visible provenance for the current bounded acceptance vocabulary.

That immediately raises a temporal-looking but still static question:

> when the set of future questions becomes richer, how does the induced memory boundary change?

In particular, does adding a question ever merge distinctions that an older vocabulary could already observe, or can it only preserve or refine the existing quotient?

This observation does not yet model vocabulary changing through time. It compares a nested family of finite vocabularies over the same finite provenance universe.

## Fixed provenance universe

Three neutral provenance marks are used:

```text
A
B
Hidden
```

Every possible combination is admitted, giving eight Origin states:

```text
A B Hidden
0 0 0
0 0 1
0 1 0
0 1 1
1 0 0
1 0 1
1 1 0
1 1 1
```

No mark is called evidence, authority, trust, justification, or support. They are only distinctions that a future question may or may not observe.

## Candidate future questions

Five Boolean questions are defined over the marks:

```text
Either(A,B)
A
B
Both(A,B)
Hidden
```

Two Origins are observationally equivalent for a vocabulary when they return the same answer vector for every question in that vocabulary.

The vocabularies are nested:

```text
V0 = {}
V1 = { Either(A,B) }
V2 = { Either(A,B), A }
V3 = { Either(A,B), A, B }
V4 = { Either(A,B), A, B, Both(A,B) }
V5 = { Either(A,B), A, B, Both(A,B), Hidden }
```

`Both(A,B)` is deliberately included after `A` and `B`. It is a new syntactic question but carries no new observational distinction because its answer is derivable from answers already available.

`Hidden` is deliberately different. It separates pairs that every earlier vocabulary merges.

## Why J first

Observation 027 already established the provenance-compression boundary relationally in Alloy.

The present question is about the complete quotient geometry of a small finite table:

```text
Origin × future-question -> answer
```

J can enumerate all eight Origins, project the answer table through each vocabulary, group equal response rows, and expose every equivalence class at once.

Alloy would add little here unless a new relational witness question appears. TLA+ remains unnecessary because vocabulary evolution through transitions is not yet modeled. Lean is intentionally deferred until the finite observation shows a law worth preserving rather than merely a convenient definition.

## Executed J boundary

The Observation 028 check expects the nested vocabularies to induce these class counts:

```text
V0  1
V1  2
V2  3
V3  4
V4  4
V5  8
```

The expected sorted class sizes are:

```text
V0: 8
V1: 2 6
V2: 2 2 4
V3: 2 2 2 2
V4: 2 2 2 2
V5: 1 1 1 1 1 1 1 1
```

The important shape is not merely increasing class count.

### A richer vocabulary can strictly refine memory

`V0 -> V1 -> V2 -> V3` repeatedly separates Origins that were previously observationally equivalent.

When `Hidden` is finally added, every remaining pair splits:

```text
V4: four classes of size 2
V5: eight classes of size 1
```

A distinction that was safe to forget under `V4` is no longer safe to forget under `V5`.

### A richer vocabulary need not require richer memory

`V3 -> V4` adds the question `Both(A,B)`, but the quotient remains exactly four classes of size two.

That happens because:

```text
Both(A,B) = A and B
```

The new question is recoverable from answers the older vocabulary already retained.

So vocabulary size and required memory size are not the same thing.

## Finding

For this finite nested family, adding future questions never makes the observational quotient coarser.

It does one of two things:

1. leaves the quotient unchanged when the new question is recoverable from existing answers;
2. splits one or more existing classes when the new question exposes a previously hidden distinction.

A concise reading is:

> Richer future vocabulary can demand finer memory, but only genuinely new observable distinctions force the refinement.

This sharpens Observation 027. The earlier compression was not a permanent declaration that `Hidden` provenance is irrelevant. It was a statement relative to a particular future vocabulary.

## Relation to Observation 016

Observation 016 compared three hand-chosen operation vocabularies and observed 5, 9, and 16 commitment classes.

Observation 028 isolates the refinement shape itself and adds an important negative case: a vocabulary can become syntactically richer while the quotient remains unchanged because the added question is observationally redundant.

That makes the relevant quantity not the number of operations or questions, but the number of distinctions they collectively induce.

## Boundary of the claim

This is still a bounded observation:

- eight provenance states;
- five Boolean questions;
- one nested family of vocabularies;
- static comparison only;
- no claim yet about changing vocabularies during system execution;
- no global minimal representation theorem.

The observation therefore does not yet prove the general statement that for arbitrary vocabularies `V ⊆ W`, observational equivalence under `W` always refines observational equivalence under `V`.

That statement now looks plausible enough to inspect as a possible general law, but it should only move to Lean if the formulation says something useful about sufficiency and recoverability rather than merely restating set inclusion.

## Next pressure point

Ask whether the refinement shape deserves preservation as a general theorem.

A useful theorem would not merely say that more predicates produce at least as many equivalence classes. It would connect vocabulary inclusion to memory sufficiency:

> if a retained summary is sufficient for a richer future vocabulary, is it necessarily sufficient for every poorer sub-vocabulary?

And conversely, can a summary sufficient for a poorer vocabulary fail exactly when a richer vocabulary introduces a distinction that does not factor through that summary?

If that formulation remains clean and non-tautological, Lean becomes justified. Otherwise the J observation should stand on its own.
