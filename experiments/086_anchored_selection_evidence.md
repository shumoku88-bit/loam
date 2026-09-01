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

The new question is:

> Do starting-basis presence and Event presence contain enough information to determine which coordinates an anchored-current query should select?

## Model boundary

Observation 086 deliberately does **not** introduce `Use`, `Holding`, `Expense`, `Account`, AccountingRole, or another intrinsic coordinate role.

The Alloy model keeps only:

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

Observed:

```text
samePhysicalSignatureDifferentSelection  SAT
```

So a local classifier using only basis/activity presence cannot reconstruct the query's selected set.

## Basis-only policy

Selecting only basis-bearing coordinates has one useful law: every selected coordinate already has the premise required by anchored-current projection.

Observed:

```text
BasisOnlyQueriesAreAnswerable  UNSAT counterexample
```

But that safety comes from shrinking the selected set. The model also admits a basisless active coordinate which the anchored question wants to include:

```text
basisOnlyCanHideSelectedBasislessActivity  SAT
```

This captures the new-locus pressure. A coordinate can first become relevant after the application origin, so basis presence alone cannot be the universal criterion for whether it belongs in a later anchored question.

The observation does not yet decide how such a coordinate obtains an anchor, whether its first admitted Event can establish an origin, or whether another fact is required.

## All-represented policy

Selecting every coordinate with either basis or Event activity avoids silently hiding newly observed coordinates.

But it can pull a basisless activity coordinate into an anchored query and make the query unavailable.

Observed:

```text
allRepresentedCanForceMissingBasis  SAT
AllRepresentedQueriesAreAnswerable  SAT counterexample
```

So the two obvious enumeration policies lose different information:

```text
basis-only
  -> always locally answerable
  -> may hide a selected basisless coordinate

all represented
  -> does not hide represented coordinates
  -> may force missing-basis failure for a coordinate the question did not need
```

## Same facts, different questions

Two anchored questions can share the exact same retained physical facts while selecting different coordinate sets.

Observed:

```text
sameFactsDifferentAnchoredQuestions  SAT
PhysicalFactsDetermineSelection      SAT counterexample
```

The central independence result is therefore:

```text
basis presence + Event presence
    -/-> anchored-current selection
```

The same physical fact set can support more than one legitimate question surface.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced the complete expected boundary:

```text
samePhysicalSignatureDifferentSelection       SAT
basisOnlyCanHideSelectedBasislessActivity      SAT
allRepresentedCanForceMissingBasis             SAT
sameFactsDifferentAnchoredQuestions            SAT
BasisOnlyQueriesAreAnswerable                  UNSAT counterexample
AllRepresentedQueriesAreAnswerable             SAT counterexample
PhysicalFactsDetermineSelection                SAT counterexample
```

The first four commands are positive witnesses. `BasisOnlyQueriesAreAnswerable` has no counterexample because selecting exactly the basis set trivially supplies basis for every selected coordinate. The final two checks intentionally fail: selecting every represented coordinate can be unanswerable, and retained physical facts do not determine one selected query set.

## Finding

Observation 085 and 086 compose into a sharper boundary:

```text
085:
query mode determines whether basis is a premise

086:
physical basis/activity presence does not determine
which coordinates that query should select
```

Therefore none of these implications is earned:

```text
has basis       -> current/holding coordinate
has Event       -> must appear in current
no basis        -> activity-only coordinate
```

The current dogfood problem is not merely a missing-zero problem and not merely a filtering problem. It is a missing distinction between:

```text
what facts exist
what projection is being asked
which coordinates that projection selects
```

Those three layers should not be silently collapsed.

## What this observation does not decide

A future production repair may use one of several shapes:

- explicit query selection;
- an anchored-coordinate enrollment fact earned by practical operations;
- separate answerable and unresolved coordinate surfaces;
- a rule tied to a concrete operation that creates a new anchored coordinate;
- another representation discovered by further dogfood.

Observation 086 does not choose among them.

In particular, it does not earn a persistent generic `Query`, `Selection`, `HoldingRole`, or `UseRole` type merely because the experiment needed a selected set.

## Tool choice

Alloy is sufficient because the question is structural indistinguishability:

- two coordinates can share retained local evidence but differ in query selection;
- two questions can share retained physical facts but select differently;
- the two obvious set-derived policies lose different information.

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
