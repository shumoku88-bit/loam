# Observation 216 — Partial AccountingRole reports under lossy-history pressure

Status: **PROBE — report/classification boundary / RESEARCH_ONLY**

## Trigger

Observation 215 showed that a mixed legacy Locus does not force permanent
Effect-level AccountingRole when migration can split recoverable Effects into clean
new identities.

The concrete `loam-data` mixed-Locus review then exposed a harder class of evidence.
Some historical rows, especially old cash-withdrawal entries stored at
`expenses:予備`, crossed a tracking boundary and do not retain enough information to
reconstruct a stronger physical cash history safely.

For such evidence, migration has a third possibility besides "classify" and
"rewrite":

```text
leave classification unresolved
```

The new question is:

> Does truthful role-aware reporting require a retained `UnknownRole` value, or can
> a partial `Locus -> AccountingRole` relation plus an explicit unresolved Effect
> witness set express the same uncertainty with fewer semantic parts?

## Why not invent `UnknownRole` first?

`Unknown` can mean two very different things:

```text
ontology:
  this thing has a stable semantic role called Unknown

observation:
  this query cannot currently justify a role for this evidence
```

The household pressure is currently the second kind. Treating uncertainty as a sixth
accounting class would risk turning missing evidence into positive semantic evidence.

Observation 216 therefore gives the role relation cardinality `lone` and asks whether
that smaller representation is enough.

## Observation-local specimen

The model contains three Loci:

```text
AssetLocus
ExpenseLocus
LossyLocus
```

and four Effects:

```text
AssetEffect      -> AssetLocus
ExpenseEffect    -> ExpenseLocus
LossyEffectA     -> LossyLocus
LossyEffectB     -> LossyLocus
```

The first two coordinates are intentionally classifiable. The third represents
retained household evidence whose source history does not justify a production role
at this boundary.

Production candidate relation:

```text
Locus -> lone AccountingRole
```

Report projection:

```text
role-selected Effects
+
unresolved Effects
```

There is deliberately no `UnknownRole` atom in the model.

## Expected matrix

```text
partialRoleReportKeepsLossyEvidence                  SAT
completeRoleMapCanResolveAllEffects                   SAT
arbitraryCompletionChangesSelectedEvidence            SAT
ClassifiedAndUnresolvedPartition                      UNSAT
MissingRoleMeansNoEvidence                            SAT counterexample
NoUnresolvedIffEveryObservedLocusClassified           UNSAT
SameRoleMapDeterminesSamePartialReport                UNSAT
```

Interpretation of Alloy `check` results follows repository convention: `UNSAT` means
no counterexample was found within the bounded scope.

## What each command asks

### Partial report witness

The first run asks whether known Asset/Expense evidence can still be reported while
both Effects at the lossy coordinate remain explicitly observable as unresolved.

Expected: **SAT**.

### Complete classification remains representable

The second run assigns the lossy coordinate an ordinary role only as observation
scaffolding. If independent evidence eventually justified such a classification, the
same partial relation should reduce to a complete report with no unresolved Effects.

Expected: **SAT**.

This does not authorize that classification for canonical household data.

### A default role is not presentation-only

The third run compares two worlds with the same Effects and the same clean roles. One
leaves the lossy Locus unresolved; the other fills it with `ExpenseRole`.

The selected Expense evidence and unresolved set must change.

Expected: **SAT**.

So a UI/report layer cannot safely say "unclassified means Expense" merely to get a
total.

### Exact partition

Every Effect should be either selected by some explicit role or present in the
unresolved set, never both and never neither.

Expected check result: **UNSAT**.

### Missing role is not missing evidence

The assertion that an unclassified Locus contains no Effects should fail.

Expected check result: **SAT counterexample**.

This is the key open-world distinction:

```text
no role
!=
no evidence
```

### Completeness requires no extra role value

For this fully observed specimen, the unresolved set is empty exactly when every
observed Locus has some explicit role.

Expected check result: **UNSAT**.

### No hidden classifier

Two worlds with the same explicit role relation should produce the same selected and
unresolved Effect sets.

Expected check result: **UNSAT**.

This keeps token spelling, colon prefixes, and UI defaults out of the semantic answer.

## Interpretation if qualified

The smallest surviving representation would be:

```text
AccountingRole relation
  Locus -> lone AccountingRole

Role-aware report
  classified evidence by role
  unresolved evidence
```

with the law:

```text
classified ∪ unresolved = all evidence in scope
classified ∩ unresolved = ∅
```

This yields a useful distinction:

```text
missing AccountingRole
    != UnknownRole object
    != zero
    != irrelevant

missing AccountingRole
    = this report has unresolved classification evidence
```

That is attractive for LOAM because uncertainty remains at the observation boundary
instead of becoming a retained ontology value merely to make a table rectangular.

## Production pressure if the matrix survives

A future role-aware Application review could return something shaped like:

```text
RoleReportInspection
  selectedByRole
  unresolvedEffects
```

or an equivalent small projection.

The report may then distinguish:

```text
Complete
  unresolvedEffects = ∅

Partial
  unresolvedEffects != ∅
```

without inventing a Core `UnknownRole` constructor.

This would also let a historical lossy coordinate remain visible while clean migrated
Loci participate in accounting-shaped reports normally.

## Deliberate boundaries

Even a successful Observation 216 does **not** establish:

- production AccountingRole persistence;
- the final set of AccountingRole constructors;
- that role belongs permanently to Locus rather than another qualified coordinate;
- production report totals or recognition-time policy;
- that every unresolved Effect should block every report;
- an `UnknownRole` prohibition for all future use cases;
- automatic classification of `expenses:予備`, `income:返金`, or settlement rows;
- destructive canonical migration;
- migration from description text alone.

It only asks whether current lossy-history pressure requires a new semantic role value.

## Next gate

If the partial projection survives, the next practical question is narrower:

> For the current household migration candidate, can clean role assignments and
> unresolved historical evidence be combined with report quantities without silently
> changing Balance Sheet / P&L style answers?

That would be the point to add quantity aggregation and compare a partial report with
selected current household evidence. Do not add production persistence before that
quantity-level pressure exists.
