# Observation 228 — Can household cycle selection collapse to explicit boundary sources?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J at exact model head `553e817b5f3413abd236ef248655d50d55ab9580`; explicit boundary-source selection is sufficient in the bounded model while cadence labels and per-window Cycle identity are not**

## Pressure

The household wants several useful time views at once:

- a two-month pension-income cycle;
- a salary/payday cycle;
- card or billing boundaries;
- arbitrary one-off household windows;
- calendar month as a UI convenience.

The immediate temptation is to introduce separate retained domain objects such as `PensionCycle`, `SalaryCycle`, `CardCycle`, or a generic `BudgetPeriod` instance.

Observation 158 already found that period identity is not earned merely to select facts inside a half-open `[start, end)` window. Observation 196 then found that a selected day alone cannot choose a unique household window.

This observation asks the next smaller question:

> Is a selected **boundary source** plus explicit ordered boundary dates enough to choose the current `[start, end)` window, while cadence names and per-window Cycle identity remain unnecessary?

## Candidate vocabulary

```text
BoundarySource
  -> explicit boundary dates
  -> optional descriptive cadence

selected date
+ selected BoundarySource
  -> nearest boundary at-or-before selected date
  -> nearest boundary after selected date
  -> [start, end)
```

The source could later be presented as `Pension`, `Salary`, `Card`, or `Custom`, but this observation does not earn any of those as Core types.

The important distinction is:

```text
boundary-source choice != retained Cycle instance identity
```

A source identity is only needed when two independent boundary sets overlap the same selected date and therefore produce different windows.

## Why explicit boundaries instead of cadence arithmetic?

A label such as `monthly` or `bimonthly` does not by itself determine concrete calendar boundaries. Real household dates can shift, be edited, stop, or remain unknown beyond the current evidence horizon.

Explicit boundary dates can represent regular and irregular spacing with the same small mechanism. The model therefore treats cadence as optional descriptive evidence, not as a generator.

This also preserves open-world behavior: if the selected date has no known next boundary, the window is unresolved rather than silently extended.

## Alloy result matrix

Exact model head: `553e817b5f3413abd236ef248655d50d55ab9580`.

```text
representativeHousehold                           SAT
customWithoutCadenceStillSelects                 SAT
sameCadenceCanYieldDifferentWindows              SAT
overlappingBoundarySourcesNeedSourceChoice       SAT
incompleteFutureLeavesWindowUndefined            SAT
AdjacentBoundaryWindowIsUnique                   UNSAT counterexample
DefinedWindowContainsSelectedDate                UNSAT counterexample
SameBoundarySetYieldsSameWindowRegardlessOfSourceName
                                                  UNSAT counterexample
```

The dedicated Observation 228 workflow required exactly this matrix and completed successfully on the exact model head.

## Probes

### 1. Representative household sources coexist

A pension boundary source and salary boundary source both cover the same selected date but produce different adjacent windows.

Result: **SAT**.

This represents the practical fact that a date can simultaneously belong to a pension cycle and a salary cycle. The user must select which question is being asked.

### 2. Custom / irregular boundaries work without cadence

A source with no cadence label and unevenly spaced explicit boundaries still selects one adjacent window.

Result: **SAT**.

Recurring-rule machinery is therefore not needed merely to use arbitrary household windows.

### 3. Same cadence can yield different concrete windows

Two boundary sources share the same `BiMonthly` cadence label but retain different concrete boundaries around the same selected date.

Result: **SAT**.

Cadence alone cannot be the production window-selection evidence.

### 4. Overlapping sources require source choice

Pension and Salary both define valid windows around one selected date, but the windows differ.

Result: **SAT**.

This is the pressure that earns selection of a boundary source. It does **not** earn an identity for each individual cycle occurrence.

### 5. Missing next boundary stays unresolved

The selected date is after the final known boundary and there is no next retained boundary.

Result: **SAT** witness with no defined window.

This is the open-world stop condition. Do not infer a future boundary from the previous spacing merely because the source has historically looked regular.

### 6. Adjacent window is unique within one source

For a fixed ordered boundary set and selected date, there is at most one nearest at-or-before boundary and one nearest after boundary.

Result: **UNSAT counterexample**.

### 7. A defined adjacent window contains the selected date

Result: **UNSAT counterexample**.

### 8. Source name alone adds no answer when boundary sets are equal

Two differently named sources with identical explicit boundaries must derive the same adjacent window for the same selected date.

Result: **UNSAT counterexample**.

Identity matters only insofar as it selects different boundary evidence, not because a `PensionCycle` atom has extra semantics of its own.

## Qualified finding

The smallest bounded production-facing shape is:

```text
selected date
+ selected boundary source
+ explicit known boundary dates
-> [start, end)
-> existing Budget Window / Stock-Flow projection
```

This is enough for pension, payday, statement, and custom windows to coexist without adding separate Cycle types or changing downstream report semantics.

What is earned is **boundary-source choice**, not retained per-window Cycle identity.

Cadence may remain descriptive or presentation-level evidence. It is not qualified as a boundary generator.

## Household implications

For a pension-oriented view, LOAM does not need to know what a pension *cycle object* is. It only needs a justified pension boundary source containing the actual boundary dates that the household wants to use.

Likewise a salary-oriented view can select another boundary source over the same canonical events. Both may overlap naturally.

Calendar month remains a presentation convenience that can directly produce a `[start, end)` without pretending to be the household cycle.

A later practical UI could therefore expose something like:

```text
Window source
  Pension
  Salary
  Card
  Custom
```

and hand only the selected `[start, end)` to existing reports. The report engines do not need to learn pension, salary, or card ontology.

## Important limits

This observation does not decide:

- where a saved boundary source should live;
- whether boundary dates are manually entered, imported, or derived from another qualified complete source;
- whether Scheduled is ever complete enough to supply such boundaries automatically;
- rollover semantics between adjacent windows;
- recurrence generation;
- business-day adjustment rules;
- naming / UI shortcuts;
- parallel budget regimes that require explicit fact membership beyond coordinates.

In particular, current Scheduled evidence is open-world and must not be silently promoted into a complete future boundary generator.

## Stop condition

Do not add a retained Cycle instance merely because several household cadences exist.

Add stronger identity or membership only if two worlds can agree on the selected boundary source, all explicit boundary dates, the selected date, and all household facts yet still require different downstream window membership or answers.
