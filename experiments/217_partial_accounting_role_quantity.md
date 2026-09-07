# Observation 217 — Quantity frontier for partial AccountingRole reports

Status: **COMPLETE — bounded quantity/report completeness observation / RESEARCH_ONLY**

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
Observation 217 asks whether numeric summaries can erase that uncertainty frontier.

## Question

> Can resolved AccountingRole quantities be published truthfully while some Effects
> remain unclassified, and what must remain visible so that a partial result is not
> mistaken for a complete Balance Sheet / P&L-shaped answer?

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

The two cases distinguish:

```text
quantity value
from
evidence/classification completeness
```

## Qualified result

Dedicated branch run `34086560597` completed SUCCESS at head
`6d926a4e494ed0ef28abbba67ceac4479b15a6ef`.
The workflow required this exact SAT/UNSAT matrix and passed:

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

## Findings

### Partial exact totals are useful

Known roles may have exact resolved totals while other evidence remains unclassified.
A truthful report therefore need not choose between refusing every quantity and
pretending the whole accounting view is complete.

The bounded specimen supports:

```text
resolved role quantities
+
unresolved Effect frontier
```

### Unresolved net zero is not completeness

The canceling witness establishes:

```text
unresolved Effects = { +5, -5 }
unresolved total   = 0
```

while unresolved evidence still exists.

Therefore:

```text
unresolvedTotal = 0
!=
Complete
```

A scalar unresolved quantity cannot serve as the report's completeness bit.

### Same displayed totals can hide different evidence state

The strongest witness assigns the canceling Locus to `ExpenseRole` in one world and
leaves it unresolved in another. Because `+5 + -5 = 0`, every role total can remain
numerically identical while one world is partial and the other fully classified.

Thus:

```text
same role totals
!=
same completeness
```

This means a table of numbers alone is insufficient to communicate how much of the
retained evidence those numbers explain.

### Nonzero completion changes resolved quantity

For the separate `+3` unresolved coordinate, assigning `ExpenseRole` changes the
resolved Expense total. Filling a missing role is therefore a semantic decision, not
a formatting convenience.

### Partition remains exact

As in Observation 216, classified and unresolved Effects form an exact partition.
No evidence disappears merely because it lacks a role.

### Fully classified totals cover the specimen

When the unresolved frontier is empty, summing the role totals accounts for the full
modeled quantity. This establishes the ordinary complete case without changing the
meaning of the partial case.

### No hidden quantity classifier

The same explicit role map determines the same role totals, unresolved Effect set, and
unresolved quantity projection. Prefix syntax or presentation defaults are unnecessary.

## Qualified interpretation

The smallest surviving quantity-level shape is not merely:

```text
role -> quantity
```

but something equivalent to:

```text
resolvedByRole
unresolvedEffects
```

with an optional unresolved quantity projection for convenience.

The Effect frontier is stronger than the scalar because unresolved Effects can cancel.

Conceptually:

```text
value dimension:
  what exact quantity is justified for each classified role?

completeness dimension:
  which retained Effects remain outside the classification?
```

These dimensions are independent enough that one cannot be reconstructed from the
other.

This is a small local law. Observation 217 does not introduce a general abstract-
interpretation framework or a new completeness lattice into production.

## Deliberate boundaries

Observation 217 does **not** establish:

- production AccountingRole persistence;
- a production `RoleQuantityInspection` type;
- which historical Loci should be classified;
- recognition-time or accrual policy;
- Balance Sheet or P&L sign/presentation conventions;
- that all unresolved evidence should be aggregated into one scalar;
- that a zero-net unresolved frontier is economically unimportant;
- destructive canonical migration.

The canceling witness is specifically pressure against treating one unresolved scalar
as sufficient evidence.

## Next gate

Apply this law to the concrete household migration candidate:

1. choose only already-justified clean role assignments;
2. keep lossy/unresolved Loci outside those role totals;
3. compute selected role totals and unresolved Effect/quantity evidence from canonical
   data;
4. compare candidate report answers before and after proposed Locus migration;
5. refuse any cutover that turns a partial answer into an apparently complete one
   without new evidence.

Only after that data-level parity exercise should production AccountingRole
persistence or a role-aware report boundary be considered earned.
