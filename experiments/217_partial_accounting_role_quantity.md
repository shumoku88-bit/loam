# Observation 217 — Quantity frontier for partial AccountingRole reports

Status: **PROBE — quantity/report completeness boundary / RESEARCH_ONLY**

## Trigger

Observation 216 qualified a smaller representation for role-aware reports over
historically lossy evidence:

```text
Locus -> lone AccountingRole
+
role-selected Effects
+
unresolved Effects
```

That observation deliberately did not add quantity aggregation.

The next question is whether role totals can safely summarize a partial report, or
whether numeric cancellation can make unresolved history disappear from view.

## Question

> Can resolved AccountingRole quantities be published truthfully while some Effects
> remain unclassified, and what extra frontier must remain visible so that a partial
> result is not mistaken for a complete Balance Sheet / P&L-shaped answer?

## Specimen

The model contains ordinary classified evidence:

```text
AssetEffect    +10
ExpenseEffect   +7
```

and two kinds of unresolved pressure.

### Canceling unresolved coordinate

```text
+5
-5
```

The net quantity is zero, but two Effects still exist.

### Nonzero unresolved coordinate

```text
+3
```

Assigning this coordinate to a role necessarily changes that role's resolved total.

The two cases let the model distinguish:

```text
quantity completeness
from
evidence/classification completeness
```

## Candidate partial quantity report

```text
RoleQuantityInspection
  role totals
  unresolved Effects
  unresolved quantity projection
```

This is observation vocabulary only. No production type is proposed yet.

## Expected matrix

```text
partialQuantityReportWitness                         SAT
zeroUnresolvedQuantityCanStillBePartial              SAT
arbitraryCompletionCanChangeResolvedQuantity         SAT
sameRoleTotalsCanHideDifferentCompleteness           SAT
ClassifiedAndUnresolvedQuantityPartition             UNSAT
ZeroUnresolvedQuantityMeansComplete                  SAT counterexample
SameRoleTotalsDetermineCompleteness                  SAT counterexample
FullyClassifiedRoleTotalsCoverQuantity               UNSAT
SameRoleMapDeterminesSameQuantityReport              UNSAT
```

For Alloy `check`, `UNSAT` means no counterexample was found in the bounded scope.

## Expected interpretation

### Partial totals are still useful

Known roles may have exact resolved totals even while other evidence remains
unclassified. A report need not choose between lying and refusing every quantity.
It can publish a qualified partial answer.

### Unresolved net zero is not completeness

If unresolved Effects are `+5` and `-5`, then:

```text
unresolvedTotal = 0
```

but:

```text
unresolvedEffects != ∅
```

Therefore `0` cannot be used as a completeness bit.

### Same displayed totals can hide different epistemic state

If the canceling coordinate is later assigned to `ExpenseRole`, the Expense total may
remain numerically unchanged because `+5 + -5 = 0`.

The two worlds can then have identical role totals while one is partial and the other
complete.

So:

```text
same numbers
!=
same evidence state
```

This is the main pressure result sought by Observation 217.

### Nonzero completion changes quantity

For the `+3` unresolved coordinate, assigning a role changes that role total. A UI
cannot fill the gap with a default role merely to make a complete-looking table.

## Deliberate boundaries

Even if qualified, Observation 217 does **not** establish:

- production AccountingRole persistence;
- a production `RoleQuantityInspection` type;
- which historical Loci should be classified;
- recognition-time or accrual policy;
- Balance Sheet or P&L sign/presentation conventions;
- that all unresolved evidence should be aggregated into one scalar;
- that a zero-net unresolved frontier is economically unimportant;
- destructive canonical migration.

In fact, the canceling witness is pressure **against** treating one unresolved scalar
as sufficient evidence. The unresolved Effect frontier remains the stronger witness.

## Next gate if qualified

Apply this law to the concrete household migration candidate:

1. choose only already-justified clean role assignments;
2. keep lossy/unresolved Loci outside those role totals;
3. compute selected role totals and unresolved Effect/quantity evidence from canonical
   data;
4. compare candidate report answers before and after any proposed Locus migration;
5. refuse any cutover that turns a partial answer into an apparently complete one
   without new evidence.

Only after that data-level parity exercise should production AccountingRole
persistence or a role-aware report boundary be considered earned.
