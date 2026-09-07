import Loam.Core.Effect

namespace Loam.Core

set_option autoImplicit false

/-!
# Accounting role classification

Observations 049, 214, 216, and 217, followed by the September 2026 household
quantity audit, established a small current production boundary:

```text
LocusId -> lone AccountingRole
```

The relation is partial. Absence of an assignment means only that this boundary
cannot currently justify an accounting role for that Locus. It is not an
`UnknownRole` value, zero quantity, irrelevance, or missing evidence.

The five constructors below are the currently earned report vocabulary for the
household accounting projection. They are not claimed to be a permanent or
metaphysically exhaustive taxonomy; LOAM may replace them if later household
pressure earns a better vocabulary.
-/

/-- Current explicit accounting-role vocabulary used by qualified household reports. -/
inductive AccountingRole where
  | asset
  | liability
  | equity
  | income
  | expense
deriving Repr, DecidableEq

/-- One explicit role assertion for one Locus identity. -/
structure AccountingRoleAssignment where
  locus : LocusId
  role : AccountingRole
deriving Repr, DecidableEq

/--
A finite partial `LocusId -> AccountingRole` relation.

Each Locus may occur at most once. Loci absent from `assignments` remain
unresolved at this classification boundary; no default role is inferred from
spelling, prefix, sign, Purpose, or presentation state.
-/
structure AccountingRoleMap where
  assignments : List AccountingRoleAssignment
  locusNodup : (assignments.map (fun assignment => assignment.locus)).Nodup

namespace AccountingRoleMap

/-- Admit explicit role assertions only when each Locus has at most one role. -/
def ofAssignments? (assignments : List AccountingRoleAssignment) : Option AccountingRoleMap :=
  if h : (assignments.map (fun assignment => assignment.locus)).Nodup then
    some { assignments := assignments, locusNodup := h }
  else
    none

/-- Empty classification evidence leaves every Locus unresolved. -/
def empty : AccountingRoleMap :=
  { assignments := [], locusNodup := by simp }

/--
Look up only an explicit role assertion. `none` is unresolved classification
evidence at this boundary, not a semantic role value.
-/
def roleOf? (roles : AccountingRoleMap) (locus : LocusId) : Option AccountingRole :=
  (roles.assignments.find? fun assignment => decide (assignment.locus = locus)).map
    (fun assignment => assignment.role)

@[simp] theorem roleOf?_empty (locus : LocusId) :
    empty.roleOf? locus = none := by
  rfl

end AccountingRoleMap

end Loam.Core
