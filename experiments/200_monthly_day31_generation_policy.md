# Observation 200 — Does a monthly day-31 Series determine its shorter-month generation rule?

Status: **F055 completed — COUNTEREXAMPLE / RESEARCH_ONLY**

## Question

F055 asks what happens when a recurring monthly expectation names day 31 but the current month has no day 31.

Observation 064 already qualified an earlier distinction:

```text
Plan content
    !=
recurrence kind
    !=
Series membership
```

and explicitly left recurrence generation rules, schedule prediction, and next-occurrence generation outside its result.

Observation 200 therefore does not revisit Series identity. It holds Series membership fixed and asks the next information question:

> If Series membership, recurrence kind, nominal day, and neighboring observed day-31 occurrences are all fixed, is the shorter-month occurrence determined?

## Candidate compression under attack

A too-small candidate says:

```text
Series membership
+ Monthly recurrence
+ nominal day 31
+ observed 31st in neighboring long months
    ->
short-month generated occurrence
```

F055 asks whether two legitimate generation policies can disagree at the boundary while all of that retained evidence remains identical.

## Why Alloy

The selected question is structural information independence, not calendar implementation.

A full Gregorian calendar would only add machinery. The bounded model uses three abstract windows:

```text
JanLike   day 31 exists
Short     day 31 does not exist
MarLike   day 31 exists
```

Both worlds observe day 31 in the two neighboring long-month windows.

Only the shorter-month policy differs.

## Observation-local policies

The model uses two deliberately small policy atoms:

```text
SkipMissing
  no generated occurrence in Short

ClampLast
  generate on the final valid day of Short
```

These are enough to test independence. They are not claimed exhaustive. Carry-forward, business-day adjustment, holiday rules, provider-specific semantics, and other policies remain outside this observation.

## Executed Alloy result

Alloy 6.2.0 + Sat4j returned exactly the selected matrix:

```text
representativeClampAtShortMonth                       SAT
sameSeriesAndObservedPatternDifferentBoundary         SAT
ExistingSeriesEvidenceDeterminesShortMonthGeneration  SAT counterexample
NeighboringOccurrencesDetermineGenerationPolicy      SAT counterexample
ExplicitGenerationPolicyDeterminesBoundary            UNSAT counterexample
```

Dedicated Observation 200 CI completed SUCCESS on the exact observation head.

## Central witness

Left and Right agree on all retained recurring-thread evidence selected for the test:

```text
same Series membership
same Monthly recurrence
same nominal day 31
same observed day 31 in JanLike
same observed day 31 in MarLike
```

but differ at the missing-day boundary:

```text
Left
  policy = SkipMissing
  generatedShort = none

Right
  policy = ClampLast
  generatedShort = LastDay
```

Therefore the same recurring thread and the same observed regularity can support different shorter-month generated results.

## Finding

The bounded separation is:

```text
Series membership + recurrence shape
    !=
generation policy
```

and more specifically:

```text
same recurring thread + same observed regularity
    -/->
shorter-month generated occurrence
```

Even neighboring successful day-31 occurrences do not reconstruct the missing-day policy.

Once explicit generation policy is fixed, the selected shorter-month answer is fixed in the bounded model. So the observation earns an independently observable policy distinction, or an information-equivalent representation, for this query.

F055 therefore closes as:

```text
Work     DONE
Finding  COUNTEREXAMPLE
Runtime  RESEARCH_ONLY
```

This does **not** automatically earn a production `GenerationPolicy` enum or automatic schedule generator.

## Boundaries

Observation 200 does not establish:

- an exhaustive recurrence-policy taxonomy;
- Gregorian calendar implementation;
- leap-year handling;
- weekend or holiday shifting (F056);
- carry-forward semantics;
- provider-specific billing rules;
- recurrence cancellation or revision lifecycle;
- whether generated future occurrences should be persisted or projected;
- a first-class production Series object;
- persistence, CLI, TUI, or household-data changes.

Runtime remains `RESEARCH_ONLY`. Production waits for real dogfood pressure.
