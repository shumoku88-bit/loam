# Observation 190 — sparse human annotation boundary

## Pressure

Observation 188 separated spending description from decision framing. Observation 189 then separated choice, commitment, and funding posture.

A new practical pressure appears immediately: human household language is not cleanly total or exclusive.

- one bundled outlay can contain a needed component and a wanted component;
- one component can be both wanted and experienced as needed;
- an intent such as `learning` may explain why a book is interesting without becoming financial authority;
- useful human language should not automatically become another LOAM Core fact family.

The question is therefore not which Japanese word is universally correct. The question is whether a proposed structural encoding forces distinctions that practical examples do not support.

## Alloy model

`model/190_sparse_human_annotation_boundary.als` deliberately keeps two layers apart.

Financial skeleton:

```text
Outlay -> ScheduleState
Outlay -> FundingState
```

Human annotation:

```text
Part -> optional Description
Part -> optional Intent
Part -> set ChoiceTag
```

`Need` and `Want` are tags rather than an exclusive enum in this observation. The annotation layer is sparse and non-authoritative.

## Expected qualification

The model asks for these witnesses:

```text
mixedBundlePressure                         SAT
samePartNeedAndWantPressure                 SAT
mixedBundleWithSingleOutlayChoice           UNSAT
samePartNeedAndWantWithExclusiveChoice      UNSAT
sameFinanceDifferentHumanMeaning            SAT
sameCurrentMeaningDifferentIntent           SAT
HumanAnnotationsCannotChangeFinancialProjection  UNSAT counterexample
```

Interpretation:

1. A single outlay-level `need | want` choice cannot preserve a mixed-component bundle.
2. A single exclusive choice per component cannot preserve a component that is both wanted and needed.
3. The same financial skeleton can support different descriptions, choices, or intents.
4. Intent can differ while current financial meaning remains unchanged.
5. Human annotations therefore do not need to become canonical financial authority merely because they are useful to a person.

## What this prunes

This observation does **not** earn new Core primitives for:

- Need;
- Want;
- Intent;
- Desire;
- Reliance;
- Learning;
- Book;
- a universal envelope taxonomy.

It also rejects, for now, a production design that requires every outlay to receive exactly one `need / want` role.

The smallest earned direction is weaker:

```text
keep financial evidence authoritative
+
allow sparse, compositional human interpretation above it when useful
```

A later concrete query or operation must demonstrate that a human annotation changes an answer LOAM is responsible for before that annotation can press toward Core authority.

## Boundary

No production code, canonical persistence, Capacity Purpose, routing, household data, recommendation policy, moral ordering, or UI vocabulary changes. This is a pruning observation only.
