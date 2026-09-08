import Loam.Core.AccountingRole
import Loam.Persistence
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# AccountingRole read persistence

The compression audit retired the previous adapter while no production caller
needed this evidence. Current Capacity coverage now has one concrete read need
for the already-canonical partial `LocusId -> lone AccountingRole` relation.

This module therefore re-admits only the read boundary. It does not restore an
AccountingRole writer, staging protocol, or synthetic default role.
-/

private def accountingRoleMapHeader : String := "LOAM-ACCOUNTING-ROLE-MAP\t1"

private def roleFromToken? : String → Option AccountingRole
  | "ASSET" => some .asset
  | "LIABILITY" => some .liability
  | "EQUITY" => some .equity
  | "INCOME" => some .income
  | "EXPENSE" => some .expense
  | _ => none

private def decodeAccountingRoleRow?
    (row : String) : Option AccountingRoleAssignment :=
  match row.splitOn "\t" with
  | ["ROLE", locusToken, roleText] => do
      if !validToken locusToken then none else
      let role ← roleFromToken? roleText
      some { locus := ⟨locusToken⟩, role := role }
  | _ => none

/--
Decode one explicit version-1 partial AccountingRole relation. Missing Loci stay
unresolved; malformed rows, unknown role tokens, and duplicate Locus assignments
fail closed.
-/
def decodeAccountingRoleMap? (input : String) : Option AccountingRoleMap := do
  let rows ← decodeVersionedRows? accountingRoleMapHeader input
  let assignments ← rows.mapM decodeAccountingRoleRow?
  AccountingRoleMap.ofAssignments? assignments

/-- Read and fail-closed decode one configured AccountingRole authority. -/
def loadAccountingRoleMap?
    (path : System.FilePath) : IO (Option AccountingRoleMap) := do
  let input ← IO.FS.readFile path
  return decodeAccountingRoleMap? input

end Loam.Persistence
