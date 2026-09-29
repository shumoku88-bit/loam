import Loam.CurrentBalanceReview
import Loam.HouseholdPaths
import Loam.Persistence.AccountingRolePersistence

namespace Loam.RoleBalanceReview

open Loam.Core
open Loam.Persistence
set_option autoImplicit false

/-!
# Role-aware current balance projection basis

This boundary refines the neutral `CurrentBalanceReview` answer with explicit
AccountingRole evidence. It does not add a second quantity/correction engine and
it does not infer completeness from Event activity or role assignment.

The coordinate universe is the union of:

- coordinates on the current correction frontier;
- coordinates with explicit zero-origin coverage;
- coordinates with explicit opening-Event support;
- coordinates with an explicit current quantity anchor assertion;
- coordinates with explicit current nonzero-presence evidence whose exact amount is unknown.

Zero-origin coordinates continue to delegate to `BalanceReview.project`, which
remains the semantic owner of zero-origin balance projection. Opening-supported
coordinates project from the already-admitted ordinary correction frontier.
Current-anchor coordinates use the shared reflected-root cut qualified by
Observation 246 and add only correction-aware Event roots outside that cut.
Coordinates carrying none of these evidence families remain visible as an
unsupported frontier.

Support families are deliberately non-overlapping at this first boundary.
Choosing precedence between independently justified answers would be new
semantics, so overlap fails closed instead of selecting a winner.

`ZeroOriginCoverage` stays semantically stronger: this module does not make
opening or current-anchor support available to `BalanceReview` or
`StockFlowReview` and therefore does not grant historical reconstruction before
the relevant current-support boundary.

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

/-- One quantity-supported coordinate whose AccountingRole is unresolved. -/
structure UnresolvedRole where
  coordinate : EffectCoordinate
  quantity : Quantity
  deriving Repr, DecidableEq

/-- One coordinate known to be nonzero now while its exact Quantity is unknown. -/
structure KnownPresentBalance where
  coordinate : EffectCoordinate
  role : Option AccountingRole
  deriving Repr, DecidableEq

/-- One coordinate whose current quantity support is absent. -/
structure UnsupportedBalance where
  coordinate : EffectCoordinate
  role : Option AccountingRole
  deriving Repr, DecidableEq

/--
Shared role-aware current balance answer.

The four lists are a disjoint partition of represented coordinates:
classified exact-supported, role-unresolved exact-supported, known-present with
unknown exact amount, and fully quantity-unsupported. A coordinate with neither
quantity nor role support lives only in `unsupportedBalances` with `role = none`;
presentation may project that one record into both quantity and role blocker
views without duplicating the answer.
-/
structure Snapshot where
  rows : List Row
  unresolvedRoles : List UnresolvedRole
  knownPresentBalances : List KnownPresentBalance := []
  unsupportedBalances : List UnsupportedBalance
  deriving Repr, DecidableEq

private def classifiedRows
    (balances : List Loam.BalanceReview.Row)
    (roles : AccountingRoleMap) : List Row :=
  balances.filterMap fun row =>
    match roles.roleOf? row.coordinate.locus with
    | none => none
    | some role => some { coordinate := row.coordinate, role := role, quantity := row.quantity }

private def unresolvedSupported
    (balances : List Loam.BalanceReview.Row)
    (roles : AccountingRoleMap) : List UnresolvedRole :=
  balances.filterMap fun row =>
    match roles.roleOf? row.coordinate.locus with
    | some _ => none
    | none => some { coordinate := row.coordinate, quantity := row.quantity }

private def knownPresentRows
    (coordinates : List EffectCoordinate)
    (roles : AccountingRoleMap) : List KnownPresentBalance :=
  coordinates.map fun coordinate =>
    { coordinate := coordinate, role := roles.roleOf? coordinate.locus }

private def unsupportedRows
    (coordinates : List EffectCoordinate)
    (roles : AccountingRoleMap) : List UnsupportedBalance :=
  coordinates.map fun coordinate =>
    { coordinate := coordinate, role := roles.roleOf? coordinate.locus }

/--
Refine the neutral current-balance answer with explicit AccountingRole evidence.

Quantity support remains owned by `CurrentBalanceReview`; this layer only
classifies that already-justified answer.
-/
private def classifyCurrent
    (current : Loam.CurrentBalanceReview.Snapshot)
    (roles : AccountingRoleMap) : Snapshot :=
  {
    rows := classifiedRows current.rows roles
    unresolvedRoles := unresolvedSupported current.rows roles
    knownPresentBalances := knownPresentRows current.knownPresent roles
    unsupportedBalances := unsupportedRows current.unsupported roles
  }

/--
Compose Role Balance by refining the neutral current-balance projection.

Current quantity support, overlap refusal, correction handling, and present-vs-
unsupported partitioning stay owned by `CurrentBalanceReview`.
-/
def project
    (evidence : Loam.BalanceReview.Evidence)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let current ←
    Loam.CurrentBalanceReview.project
      evidence openingSupport currentAnchor Loam.CurrentQuantityPresence.Evidence.empty
  return classifyCurrent current roles

/-- Raw/in-memory Role Balance composition with explicit current-presence evidence. -/
def projectWithPresence
    (evidence : Loam.BalanceReview.Evidence)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let current ←
    Loam.CurrentBalanceReview.project
      evidence openingSupport currentAnchor currentPresence
  return classifyCurrent current roles

/-- Compose Role Balance from one fully admitted Actual read image. -/
def projectImage
    (image : Loam.ActualAuthority.Image)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let current ←
    Loam.CurrentBalanceReview.projectImage
      image coverage openingSupport currentAnchor Loam.CurrentQuantityPresence.Evidence.empty
  return classifyCurrent current roles

/-- Compose Role Balance with explicit present-but-exact-amount-unknown evidence. -/
def projectImageWithPresence
    (image : Loam.ActualAuthority.Image)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let current ←
    Loam.CurrentBalanceReview.projectImage
      image coverage openingSupport currentAnchor currentPresence
  return classifyCurrent current roles

/--
Load current Role Balance from a caller-supplied admitted Actual image plus the
independent support and AccountingRole authorities.

This is the composed-reader entrance for UI surfaces that already own one Actual
generation. No presentation selection such as `balance-view.tsv` is used.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image) : IO (Except String Snapshot) := do
  let rolesPath := Loam.HouseholdPaths.accountingRole dataDir
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"

  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  let current ←
    match ← Loam.CurrentBalanceReview.loadSnapshotFromActualImage dataDir image with
    | .error message => return .error message
    | .ok snapshot => pure snapshot

  return .ok (classifyCurrent current roles)

/--
Load one admitted production Actual image, independent zero-origin coverage,
optional opening/current support, and explicit AccountingRole evidence, then
compose them. No presentation selection such as `balance-view.tsv` is used.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImage dataDir image

end Loam.RoleBalanceReview
