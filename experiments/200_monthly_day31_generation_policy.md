# Observation 200 — Does a monthly day-31 Series determine its shorter-month generation rule?

Status: **F055 active falsification observation**

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

## Selected probes

### Representative clamp policy

Can a monthly day-31 rule generate on `LastDay` in a shorter month?

Expected: **SAT**.

### Same Series and observed pattern, different boundary result

Can Left and Right have exactly the same:

- Series membership;
- Monthly recurrence;
- nominal day 31;
- observed day 31 in JanLike;
- observed day 31 in MarLike;

while Left skips the shorter month and Right clamps to its last day?

Expected: **SAT**.

This is the central F055 witness.

## Deliberately too-strong checks

### Existing Series evidence determines short-month generation

Does equal Series membership + recurrence + nominal day + neighboring observations force the same shorter-month result?

Expected: **SAT counterexample**.

### Neighboring occurrences determine generation policy

Does observing the same day-31 pattern on both sides of the boundary reconstruct whether the Series skips or clamps?

Expected: **SAT counterexample**.

## Positive sufficiency check

### Explicit generation policy determines the selected boundary result

Once Series membership, recurrence, nominal day, and the explicit generation policy are fixed, can the shorter-month result still differ?

Expected counterexample: **UNSAT**.

If this holds, the selected information boundary is:

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

## Candidate interpretation if the matrix holds

F055 would close as a genuine counterexample to the tested compression:

```text
Work     DONE
Finding  COUNTEREXAMPLE
Runtime  RESEARCH_ONLY
```

The earned information would be only that a generation policy, or some information-equivalent distinction, is independently observable for this query.

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

Runtime remains `RESEARCH_ONLY` regardless of the result. Production waits for real dogfood pressure.
