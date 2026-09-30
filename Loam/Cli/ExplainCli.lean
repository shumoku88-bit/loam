import Loam.Review.RoleBalanceAnswerability
import Loam.Review.RoleBalanceReview
import Loam.Persistence.TokenSyntax

namespace Loam.ExplainCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage:\n" ++
  "  loam explain balances [LOAM_DATA_DIR]\n" ++
  "  loam explain balances --machine [LOAM_DATA_DIR]\n\n" ++
  "The explanation is read-only and derived from the shared RoleBalance answer.\n" ++
  "Machine output is EXPLAIN1 tab-separated framing and ends with status=complete."

private def resolveDataDir (args : List String) :
    IO (Except String (System.FilePath × Bool)) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path, false)
      | none => return .ok (System.FilePath.mk "../loam-data", false)
  | ["--machine"] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path, true)
      | none => return .ok (System.FilePath.mk "../loam-data", true)
  | [path] =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path, false)
  | ["--machine", path] =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path, true)
  | _ => return .error usage

private def roleText : AccountingRole → String
  | .asset => "ASSET"
  | .liability => "LIABILITY"
  | .equity => "EQUITY"
  | .income => "INCOME"
  | .expense => "EXPENSE"

private def statusText (answerable : Bool) : String :=
  if answerable then "ANSWERABLE" else "BLOCKED"

private def coordinateText (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

private def roleGapText
    (gap : Loam.RoleBalanceAnswerability.RoleGap) : String :=
  let quantityState :=
    match gap.quantity with
    | some quantity => "quantity known: " ++ toString quantity.quanta
    | none => "quantity also unsupported"
  coordinateText gap.coordinate ++ "  " ++ quantityState

def plainText
    (summary : Loam.RoleBalanceAnswerability.Summary) : String :=
  let stockTargets :=
    (summary.balanceSheetAmountUnknown.map fun row =>
      "  [amount] " ++ coordinateText row.coordinate ++
        "  " ++ (row.role.map roleText |>.getD "UNRESOLVED")) ++
    (summary.balanceSheetUnsupported.map fun row =>
      "  [quantity] " ++ coordinateText row.coordinate ++
        "  " ++ (row.role.map roleText |>.getD "UNRESOLVED")) ++
    (summary.roleBlockers.map fun gap =>
      "  [role] " ++ roleGapText gap)
  String.intercalate "\n" <|
    [ "LOAM Explain / Balances"
    , "Read-only explanation derived from the shared RoleBalance answer."
    , ""
    , "Exact current quantity support: " ++
        toString summary.exactCurrentQuantitySupport ++ " / " ++
        toString summary.totalCoordinates
    , "AccountingRole coverage: " ++
        toString summary.accountingRoleCoverage ++ " / " ++
        toString summary.totalCoordinates
    , "Balance Sheet: " ++ statusText summary.balanceSheetAnswerable ++
        "  (" ++ toString summary.balanceSheetAmountUnknown.length ++
        " amount-unknown, " ++ toString summary.balanceSheetUnsupported.length ++
        " unsupported stock-role, " ++ toString summary.roleBlockers.length ++
        " role blockers)"
    , "Net Worth: " ++ statusText summary.netWorthAnswerable ++
        "  (" ++ toString summary.netWorthAmountUnknown.length ++
        " amount-unknown, " ++ toString summary.netWorthUnsupported.length ++
        " unsupported stock-role, " ++ toString summary.roleBlockers.length ++
        " role blockers)"
    , "Flow-role quantity gaps: " ++ toString summary.flowRoleQuantityGaps.length ++
        "  (Income / Expense; do not block Balance Sheet or Net Worth)"
    , ""
    , "Next evidence targets for Balance Sheet / Net Worth:"
    ] ++
    (if stockTargets.isEmpty then ["  (none)"] else stockTargets)

private def machineRecord (fields : List String) : String :=
  String.intercalate "\t" ("EXPLAIN1" :: fields)

private def blockerRole (role : Option AccountingRole) : String :=
  role.map roleText |>.getD "UNRESOLVED"

def machineText
    (summary : Loam.RoleBalanceAnswerability.Summary) : String :=
  let base := [
    machineRecord ["meta", "schema", "1"],
    machineRecord ["meta", "implementation", "loam"],
    machineRecord ["meta", "question", "balances"],
    machineRecord ["status", "balance-sheet", statusText summary.balanceSheetAnswerable],
    machineRecord ["status", "net-worth", statusText summary.netWorthAnswerable],
    machineRecord ["scalar", "total_coordinates", "count", toString summary.totalCoordinates],
    machineRecord ["scalar", "exact_current_quantity_support", "count",
      toString summary.exactCurrentQuantitySupport],
    machineRecord ["scalar", "accounting_role_coverage", "count",
      toString summary.accountingRoleCoverage],
    machineRecord ["scalar", "flow_role_quantity_gaps", "count",
      toString summary.flowRoleQuantityGaps.length]
  ]
  let stockAmount := summary.balanceSheetAmountUnknown.map fun row =>
    machineRecord ["blocker", "balance-sheet", "amount-unknown",
      row.coordinate.locus.token, row.coordinate.measure.token, blockerRole row.role]
  let stockUnsupported := summary.balanceSheetUnsupported.map fun row =>
    machineRecord ["blocker", "balance-sheet", "unsupported",
      row.coordinate.locus.token, row.coordinate.measure.token, blockerRole row.role]
  let nwAmount := summary.netWorthAmountUnknown.map fun row =>
    machineRecord ["blocker", "net-worth", "amount-unknown",
      row.coordinate.locus.token, row.coordinate.measure.token, blockerRole row.role]
  let nwUnsupported := summary.netWorthUnsupported.map fun row =>
    machineRecord ["blocker", "net-worth", "unsupported",
      row.coordinate.locus.token, row.coordinate.measure.token, blockerRole row.role]
  let roleRows := summary.roleBlockers.map fun gap =>
    machineRecord ["blocker", "balance-sheet+net-worth", "role-unresolved",
      gap.coordinate.locus.token, gap.coordinate.measure.token,
      if gap.quantity.isSome then "quantity-known" else "quantity-unsupported"]
  let flowRows := summary.flowRoleQuantityGaps.map fun row =>
    machineRecord ["gap", "flow-role-quantity", row.coordinate.locus.token,
      row.coordinate.measure.token, blockerRole row.role, "nonblocking-stock"]
  String.intercalate "\n" <|
    base ++ stockAmount ++ stockUnsupported ++ nwAmount ++ nwUnsupported ++
      roleRows ++ flowRows ++ [machineRecord ["meta", "status", "complete"]]

/-- Explain current balance answerability from the shared production read. -/
def run (args : List String) : IO UInt32 := do
  let (dataDir, machineMode) ←
    match ← resolveDataDir args with
    | .ok resolved => pure resolved
    | .error message =>
        IO.eprintln message
        return 2
  let snapshot ←
    match ← Loam.RoleBalanceReview.loadSnapshot dataDir dataDir with
    | .ok snapshot => pure snapshot
    | .error message =>
        IO.eprintln message
        return 2
  let summary := Loam.RoleBalanceAnswerability.summarize snapshot
  IO.println (if machineMode then machineText summary else plainText summary)
  return 0

end Loam.ExplainCli
