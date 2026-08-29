# Observation 027: How Much Provenance Must Be Remembered?

## Question

Observation 026 showed that offered semantic content can be sufficient for recovering Resolution meaning while still being insufficient for an acceptance vocabulary that observes provenance.

That left a more precise question:

> If provenance can matter, must full Origin identity be remembered, or only the distinctions that future acceptance criteria can observe?

This observation applies the earlier vocabulary-induced-state idea to provenance.

It deliberately does not introduce Evidence, Authority, trust, support, endorsement, or justification.

## Tool choice

Alloy only.

No J is needed yet because this observation does not compare the size or shape of a large quotient space. It asks whether three candidate summaries are distinguishable in a small relational world.

No TLA+ is needed because provenance and criteria do not evolve through time here.

No miniKanren is needed because the observation is not yet synthesizing summaries backwards from desired behavior.

No Lean theorem is introduced because the experiment is still locating the precise bounded relation that might later deserve generalization.

## Model

The Resolution shape from Observations 023-026 is kept fixed:

```text
       KA
      /  \
    C0    R0
      \  /
       KB
```

Both worlds still agree on all semantic content:

```text
C0 -> M0
KA -> MA
KB -> MB
offered -> MX
R0 -> MX
```

Only provenance varies.

Instead of defining two Origin classes and then declaring one acceptable, each Origin carries neutral marks:

```text
O0 -> {MarkA, Hidden0}
O1 -> {MarkA, Hidden1}
O2 -> {MarkB, Hidden0}
```

The future acceptance vocabulary contains two criteria:

```text
CriterionA observes MarkA
CriterionB observes MarkB
```

`Hidden0` and `Hidden1` are deliberately outside that vocabulary.

Acceptance is therefore:

```text
accepted(world, criterion)
    iff Resolution meaning is MX
    and the criterion's required mark is present
```

The semantic content and the criterion are held fixed when two worlds are compared. Only provenance differs.

## Three candidate memories

### 1. Full Origin identity

The first candidate keeps:

```text
Origin = O0 | O1 | O2
```

This preserves every distinction, including distinctions invisible to the current acceptance vocabulary.

### 2. Acceptance-relevant provenance

The second candidate does not store a hand-written Origin class.

It projects each Origin to the marks that the current criterion vocabulary can observe:

```text
relevantProvenance(origin)
    = origin.marks & observableMarks
```

So:

```text
O0 -> {MarkA}
O1 -> {MarkA}
O2 -> {MarkB}
```

`O0` and `O1` remain different Origins, but this future vocabulary cannot distinguish them.

The resulting equivalence is induced by what the vocabulary observes rather than introduced as a primitive classification.

### 3. Coarse count-only summary

The third candidate keeps only:

```text
# relevantProvenance(origin)
```

This intentionally forgets which observable mark is present.

Therefore both:

```text
{MarkA}
{MarkB}
```

compress to the same count:

```text
1
```

This creates the required collision rather than assuming that a coarse summary fails.

## Expected Alloy boundary

The model asks for two kinds of witnesses and checks three sufficiency claims.

```text
distinctOriginSameRelevantSameAcceptance                SAT
sameFullOriginDifferentAcceptance                       UNSAT
sameRelevantDifferentAcceptance                         UNSAT
sameCoarseDifferentRelevantDifferentAcceptance          SAT
FullOriginDeterminesAcceptance                          UNSAT
RelevantProvenanceDeterminesAcceptance                  UNSAT
CoarseSummaryDeterminesAcceptance                       SAT
OriginDoesNotChangeResolutionMeaning                    UNSAT
WholeFrontierResolutionStillSettles                     UNSAT
```

For checked assertions, `SAT` means Alloy found a counterexample.

## What the witnesses mean

### Full identity is sufficient but may remember unused detail

`distinctOriginSameRelevantSameAcceptance` should be SAT.

A witness can choose `O0` and `O1`:

```text
full identity:
O0 != O1

full marks:
O0 = {MarkA, Hidden0}
O1 = {MarkA, Hidden1}

acceptance-relevant projection:
O0 = {MarkA}
O1 = {MarkA}
```

Both criteria then give the same acceptance result in both worlds.

So full Origin identity can contain distinctions that this bounded future vocabulary does not use.

### Acceptance-relevant provenance is sufficient in this vocabulary

`sameRelevantDifferentAcceptance` should be UNSAT, and `RelevantProvenanceDeterminesAcceptance` should have no counterexample.

Within the modeled vocabulary:

```text
same observable provenance marks
              |
              v
same acceptance for every modeled criterion
```

The summary does not need to know whether the hidden mark was `Hidden0` or `Hidden1`.

### A still coarser summary loses a future distinction

`sameCoarseDifferentRelevantDifferentAcceptance` should be SAT, and `CoarseSummaryDeterminesAcceptance` should have a counterexample.

A witness can compare:

```text
O0 -> {MarkA}
O2 -> {MarkB}
```

Both have count `1`, but under the same fixed `CriterionA`:

```text
O0 accepted
O2 rejected
```

or under `CriterionB` the result reverses.

Therefore quantity of provenance information is not enough. Which acceptance-visible distinction survives the projection matters.

## Finding

For this bounded acceptance vocabulary, full Origin identity is sufficient but not necessary.

A smaller provenance projection is also sufficient when it preserves exactly the marks that the future criteria can observe.

A coarser projection that merges different observable marks is insufficient.

The shape is:

```text
full Origin identity
        |
        | forget distinctions invisible to the vocabulary
        v
acceptance-relevant provenance
        |
        | forget an observable distinction
        v
coarse summary
```

and the observed boundary is:

```text
full identity                    sufficient
acceptance-relevant projection   sufficient
count-only projection            insufficient
```

## Relation to Observations 004-008

The earlier observations found that sufficient state is relative to a future vocabulary.

Observation 027 applies the same idea to provenance:

> provenance need not be retained at the resolution of its original representation; it must retain the distinctions that the future provenance-sensitive vocabulary can still ask about.

This is a quotient-shaped result.

The relevant equivalence is not metaphysical identity. It is observational equivalence under the current bounded acceptance vocabulary.

## What this does not establish

This observation does not establish a globally minimal provenance representation.

It does not establish that the modeled marks are evidence, authority, trust, support, or justification.

It does not establish that real systems should expose `MarkA` or `MarkB` as stored fields.

It does not establish that future vocabularies will remain limited to the two modeled criteria.

A new future criterion could make `Hidden0` and `Hidden1` observable, in which case the currently sufficient projection would no longer be sufficient.

The result is therefore explicitly limited to the current finite Alloy model and its acceptance vocabulary.

## Boundary exposed

Observation 026 established:

```text
offered meaning + provenance-sensitive criterion
                    |
                    v
               acceptance
```

Observation 027 refines the provenance side:

```text
full provenance
      |
      v
future-observable provenance equivalence
      |
      v
acceptance
```

The next question, if earned, is whether this quotient-shaped observation is only a property of this hand-sized model, or whether a general preservation law can be stated cleanly enough to deserve Lean.
