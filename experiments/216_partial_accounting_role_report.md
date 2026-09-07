# Observation 216 — Partial AccountingRole reports under lossy-history pressure

Status: **COMPLETE — bounded report/classification observation / RESEARCH_ONLY**

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

The question is:

> Does truthful role-aware reporting require a retained `UnknownRole` value, or can
> a partial `Locus -> AccountingRole` relation plus an explicit unresolved Effect
> witness set express the same uncertainty with fewer semantic parts?

## Why not invent `UnknownRole` first?

`Unknown` can mean two different things:

```text
ontology:
  this thing has a stable semantic role called Unknown

observation:
  this query cannot currently justify a role for this evidence
```

The household pressure is currently the second kind. Treating uncertainty as another
accounting class would risk turning missing evidence into positive semantic evidence.

Observation 216 therefore gives the role relation cardinality `lone` and tests whether
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
retained household evidence whose source history does not justify a role at this
boundary.

Candidate relation:

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

## Qualified result

Branch execution at head `4575684f23b5f7cfc96ea89206e6762b35b42702`
completed successfully in dedicated Observation 216 run `34086151674`.
The workflow independently required the following exact SAT/UNSAT matrix and passed:

```text
partialRoleReportKeepsLossyEvidence                  SAT
completeRoleMapCanResolveAllEffects                   SAT
arbitraryCompletionChangesSelectedEvidence            SAT
ClassifiedAndUnresolvedPartition                      UNSAT
MissingRoleMeansNoEvidence                            SAT counterexample
NoUnresolvedIffEveryObservedLocusClassified           UNSAT
SameRoleMapDeterminesSamePartialReport                UNSAT
```

For Alloy `check`, `UNSAT` means no counterexample was found within the bounded scope.

## Findings

### Partial report keeps lossy evidence visible

Known Asset/Expense evidence can be selected normally while both Effects at the lossy
coordinate remain explicitly present in `unresolvedEffects`.

The report therefore does not need to discard unclassified history or pretend that it
belongs to an accounting role.

### Complete classification remains representable

If independent evidence later resolves every observed Locus, the same partial relation
naturally reduces to a complete report with an empty unresolved set.

This is representational sufficiency only. The witness does not authorize a real
classification for canonical lossy household history.

### A default role is a semantic decision

Two worlds can contain the same Effects and the same clean role assignments while one
leaves the lossy Locus unresolved and the other assigns it `ExpenseRole`.

That completion changes both the Expense-selected evidence and the unresolved set.
Therefore a report or UI cannot safely use "unclassified means Expense" as a display
default.

### Classified and unresolved form an exact partition

The qualified assertion is:

```text
classified ∪ unresolved = all evidence in scope
classified ∩ unresolved = ∅
```

So lack of classification does not make an Effect disappear.

### Missing role is not missing evidence

The assertion

```text
no role -> no evidence
```

has a counterexample.

The open-world distinction is therefore concrete:

```text
no role
!=
no evidence
```

### Completeness needs no extra role atom

For this fully observed specimen, the unresolved set is empty exactly when every
observed Locus has some explicit role. The bounded model needs no additional
`UnknownRole` value to state whether a report is complete.

### No hidden classifier is needed

Two worlds with the same explicit role relation produce the same selected and
unresolved Effect sets. Prefix spelling, UI defaults, and presentation code therefore
need not participate in the semantic answer.

## Qualified interpretation

The smallest surviving representation is:

```text
AccountingRole relation
  Locus -> lone AccountingRole

Role-aware report
  classified evidence by role
  unresolved evidence
```

with:

```text
missing AccountingRole
    != UnknownRole object
    != zero
    != irrelevant

missing AccountingRole
    = unresolved classification evidence at this report boundary
```

Current lossy-history pressure therefore does **not** earn a retained `UnknownRole`
constructor.

This is compatible with Observation 215: recoverable historical Effects may be split
into clean role-homogeneous Loci, while genuinely lossy rows can remain observable but
unclassified instead of forcing a more complicated production ontology.

## Production pressure

A future role-aware Application review could return something equivalent to:

```text
RoleReportInspection
  selectedByRole
  unresolvedEffects
```

and derive report completeness locally:

```text
Complete
  unresolvedEffects = ∅

Partial
  unresolvedEffects != ∅
```

That is a projection candidate, not yet production API or retained Core state.

## Deliberate boundaries

Observation 216 does **not** establish:

- production AccountingRole persistence;
- the final set of AccountingRole constructors;
- that role belongs permanently to Locus rather than another qualified coordinate;
- production report totals or recognition-time policy;
- that every unresolved Effect should block every report;
- an `UnknownRole` prohibition for all future use cases;
- automatic classification of `expenses:予備`, `income:返金`, or settlement rows;
- destructive canonical migration;
- migration from description text alone.

It only establishes, within the bounded specimen, that current lossy-history pressure
does not require a new semantic role value in order to keep unresolved evidence
observable.

## Next gate

The next practical question is quantity-level:

> For the current household migration candidate, can clean role assignments and
> unresolved historical evidence be combined with report quantities without silently
> changing Balance Sheet / P&L-shaped answers?

That is the point to compare resolved role totals plus an unresolved quantity/evidence
frontier against selected current household data. Production persistence should still
wait for that pressure.
