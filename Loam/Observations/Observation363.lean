namespace Loam.Observation363

set_option autoImplicit false

/-!
# Observation 363 — real workflows separate incremental reconciliation from complete allocation publication

Observation 362 left one practical question open:

> Does a real settlement workflow require several correspondence revisions to
> become current together, or is row-by-row correction sufficient?

External workflow research gives evidence in both directions.

## Incremental reconciliation is a real workflow

Bank reconciliation systems permit one physical bank movement to be matched
incrementally against several semantic obligations.

Odoo 19 bank reconciliation explicitly permits:

- selecting one or multiple counterpart items for one bank transaction;
- leaving a remaining amount open for later reconciliation;
- partial matching where one side is fully reconciled while the other side
  retains an outstanding remainder.

So a frontier such as:

    A = 600
    B = 300
    physical Effect = 1000

is not inherently malformed. It can mean that 900 has been attributed and 100
remains open.

This is direct workflow evidence against a universal atomic correction group.

## Complete allocation publication is also a real workflow

Other systems make a stronger publication promise.

FIX AllocationInstruction supports New / Cancel / Replace. A Replace references
the prior allocation instruction and the replacement message carries the full
replacement allocation data. The semantic publication unit is therefore the
allocation instruction, not merely one changed account row.

QuickBooks Online also exposes a familiar household/business analogue when a
bank transaction is split across categories: the user supplies all split amounts
until the remaining Difference is zero, then publishes the split.

Those workflows do not prove that every settlement correction is atomic. They
show a different semantic authority:

    complete allocation snapshot

That authority is stronger than:

    independent settlement correspondence rows

The clean boundary is therefore not a universal CorrectionGroup. It is an
optional publication/completeness promise when the source workflow itself says
that one allocation set is complete.

This observation encodes only that distinction. It introduces no production
settlement family, group persistence, or batch mutation.
-/

structure AllocationRow where
  quantity : Nat
deriving Repr, DecidableEq

private def physicalQuantity : Nat := 1000

private def attributedTotal (rows : List AllocationRow) : Nat :=
  rows.foldl (fun total row => total + row.quantity) 0

/--
The weak settlement/reconciliation law from Observations 361-362.

Rows must be positive and may not collectively consume more than the physical
movement. Under-attribution is allowed because it represents an open remainder.
-/
private def incrementallyAdmissible (rows : List AllocationRow) : Bool :=
  rows.all (fun row => row.quantity > 0) &&
  attributedTotal rows <= physicalQuantity

/--
A stronger authority used only when a workflow publishes a complete allocation
snapshot for this physical movement.
-/
private def completeAllocationPublication (rows : List AllocationRow) : Bool :=
  incrementallyAdmissible rows &&
  attributedTotal rows = physicalQuantity

private def original : List AllocationRow := [
  ⟨700⟩,
  ⟨300⟩
]

private def halfCorrected : List AllocationRow := [
  ⟨600⟩,
  ⟨300⟩
]

private def corrected : List AllocationRow := [
  ⟨600⟩,
  ⟨400⟩
]

/-!
## Pressure 1 — the 900 intermediate is legitimate under incremental semantics
-/

theorem half_correction_can_represent_open_remainder :
    incrementallyAdmissible halfCorrected = true ∧
    attributedTotal halfCorrected = 900 := by
  native_decide

/-!
## Pressure 2 — the same 900 intermediate is not a complete publication
-/

theorem half_correction_is_not_a_complete_allocation_publication :
    completeAllocationPublication halfCorrected = false := by
  native_decide

/-!
## Pressure 3 — old and corrected complete allocations both satisfy the stronger authority
-/

theorem complete_snapshots_distinguish_old_and_corrected_publications :
    completeAllocationPublication original = true ∧
    completeAllocationPublication corrected = true ∧
    original ≠ corrected := by
  native_decide

/-!
## Finding

Real workflow evidence does not earn a universal atomic settlement correction
group.

It instead separates two authorities.

### Authority A — incremental correspondence frontier

This is appropriate for bank reconciliation, household reimbursement matching,
and other workflows where a physical movement may remain partly unattributed:

    sum(current correspondence quantities)
      <= physical Effect magnitude

A partial current frontier is meaningful. Observation 362's 600/300 state is
therefore not, by itself, a semantic failure.

### Authority B — complete allocation publication

Some workflows publish an allocation set as one complete semantic statement.
FIX allocation replacement is the strongest observed example: replacement
refers to the prior instruction and republishes the complete replacement
allocation data. Split-transaction UIs also commonly enforce zero remainder at
publication.

For that stronger promise the law becomes:

    sum(member quantities)
      = physical Effect magnitude

for the selected physical allocation boundary.

The important design point is that this equality is not a settlement arithmetic
law. It is a publication/completeness assertion supplied by a workflow.

Therefore:

    ReplacementFrontier
      remains the row-version / supersession mechanism

    SettlementEffectCorrespondence
      remains independently meaningful

    universal CorrectionGroup
      is not earned

    optional complete-allocation publication boundary
      has real external precedent, but should be introduced only when LOAM
      promises a workflow that needs it

This also keeps the reconciliation-group mechanics introduced around
CurrentQuantityAnchor semantically separate. Similar grouping mechanics may be
shareable later, but their authority is not automatically settlement authority.

## Current decision

For the present settlement family, stop at row-wise correction plus exact
correspondence quantity and version identity.

Do not add an atomic multi-row correction primitive yet.

If a future LOAM workflow explicitly imports or creates a complete allocation
snapshot, model that completeness as its own semantic publication boundary
rather than broadening SettlementEffectCorrespondence or ReplacementFrontier.

This preserves:

    share mechanics
    preserve semantic authority
    promote only after repeated independent pressure

and avoids making institutional block-allocation semantics a universal rule for
ordinary household reconciliation.
-/

end Loam.Observation363
