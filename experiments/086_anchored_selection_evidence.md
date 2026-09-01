# Observation 086 — Can basis presence and Event presence determine anchored-current selection?

## Question

Observation 085 established that starting-basis applicability is query-relative:

```text
missing basis
    -> anchored-current unavailable

missing basis
    -/-> activity unavailable
```

It also rejected the shortcut that a `Locus × Measure` coordinate has one intrinsic projection meaning.

That leaves a second problem in the current daily-use path.

A tempting repair would enumerate an anchored-current view from facts already present in storage:

```text
basis-only policy:
  select coordinates that have starting basis

all-represented policy:
  select coordinates that have basis or Event activity
```

Both are attractive, but each may collapse a distinction exposed by dogfood.

The new question is:

> Do starting-basis presence and Event presence contain enough information to determine which coordinates an anchored-current query should select?

## Pressure

Two basisless coordinates can have the same locally visible shape:

```text
basis:    absent
activity: present
```

Yet a later question may want different readings.

One can be useful only as an activity coordinate for the current question. Another can be a coordinate whose current quantity became relevant only after the application origin, for example after quantity first moved into a newly used locus.

Observation 086 deliberately does **not** name those coordinates `Use`, `Holding`, `Expense`, `Account`, or any other domain role.

Instead, the model keeps only:

```text
Facts
  basis:   set Coordinate
  active:  set Coordinate

AnchoredQuestion
  facts:    one Facts
  selected: set Coordinate
```

`selected` is experiment-local question information. It is not proposed as a persistent production relation.

## Same local evidence, different query selection

The first witness uses three coordinates:

```text
anchored:
  basis present
  activity present
  selected

activityOnly:
  basis absent
  activity present
  not selected

laterCurrent:
  basis absent
  activity present
  selected
```

The last two coordinates have identical local physical evidence:

```text
basis absent + activity present
```

but the question selects them differently.

Expected:

```text
samePhysicalSignatureDifferentSelection  SAT
```

If SAT, a local classifier using only basis/activity presence cannot recover the query's selected set.

## Basis-only policy

Selecting only basis-bearing coordinates has one pleasant law: every selected coordinate has the premise required by the anchored-current projection.

Expected check:

```text
BasisOnlyQueriesAreAnswerable  UNSAT counterexample
```

But basis-only selection can omit a basisless coordinate that the anchored question wants to include.

Expected witness:

```text
basisOnlyCanHideSelectedBasislessActivity  SAT
```

This captures the new-locus pressure. A coordinate can first become relevant after the application origin and therefore need not possess a starting basis merely because it participates in a later current question.

The observation does not yet decide how such a coordinate obtains an anchor, whether its first admitted Event can serve as an origin, or whether another fact is required. Those are later questions.

## All-represented policy

Selecting every coordinate with either basis or Event activity avoids silently hiding newly observed coordinates.

But Observation 085 already showed the cost: an activity-only coordinate with no basis can make the entire anchored-current query unavailable.

Expected witness/check:

```text
allRepresentedCanForceMissingBasis  SAT
AllRepresentedQueriesAreAnswerable  SAT counterexample
```

So the two obvious enumeration policies pull in opposite directions:

```text
basis-only
  -> always locally answerable
  -> may hide a selected basisless coordinate

all represented
  -> does not hide represented coordinates
  -> may force missing-basis failure for coordinates the question did not need
```

## Same facts, different questions

The model also asks whether two anchored questions can share the exact same retained facts while selecting different coordinate sets.

Expected:

```text
sameFactsDifferentAnchoredQuestions  SAT
PhysicalFactsDetermineSelection      SAT counterexample
```

This is the central independence claim:

```text
basis presence + Event presence
    -/-> anchored-current selection
```

The physical fact set can support more than one legitimate question surface.

## Interpretation if qualified

If the expected results hold, Observation 085 and 086 compose into a sharper boundary:

```text
085:
query mode determines whether basis is a premise

086:
physical basis/activity presence does not determine
which coordinates that query should select
```

Therefore production should not silently use either of these as hidden ontology:

```text
has basis       -> current/holding coordinate
has Event       -> must appear in current
no basis        -> activity-only coordinate
```

Those implications are not earned.

A future production repair may need one of several shapes:

- explicit query selection;
- an anchored-coordinate enrollment fact earned by practical operations;
- separate answerable and unresolved coordinate surfaces;
- a rule tied to a concrete operation that creates a new anchored coordinate;
- another representation discovered by further dogfood.

Observation 086 does not choose among them.

## Tool choice

Alloy is sufficient because the question is structural indistinguishability:

- can two coordinates have the same retained local evidence but differ in query selection;
- can two questions share the same retained physical facts but select differently;
- do the two obvious set-derived policies lose different information.

No temporal ordering or concurrency law is involved, so TLA+ is not yet earned. No unbounded arithmetic theorem is being claimed, so Lean is unnecessary at this checkpoint.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no `HoldingRole` / `UseRole`;
- no Account / Expense Category / AccountingRole;
- no persistent generic `Query` or `Selection` type;
- no private household values committed.
