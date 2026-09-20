import Loam.Core.AccountingRole

namespace Loam.Observation285

open Loam.Core

set_option autoImplicit false

/-!
# Observation 285 — chained migration preserves what?

LOAM has already qualified several one-shot migration / re-key boundaries.

This observation asks a different long-horizon question:

> If representation changes happen repeatedly, what preservation condition is
> strong enough to keep future household questions answerable?

The selected pressure is intentionally small.

Two source Loci currently have the same AccountingRole, so a report that asks
only for total Expense cannot distinguish them.

A tempting migration can therefore merge them and still pass the current report.

But a future household question may need the two source identities separately.

This observation compares:

1. a weak migration judged only by current report parity;
2. two successive injective re-keys that preserve the distinction.

No production persistence or household data is changed.
-/

structure Row where
  locus : LocusId
  role : AccountingRole
  quanta : Int
deriving Repr, DecidableEq

private def oldA : LocusId := ⟨"old-a"⟩
private def oldB : LocusId := ⟨"old-b"⟩
private def merged : LocusId := ⟨"merged-expense"⟩

private def midA : LocusId := ⟨"mid-a"⟩
private def midB : LocusId := ⟨"mid-b"⟩
private def finalA : LocusId := ⟨"final-a"⟩
private def finalB : LocusId := ⟨"final-b"⟩

def quantityAt (rows : List Row) (locus : LocusId) : Int :=
  rows.foldl
    (fun total row =>
      if row.locus = locus then total + row.quanta else total)
    0

def expenseTotal (rows : List Row) : Int :=
  rows.foldl
    (fun total row =>
      if row.role = .expense then total + row.quanta else total)
    0

private def sourceLeft : List Row := [
  { locus := oldA, role := .expense, quanta := 700 },
  { locus := oldB, role := .expense, quanta := 300 }
]

private def sourceRight : List Row := [
  { locus := oldA, role := .expense, quanta := 600 },
  { locus := oldB, role := .expense, quanta := 400 }
]

/--
A deliberately weak migration candidate.

It preserves only the currently selected Expense total and collapses every
source distinction that contributed to that answer.
-/
def collapseToExpenseReport (rows : List Row) : List Row := [
  { locus := merged, role := .expense, quanta := expenseTotal rows }
]

/--
Both source worlds produce the same current Expense report.

So a migration qualification that checks only this report sees no difference.
-/
theorem selected_current_report_cannot_distinguish_sources :
    expenseTotal sourceLeft = expenseTotal sourceRight ∧
    expenseTotal sourceLeft = 1000 := by
  native_decide

/--
The weak migrated representation is exactly the same for two source worlds.
-/
theorem weak_migration_collapses_distinct_sources :
    collapseToExpenseReport sourceLeft =
      collapseToExpenseReport sourceRight := by
  native_decide

/--
But a later identity-sensitive question distinguishes the source worlds.

Therefore the collapsed migrated image cannot determine this future answer.
-/
theorem same_weak_migrated_image_different_future_answer :
    collapseToExpenseReport sourceLeft =
        collapseToExpenseReport sourceRight ∧
    quantityAt sourceLeft oldA != quantityAt sourceRight oldA := by
  native_decide

/-!
## Safe contrast: repeated one-to-one re-key

The next candidate changes spelling twice while retaining the independent
coordinate distinction.

The new tokens carry no chronology or semantic rank. They are merely the target
identity spellings of two successive representation changes.
-/

def firstRekey (locus : LocusId) : LocusId :=
  if locus = oldA then midA
  else if locus = oldB then midB
  else locus

def secondRekey (locus : LocusId) : LocusId :=
  if locus = midA then finalA
  else if locus = midB then finalB
  else locus

def migrateRows
    (rekey : LocusId -> LocusId)
    (rows : List Row) : List Row :=
  rows.map fun row => { row with locus := rekey row.locus }

private def afterFirst : List Row :=
  migrateRows firstRekey sourceLeft

private def afterSecond : List Row :=
  migrateRows secondRekey afterFirst

/--
The current report is preserved through both representation changes.
-/
theorem two_rekeys_preserve_selected_report :
    expenseTotal sourceLeft = expenseTotal afterFirst ∧
    expenseTotal afterFirst = expenseTotal afterSecond := by
  native_decide

/--
More importantly, the source-specific quantities are still recoverable under
the exact composed identity translation.
-/
theorem two_rekeys_preserve_identity_sensitive_answers :
    quantityAt sourceLeft oldA = quantityAt afterFirst midA ∧
    quantityAt sourceLeft oldB = quantityAt afterFirst midB ∧
    quantityAt sourceLeft oldA = quantityAt afterSecond finalA ∧
    quantityAt sourceLeft oldB = quantityAt afterSecond finalB := by
  native_decide

/--
The final generation remains distinguishable at the same cardinality as the
source for the selected coordinates.
-/
theorem chained_rekey_does_not_merge_selected_identities :
    finalA != finalB ∧
    quantityAt afterSecond finalA = 700 ∧
    quantityAt afterSecond finalB = 300 := by
  native_decide

/-!
## Finding

Repeated migration does not create a new arithmetic problem.

It creates a **preservation-contract problem**.

The weak rule:

    before current report = after current report

is insufficient.

Two source worlds can agree on that report and become the exact same migrated
representation while still requiring different answers to a later legitimate
query.

The stronger long-horizon shape is:

    semantic distinctions that remain retained
    + complete reference translation
    + injective identity transport where identity is still observable
        -> repeated representation change may compose safely

For LOAM this means a migration should not be qualified solely against the set
of reports that happen to exist on migration day.

The preservation boundary must be owned by the retained semantic evidence and
its reference closure.

This observation does **not** earn:

- a generic migration framework;
- a universal promise that every old byte or token survives;
- permanent compatibility readers for every historical schema;
- prohibition on intentional semantic compression;
- preservation of distinctions already proved unobservable and deliberately
  retired;
- production migration code.

It does earn one useful future audit question:

> For every destructive representation change, what independently observable
> distinction is being intentionally preserved, translated, or explicitly
> retired?

That question remains meaningful after the first, second, or tenth migration.
-/

end Loam.Observation285
