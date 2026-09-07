import Loam.Persistence.AccountingRolePersistence

open Loam.Core
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def smbc : LocusId := ⟨"smbc"⟩
private def rent : LocusId := ⟨"expenses:家賃"⟩
private def reserve : LocusId := ⟨"expenses:予備"⟩
private def misleadingName : LocusId := ⟨"opaque-expense-looking"⟩

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := smbc, role := .asset },
       { locus := rent, role := .expense },
       { locus := misleadingName, role := .asset }])
    "explicit AccountingRole fixture was not admitted"

  expect (roles.roleOf? smbc == some .asset)
    "explicit AssetRole assignment was not recovered"
  expect (roles.roleOf? rent == some .expense)
    "explicit ExpenseRole assignment was not recovered"
  expect (roles.roleOf? reserve == none)
    "missing AccountingRole stopped being unresolved"
  expect (roles.roleOf? misleadingName == some .asset)
    "Locus spelling overrode explicit AccountingRole evidence"

  let encoded ← requireSome
    (encodeAccountingRoleMap? roles)
    "AccountingRole fixture could not be encoded"
  let decoded ← requireSome
    (decodeAccountingRoleMap? encoded)
    "encoded AccountingRole fixture did not decode"
  let reencoded ← requireSome
    (encodeAccountingRoleMap? decoded)
    "decoded AccountingRole fixture could not be re-encoded"
  expect (encoded == reencoded)
    "AccountingRole decode/encode changed retained bytes"
  expect (decoded.roleOf? reserve == none)
    "persistence invented a role for an absent Locus"

  let permuted ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := misleadingName, role := .asset },
       { locus := rent, role := .expense },
       { locus := smbc, role := .asset }])
    "permuted AccountingRole fixture was not admitted"
  expect (permuted.roleOf? smbc == roles.roleOf? smbc)
    "row order changed AssetRole lookup"
  expect (permuted.roleOf? rent == roles.roleOf? rent)
    "row order changed ExpenseRole lookup"
  expect (permuted.roleOf? reserve == roles.roleOf? reserve)
    "row order changed unresolved classification"

  expect
    ((AccountingRoleMap.ofAssignments?
      [{ locus := smbc, role := .asset },
       { locus := smbc, role := .expense }]).isNone)
    "two AccountingRoles for one Locus were admitted"

  let unknownRole :=
    "LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
    "ROLE\tsmbc\tUNKNOWN\n"
  expect ((decodeAccountingRoleMap? unknownRole).isNone)
    "persistence admitted an UnknownRole token"

  let duplicateRole :=
    "LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
    "ROLE\tsmbc\tASSET\n" ++
    "ROLE\tsmbc\tEXPENSE\n"
  expect ((decodeAccountingRoleMap? duplicateRole).isNone)
    "persistence used row order to resolve duplicate Locus roles"

  let prefixOnly :=
    "LOAM-ACCOUNTING-ROLE-MAP\t1\n"
  let emptyRoles ← requireSome
    (decodeAccountingRoleMap? prefixOnly)
    "empty AccountingRole map did not decode"
  expect (emptyRoles.roleOf? rent == none)
    "expenses: prefix silently became ExpenseRole"

  IO.println "Partial AccountingRole persistence practical story succeeded."
