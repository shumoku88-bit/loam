# Observation 026: Is Offered Meaning Enough?

## Question

Observation 024 showed that a settled correction frontier does not by itself determine the meaning of a Resolution.

Observation 025 then separated two cases:

- a rule may select meaning already present in a parent;
- fresh Resolution meaning requires fresh semantic input somewhere.

The fresh input was deliberately called `offered`, without treating it as evidence, authority, support, or justification.

This observation asks a narrower next question:

> Once fresh Resolution meaning is recoverable from an offered meaning, does that offered meaning also determine whether it may be accepted?

The important distinction is between recovering semantic content and evaluating that content under a vocabulary that may observe provenance.

## Tool choice

Alloy only.

No J is needed because this observation compares no quantitative projections.

No TLA+ is needed because the question concerns bounded relational distinguishability rather than temporal behavior.

No miniKanren is needed because no inverse search or synthesis of candidate summaries is being performed.

No Lean theorem is introduced yet because the experiment is still locating the boundary that might later deserve a general statement.

## Model

The model keeps the same small correction shape:

```text
       KA
      /  \
    C0    R0
      \  /
       KB
```

`R0` is the sole terminal interpretation.

Both worlds have the same prior meanings and the same fresh offered meaning:

```text
C0 -> M0
KA -> MA
KB -> MB
offered -> MX
R0 -> MX
```

The offered meaning is fresh relative to the two parents.

The only additional coordinate is a neutral `Origin`:

```text
Origin = O0 | O1
```

Two acceptance vocabularies are then compared.

### Content-only acceptance

```text
acceptedByContent(w)
    iff offered(w) = requiredMeaning
```

This vocabulary observes semantic content only.

### Origin-sensitive acceptance

```text
acceptedByOrigin(w)
    iff acceptedByContent(w)
    and origin(w) = requiredOrigin
```

This vocabulary observes both semantic content and origin.

`requiredOrigin` is only a modeled criterion. The experiment does not explain why one origin should be preferred, nor does it name that preference authority, trust, evidence, support, or justification.

## Executed result

Alloy 6.2.0 with Sat4j, exact scope:

- 4 Interpretations
- 4 Meanings
- 2 Origins
- 2 Worlds

```text
sameOfferedDifferentOriginDifferentAcceptance           SAT
sameOfferedSameOriginDifferentAcceptance                UNSAT
sameResolutionDifferentAcceptance                       SAT
sameOfferedDifferentOriginSameContentAcceptance         SAT
OfferedMeaningDeterminesContentAcceptance               UNSAT
OfferedMeaningDeterminesOriginAcceptance                 SAT
OfferedMeaningAndOriginDetermineOriginAcceptance        UNSAT
OriginDoesNotChangeResolutionMeaning                     UNSAT
WholeFrontierResolutionStillSettles                      UNSAT
```

For checked assertions, `SAT` means Alloy found a counterexample.

## Reading the witnesses

### Same offered meaning, different origin, different origin-sensitive acceptance

`sameOfferedDifferentOriginDifferentAcceptance` is SAT.

The two worlds may therefore agree on the exact semantic content being offered while differing only in origin, and the origin-sensitive vocabulary can accept one and reject the other.

So this implication fails:

```text
same offered meaning
        |
        X
        v
same origin-sensitive acceptance
```

This is also reflected by the counterexample to `OfferedMeaningDeterminesOriginAcceptance`.

### Same offered meaning and same origin do determine origin-sensitive acceptance

`sameOfferedSameOriginDifferentAcceptance` is UNSAT, and `OfferedMeaningAndOriginDetermineOriginAcceptance` is UNSAT.

Within this bounded vocabulary:

```text
(offered meaning, origin)
          |
          v
origin-sensitive acceptance
```

is recoverable.

### Content-only acceptance does not need origin

`sameOfferedDifferentOriginSameContentAcceptance` is SAT, while `OfferedMeaningDeterminesContentAcceptance` is UNSAT.

The same semantic content can arrive from different origins without changing content-only acceptance.

Therefore provenance is not intrinsically required merely because an offered meaning exists. It becomes required when the future observation vocabulary asks a provenance-sensitive question.

### Resolution meaning remains unchanged

`sameResolutionDifferentAcceptance` is SAT, while `OriginDoesNotChangeResolutionMeaning` is UNSAT.

The model therefore permits this shape:

```text
World Left                         World Right

origin O0                          origin O1
    |                                  |
offered MX                         offered MX
    |                                  |
Resolution meaning MX             Resolution meaning MX
    |                                  |
 accepted                            rejected
```

The semantic result is the same. What differs is an acceptance judgment under an origin-sensitive criterion.

## Finding

> Offered meaning is enough to recover what fresh meaning a Resolution carries, but it is not enough to recover every future judgment about that meaning once the vocabulary is allowed to observe provenance.

More compactly:

```text
semantic content answers: what is offered?
provenance may answer:     is this offer admissible under this criterion?
```

This sharpens Observation 025's separation:

```text
recoverable meaning
        !=
recoverable acceptance
```

It also reconnects to the earlier vocabulary-induced-state observations. Information becomes necessary not because it is metaphysically part of the object, but because a future vocabulary is allowed to distinguish worlds by it.

## What this does not establish

This observation does **not** establish that real acceptance always depends on provenance.

It does **not** establish that `Origin` is Evidence, Authority, trust, endorsement, support, or justification.

It does **not** establish why `O0` rather than `O1` should satisfy the criterion.

It does **not** establish that full origin identity is the minimal information needed for every provenance-sensitive vocabulary.

The result is bounded to the chosen acceptance predicates and finite Alloy scope.

## Boundary exposed

Observation 025 located fresh semantic input:

```text
(parent meanings, rule, offered meaning)
                |
                v
        Resolution meaning
```

Observation 026 adds a second, independent projection when the vocabulary observes provenance:

```text
offered meaning -----------------> Resolution meaning
      |
      +---- + origin ------------> acceptance
```

The next question, if earned, is no longer whether provenance can matter. It is how much provenance must be retained for the distinctions that the acceptance vocabulary actually observes.
