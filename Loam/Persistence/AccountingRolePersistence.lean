import Loam.Core.AccountingRole
import Loam.Persistence
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# AccountingRole persistence

The current production boundary is one explicit partial
`LocusId -> lone AccountingRole` relation. Reads fail closed. Physical writes
encode one complete admitted map and replace the configured image through the
shared sibling-stage primitive.

Semantic permission to add an assignment does not live here. In particular,
this module does not decide whether a Locus is new, unused, reclassifiable, or
eligible for mutation. Those admission rules belong to the publisher.
-/

private def accountingRoleMapHeader : String := "LOAM-ACCOUNTING-ROLE-MAP\t1"

private def roleFromToken? : String → Option AccountingRole
  | "ASSET" => some .asset
  | "LIABILITY" => some .liability
  | "EQUITY" => some .equity
  | "INCOME" => some .income
  | "EXPENSE" => some .expense
  | _ => none

private def roleToken : AccountingRole → String
  | .asset => "ASSET"
  | .liability => "LIABILITY"
  | .equity => "EQUITY"
  | .income => "INCOME"
  | .expense => "EXPENSE"

private def decodeAccountingRoleRow?
    (row : String) : Option AccountingRoleAssignment :=
  match row.splitOn "\t" with
  | ["ROLE", locusToken, roleText] => do
      if !validToken locusToken then none else
      let role ← roleFromToken? roleText
      some { locus := ⟨locusToken⟩, role := role }
  | _ => none

private def encodeAccountingRoleRow?
    (assignment : AccountingRoleAssignment) : Option String := do
  if !validToken assignment.locus.token then none else
  pure ("ROLE\t" ++ assignment.locus.token ++ "\t" ++ roleToken assignment.role)

/--
Decode one explicit version-1 partial AccountingRole relation. Missing Loci stay
unresolved; malformed rows, unknown role tokens, and duplicate Locus assignments
fail closed.
-/
def decodeAccountingRoleMap? (input : String) : Option AccountingRoleMap := do
  let rows ← decodeVersionedRows? accountingRoleMapHeader input
  let assignments ← rows.mapM decodeAccountingRoleRow?
  AccountingRoleMap.ofAssignments? assignments

/-- Encode one already-admitted complete partial AccountingRole relation. -/
def encodeAccountingRoleMap? (roles : AccountingRoleMap) : Option String := do
  let rows ← roles.assignments.mapM encodeAccountingRoleRow?
  pure (encodeVersionedRows accountingRoleMapHeader rows)

/-- Publish one complete AccountingRole image through the shared sibling stage. -/
def saveAccountingRoleMap?
    (path : System.FilePath) (roles : AccountingRoleMap) : IO Bool := do
  match encodeAccountingRoleMap? roles with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read and fail-closed decode one configured AccountingRole authority. -/
def loadAccountingRoleMap?
    (path : System.FilePath) : IO (Option AccountingRoleMap) := do
  let input ← IO.FS.readFile path
  return decodeAccountingRoleMap? input

end Loam.Persistence
