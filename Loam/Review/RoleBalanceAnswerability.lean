import Loam.Review.RoleBalanceReview

namespace Loam.RoleBalanceAnswerability

open Loam.Core

set_option autoImplicit false

/-!
# Shared RoleBalance answerability

This module extracts the evidence-frontier classification previously embedded in
the TUI Balance presentation. It does not load household authority, calculate
balances, infer AccountingRole, or prescribe repair.

Human and machine-facing surfaces can therefore explain the same
`RoleBalanceReview.Snapshot` without reimplementing the blocker rules.
-/

/-- A current coordinate whose AccountingRole remains unresolved. -/
structure RoleGap where
  coordinate : EffectCoordinate
  quantity : Option Quantity
  deriving Repr, DecidableEq

/-- Balance-Sheet role domain used by the existing presentation. -/
def isBalanceSheetRole : AccountingRole → Bool
  | .asset => true
  | .liability => true
  | .equity => true
  | .income => false
  | .expense => false

/-- Net-Worth role domain used by the existing presentation. -/
def isNetWorthRole : AccountingRole → Bool
  | .asset => true
  | .liability => true
  | .equity => false
  | .income => false
  | .expense => false

/-- Flow roles do not block stock-report answerability. -/
def isFlowRole : AccountingRole → Bool
  | .income => true
  | .expense => true
  | _ => false

/-- Every coordinate whose AccountingRole is unresolved. -/
def roleGaps (snapshot : Loam.RoleBalanceReview.Snapshot) : List RoleGap :=
  snapshot.unresolvedRoles.map (fun row =>
    { coordinate := row.coordinate, quantity := some row.quantity }) ++
  snapshot.knownPresentBalances.filterMap (fun row =>
    match row.role with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := none }) ++
  snapshot.unsupportedBalances.filterMap fun row =>
    match row.role with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := none }

def quantitySupportedCount (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  snapshot.rows.length + snapshot.unresolvedRoles.length

def totalCoordinateCount (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  quantitySupportedCount snapshot +
    snapshot.knownPresentBalances.length +
    snapshot.unsupportedBalances.length

private def classifiedUnsupportedCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  (snapshot.unsupportedBalances.filter fun row => row.role.isSome).length

private def classifiedKnownPresentCount
    (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  (snapshot.knownPresentBalances.filter fun row => row.role.isSome).length

def roleClassifiedCount (snapshot : Loam.RoleBalanceReview.Snapshot) : Nat :=
  snapshot.rows.length +
    classifiedKnownPresentCount snapshot +
    classifiedUnsupportedCount snapshot

def balanceSheetKnownPresent
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    match row.role with
    | some role => isBalanceSheetRole role
    | none => false

def netWorthKnownPresent
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.KnownPresentBalance :=
  snapshot.knownPresentBalances.filter fun row =>
    match row.role with
    | some role => isNetWorthRole role
    | none => false

def balanceSheetUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isBalanceSheetRole role
    | none => false

def netWorthUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isNetWorthRole role
    | none => false

def flowUnsupported
    (snapshot : Loam.RoleBalanceReview.Snapshot) :
    List Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.filter fun row =>
    match row.role with
    | some role => isFlowRole role
    | none => false

/--
One surface-neutral explanation of why stock reports are answerable or blocked.
The detailed lists remain present so renderers can name exact evidence targets
instead of asking a human or AI to infer them from counts.
-/
structure Summary where
  totalCoordinates : Nat
  exactCurrentQuantitySupport : Nat
  accountingRoleCoverage : Nat
  balanceSheetAmountUnknown :
    List Loam.RoleBalanceReview.KnownPresentBalance
  balanceSheetUnsupported :
    List Loam.RoleBalanceReview.UnsupportedBalance
  netWorthAmountUnknown :
    List Loam.RoleBalanceReview.KnownPresentBalance
  netWorthUnsupported :
    List Loam.RoleBalanceReview.UnsupportedBalance
  roleBlockers : List RoleGap
  flowRoleQuantityGaps :
    List Loam.RoleBalanceReview.UnsupportedBalance
  deriving Repr, DecidableEq

def Summary.balanceSheetAnswerable (summary : Summary) : Bool :=
  summary.balanceSheetAmountUnknown.isEmpty &&
    summary.balanceSheetUnsupported.isEmpty &&
    summary.roleBlockers.isEmpty

def Summary.netWorthAnswerable (summary : Summary) : Bool :=
  summary.netWorthAmountUnknown.isEmpty &&
    summary.netWorthUnsupported.isEmpty &&
    summary.roleBlockers.isEmpty

/-- Derive the shared explanation from one already-qualified RoleBalance answer. -/
def summarize (snapshot : Loam.RoleBalanceReview.Snapshot) : Summary :=
  {
    totalCoordinates := totalCoordinateCount snapshot
    exactCurrentQuantitySupport := quantitySupportedCount snapshot
    accountingRoleCoverage := roleClassifiedCount snapshot
    balanceSheetAmountUnknown := balanceSheetKnownPresent snapshot
    balanceSheetUnsupported := balanceSheetUnsupported snapshot
    netWorthAmountUnknown := netWorthKnownPresent snapshot
    netWorthUnsupported := netWorthUnsupported snapshot
    roleBlockers := roleGaps snapshot
    flowRoleQuantityGaps := flowUnsupported snapshot
  }

end Loam.RoleBalanceAnswerability
