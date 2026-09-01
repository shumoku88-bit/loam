# Observation 082 — Does a sanitized realization summary preserve realization provenance?

## Question

Observation 063 established that Plan/Event content does not determine which Actual Event realizes which Plan. The realization relation carries independent information.

PR #156 then added a private canonical-data observer that deliberately exposes only sanitized structural counts. For each explicitly linked Plan/Actual pair, it classifies the pair into a 3 × 3 matrix:

```text
                exact   quantity-different   shape-different
before
same-day
after
```

The current private canonical snapshot produced this sanitized matrix for 20 explicitly linked pairs:

```text
                exact   quantity-different   shape-different
before             4            0                  0
same-day           9            2                  0
after              4            1                  0
```

No private identities, dates, quantities, descriptions, loci, measures, or source metadata are copied into this observation.

The new question is not whether the summary is useful. It clearly preserves structural pressure while protecting private source detail.

The narrower question is:

> If two worlds expose the same sanitized time × physical-delta summary, must they contain the same Plan → Actual realization provenance?

## Why this is distinct from Observation 063

Observation 063 varied the explicit realization relation while keeping Plan/Event records fixed, showing that record content does not recover provenance.

Observation 082 starts one step later:

```text
explicit realization relation
        ↓ classify linked pairs
privacy-safe aggregate summary
```

It asks whether this deliberately lossy projection can later be mistaken for the semantic relation from which it was derived.

## Experiment

The Alloy model abstracts only the post-classification boundary.

It retains:

- three Plan identities;
- three Event identities;
- one candidate for every Plan/Event pair;
- one of the nine sanitized summary buckets for each candidate;
- two worlds whose realization relations are partial matchings.

The model does not duplicate the private parser, household values, dates, quantities, account-like coordinates, or the mechanics by which PR #156 computes each bucket. Those details are upstream of the information-loss question.

For each world, the sanitized summary is only the count of realized candidates in each of the nine buckets.

### Expected witness

There should be a witness where:

```text
same nine bucket counts
same number of realized links
at least two occupied buckets

but

different Plan -> Actual realization links
```

### Expected counterexample

The assertion

```text
same sanitized summary
    ->
same realization relation
```

should have a counterexample.

### Controls

Two narrow controls should hold in the bounded model:

```text
same explicit realization relation
    -> same sanitized summary

same sanitized summary
    -> same realized-link count
```

The second control matters because the intended loss is provenance, not simple cardinality corruption.

## Expected boundary

If the model behaves as expected, Observation 082 earns only this distinction:

```text
privacy-safe structural summary
        !=
realization provenance
```

A sanitized aggregate can preserve enough information to reveal real-data pressure without preserving enough information to reconstruct which Plan was realized by which Actual Event.

That is desirable for the private dogfood tool, but it also means a later human/AI workflow must not silently promote such a summary into canonical semantic state.

## Non-goals

This observation does not earn:

- a generic privacy framework;
- a generic provenance type;
- a Plan store in Practical Core;
- realization persistence in LOAM;
- a universal 3 × 3 realization taxonomy;
- a claim that realization is permanently one-to-one;
- a semantic-OS primitive;
- a rule that aggregate summaries are unsafe or unhelpful.

It tests only whether the sanitized projection introduced by the current private Plan-realization observer preserves the underlying relation.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private canonical data committed;
- no source mutation.
