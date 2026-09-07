import Loam.Core.AccountingRole
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# AccountingRole persistence

This stream persists exactly the current explicit partial relation:

```text
LocusId -> lone AccountingRole
```

Missing rows remain missing classification evidence. The decoder does not infer
roles from Locus spelling, colon prefixes, Effect sign, Purpose, or any other
household evidence, and there is deliberately no persisted `UnknownRole` token.

Row order is representation only. `AccountingRoleMap.ofAssignments?` rejects a
second row for the same Locus, so serialization order cannot become a winner or
priority rule.
-/

/-- Version marker for the first explicit partial AccountingRole map. -/
def accountingRoleMapHeader : String := "LOAM-ACCOUNTING-ROLE-MAP\t1"

private def roleToken : AccountingRole → String
  | .asset => "ASSET"
  | .liability => "LIABILITY"
  | .equity => "EQUITY"
  | .income => "INCOME"
  | .expense => "EXPENSE"

private def roleFromToken? : String → Option AccountingRole
  | "ASSET" => some .asset
  | "LIABILITY" => some .liability
  | "EQUITY" => some .equity
  | "INCOME" => some .income
  | "EXPENSE" => some .expense
  | _ => none

private def encodeAccountingRoleRow?
    (assignment : AccountingRoleAssignment) : Option String :=
  if validToken assignment.locus.token then
    some ("ROLE\t" ++ assignment.locus.token ++ "\t" ++ roleToken assignment.role)
  else
    none

private def decodeAccountingRoleRow?
    (row : String) : Option AccountingRoleAssignment :=
  match row.splitOn "\t" with
  | ["ROLE", locusToken, roleText] => do
      if !validToken locusToken then none else
      let role ← roleFromToken? roleText
      some { locus := ⟨locusToken⟩, role := role }
  | _ => none

/-- Encode only explicit role assertions; absent Loci produce no synthetic row. -/
def encodeAccountingRoleMap? (roles : AccountingRoleMap) : Option String := do
  let rows ← roles.assignments.mapM encodeAccountingRoleRow?
  return String.intercalate "\n" (accountingRoleMapHeader :: rows) ++ "\n"

/--
Decode one version-1 partial relation. Unknown role tokens, malformed rows, and
duplicate Locus assignments fail closed.
-/
def decodeAccountingRoleMap? (input : String) : Option AccountingRoleMap :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != accountingRoleMapHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => do
            let assignments ← reversedRows.reverse.mapM decodeAccountingRoleRow?
            AccountingRoleMap.ofAssignments? assignments
        | _ => none
  | _ => none

private def accountingRoleMapStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one complete AccountingRole relation by sibling staging plus rename. -/
def saveAccountingRoleMap?
    (path : System.FilePath) (roles : AccountingRoleMap) : IO Bool := do
  match encodeAccountingRoleMap? roles with
  | none => return false
  | some text =>
      let stagePath := accountingRoleMapStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one explicit AccountingRole relation. -/
def loadAccountingRoleMap?
    (path : System.FilePath) : IO (Option AccountingRoleMap) := do
  let input ← IO.FS.readFile path
  return decodeAccountingRoleMap? input

end Loam.Persistence
