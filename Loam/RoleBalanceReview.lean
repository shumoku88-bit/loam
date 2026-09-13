import Loam.Application.CorrectionFrontier
import Loam.BalanceReview
import Loam.Persistence.AccountingRolePersistence

namespace Loam.RoleBalanceReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Role-aware current balance projection basis

This boundary composes existing current balance evidence with explicit
AccountingRole evidence. It does not add a second quantity engine and it does
not infer completeness from Event activity or role assignment.

The coordinate universe is the union of:

- coordinates on the current correction frontier;
- coordinates with explicit zero-origin coverage.

Covered coordinates are delegated to `BalanceReview.project`. Uncovered
coordinates remain visible as an unsupported frontier instead of causing them
to disappear or acquire an implicit zero balance.

This is a current-balance basis only. Historical as-of reconstruction, period
closing, retained earnings, valuation and recognition policy remain outside this
boundary.
-/

/-- One classified coordinate with a justified current quantity. -/
structure Row where
  coordinate : EffectCoordinate
  role : AccountingRole
  quantity : Quantity
  deriving Repr, DecidableEq

/--
A coordinate whose current quantity is supported but whose AccountingRole is
unresolved, or whose quantity is itself unsupported and therefore absent.
-/
structure UnresolvedRole where
  coordinate : EffectCoordinate
  quantity : Option Quantity
  deriving Repr, DecidableEq

/-- One coordinate whose zero-origin quantity support is absent. -/
structure UnsupportedBalance where
  coordinate : EffectCoordinate
  role : Option AccountingRole
  deriving Repr, DecidableEq

/-- Shared role-aware current balance answer. -/
structure Snapshot where
  rows : List Row
  unresolvedRoles : List UnresolvedRole
  unsupportedBalances : List UnsupportedBalance
  deriving Repr, DecidableEq

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def normalizeCoordinates
    (coordinates : List EffectCoordinate) : List EffectCoordinate :=
  coordinates.foldl addCoordinateIfAbsent []

private def eventCoordinates (events : EventMemory) : List EffectCoordinate :=
  events.events.flatMap fun event => event.effects.map fun effect => effect.coordinate

private def candidateCoordinates
    (frontier : EventMemory)
    (coverage : ZeroOriginCoverage) : List EffectCoordinate :=
  normalizeCoordinates (eventCoordinates frontier ++ coverage.coordinates)

private def classifiedRows
    (balances : Loam.BalanceReview.Snapshot)
    (roles : AccountingRoleMap) : List Row :=
  balances.rows.filterMap fun row =>
    match roles.roleOf? row.coordinate.locus with
    | none => none
    | some role => some { coordinate := row.coordinate, role := role, quantity := row.quantity }

private def unresolvedSupported
    (balances : Loam.BalanceReview.Snapshot)
    (roles : AccountingRoleMap) : List UnresolvedRole :=
  balances.rows.filterMap fun row =>
    match roles.roleOf? row.coordinate.locus with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := some row.quantity }

private def unsupportedRows
    (coordinates : List EffectCoordinate)
    (roles : AccountingRoleMap) : List UnsupportedBalance :=
  coordinates.map fun coordinate =>
    { coordinate := coordinate, role := roles.roleOf? coordinate.locus }

private def unresolvedUnsupported
    (coordinates : List EffectCoordinate)
    (roles : AccountingRoleMap) : List UnresolvedRole :=
  coordinates.filterMap fun coordinate =>
    match roles.roleOf? coordinate.locus with
    | some _ => none
    | none => some { coordinate := coordinate, quantity := none }

/--
Compose the existing current correction frontier, zero-origin support and
BalanceReview quantity answer with explicit AccountingRole evidence.
-/
def project
    (evidence : Loam.BalanceReview.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let frontier ←
    match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
    | some frontier => pure frontier
    | none => throw "loam: role balances unavailable: event corrections do not justify one frontier"

  let candidates := candidateCoordinates frontier evidence.coverage
  let supported := candidates.filter fun coordinate => evidence.coverage.covers coordinate
  let unsupported := candidates.filter fun coordinate => !evidence.coverage.covers coordinate

  let balances ← Loam.BalanceReview.project
    evidence.events evidence.corrections evidence.coverage supported

  return {
    rows := classifiedRows balances roles
    unresolvedRoles := unresolvedSupported balances roles ++ unresolvedUnsupported unsupported roles
    unsupportedBalances := unsupportedRows unsupported roles
  }

/--
Load existing production balance evidence and explicit AccountingRole evidence,
then compose them. No presentation selection such as `balance-view.tsv` is used.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let rolesPath := dataDir / "accounting-role.loam"
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"

  let evidence ←
    match ← Loam.BalanceReview.loadEvidence dataDir actualRoot with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  return project evidence roles

end Loam.RoleBalanceReview
