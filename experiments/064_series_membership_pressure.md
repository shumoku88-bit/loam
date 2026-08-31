# Observation 064 — Does recurring Plan structure determine Series membership?

## Question

Observation 063 found that Plan and Actual Event endpoint records do not determine which Event realizes which Plan. It left one-to-one realization in place because the current household source does not yet provide concrete pressure for split or merged realization.

A different recurring structure is already present in the source data: multiple Plans carry explicit Series membership, alongside recurrence kinds such as `monthly`, `cycle`, and `once`.

The public observation copies **none** of the private Series names, Plan identities, dates, quantities, descriptions, or account identities. It keeps only anonymized structural pressure observed in the source:

- one recurring Series can contain Plans whose expected quantity changes across instances;
- multiple distinct recurring Series can share the same recurrence kind and broad Plan shape;
- future questions may ask which Plans belong to the same recurring thread.

The question is:

> Can Series membership be reconstructed from Plan content such as recurrence, time, amount, and broad shape, or does the grouping itself carry independent information?

## Why not many-to-many realization yet?

Observation 063 explicitly left split / merged realization as future pressure.

The current canonical household records were checked before starting this observation. The visible Plan-linked Actual records still use one Plan identity per Actual record, and no concrete case was found where one Plan is realized by several Actuals or one Actual explicitly realizes several Plans.

LOAM therefore should not promote many-to-many realization merely because it is imaginable.

## Why Alloy

This question is structural:

- keep the same Plan atoms and Plan fields;
- vary only Series grouping;
- observe whether same-series peer answers change;
- ask whether recurrence and broad shape are sufficient to identify a recurring thread.

No transition order or concurrent protocol is involved, so Alloy is sufficient.

## Anonymous vocabulary

```text
Plan identity
  + expected Time
  + expected Amount
  + expected Shape
  + Recurrence kind

Series

seriesOf : Plan -> one Series
```

The model uses three recurrence atoms:

```text
Once
Monthly
Cycle
```

Every Plan belongs to exactly one Series in this bounded experiment because the source Plans under pressure carry explicit Series membership. This is not a general claim that every future Plan must belong to a Series.

## Representative pressure

The model asks for three Plans with monthly recurrence and the same broad Shape.

Two belong to the same Series but differ in expected time and amount.

A third belongs to a different Series despite sharing the same recurrence kind and broad Shape.

This captures two source-shaped facts without copying private values:

```text
same recurring thread
  does not require fixed amount

same recurrence + broad shape
  does not identify one recurring thread
```

## Probes

### 1. Can the representative source-shaped pressure coexist?

Expected: **SAT**.

### 2. Can the same Plan records yield different Series peer answers when only grouping changes?

Expected: **SAT**.

This asks whether Plan fields alone determine grouping.

### 3. Can one Series contain different expected amounts?

Expected: **SAT**.

A recurring thread therefore need not be a fixed-amount template.

### 4. Can two Plans share recurrence kind and broad Shape while belonging to different Series?

Expected: **SAT**.

Recurrence classification is therefore coarser than Series identity.

### 5. Do Plan records determine Series grouping across worlds?

Expected check result: **SAT counterexample**.

### 6. Does same recurrence + broad Shape force same Series?

Expected check result: **SAT counterexample**.

### 7. Does membership in one Series require a fixed amount?

Expected check result: **SAT counterexample**.

### 8. Once the explicit Series relation is fixed, are same-series peer answers fixed?

Expected check result: **UNSAT counterexample**.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
representativeSeriesPressure                         SAT
sameRecordsDifferentGrouping                         SAT
changingAmountWithinSeries                           SAT
sameRecurrenceAndShapeDifferentSeries                SAT
PlanRecordsDetermineSeriesGrouping                   SAT counterexample
SameRecurrenceAndShapeMeansSameSeries                SAT counterexample
SeriesMembershipRequiresFixedAmount                  SAT counterexample
ExplicitSeriesRelationDeterminesPeerAnswers          UNSAT counterexample
```

The executable workflow completed successfully on the observation branch. The result matches every expected witness and check.

## Finding

Within the bounded vocabulary:

```text
Plan content
    !=
recurrence kind
    !=
Series membership
```

The same recurring thread can continue across changed expected quantities, while two distinct recurring threads can share recurrence kind and broad structural Shape.

Keeping all Plan records fixed while changing only Series membership can change same-series peer answers. Therefore Plan content does not determine the grouping.

The independently observable information is the grouping relation: which Plan identities belong to the same recurring thread.

This does **not** mean a first-class stored `Series` object has been earned. A `series-id` field, a standalone membership relation, or another information-equivalent representation could all preserve the observed distinction.

## Important boundaries

Observation 064 does **not** establish:

- that `Series` belongs in the Practical Lean Core;
- that every Plan belongs to exactly one Series generally;
- recurrence generation rules;
- schedule prediction;
- next-occurrence generation;
- recurrence lifecycle or cancellation;
- whether Series itself needs stable identity beyond preserving membership distinctions;
- whether a Series can branch or merge;
- many-to-many Plan realization;
- whether recurrence kind belongs to the neutral core;
- persistence layout.

## Next pressure

If Series membership is independently observable, the next useful question should come from what people actually ask of a recurring thread.

Candidates include:

- whether future occurrence generation requires a Series-level rule rather than mere membership;
- whether changes to recurring amount or schedule are revisions of one Series or creation of a new one;
- whether expected time, actual time, and learned time need separate coordinates once recurrence is involved.

Those questions should be separated rather than smuggled into Series identity prematurely.
