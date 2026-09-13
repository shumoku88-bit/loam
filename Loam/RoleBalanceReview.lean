import Loam.Application.CorrectionFrontier
import Loam.Application.QuantityInspection
import Loam.BalanceReview
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.OpeningSupportPersistence

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
- coordinates with explicit zero-origin coverage;
- coordinates with explicit opening-Event support.

Zero-origin coordinates continue to delegate to `BalanceReview.project`.
Opening-supported coordinates delegate to the same production `inspectQuantity`
arithmetic only after the retained opening Event survives on the current
correction frontier and contains the supported coordinate. Coordinates carrying
neither evidence family remain visible as an unsupported frontier.

`ZeroOriginCoverage` stays semantically stronger: this module does not make
opening support available to `BalanceReview` or `StockFlowReview` and therefore
does not grant historical reconstruction before the opening witness.

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

/-- One coordinate whose current quantity support is absent. -/
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
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap) : List EffectCoordinate :=
  normalizeCoordinates
    (eventCoordinates frontier ++ coverage.coordinates ++ openingSupport.coordinates)

private def eventContainsCoordinate
    (event : Event) (coordinate : EffectCoordinate) : Bool :=
  event.effects.any fun effect => decide (effect.coordinate = coordinate)

private def validateOpeningSupport
    (frontier : EventMemory) (support : OpeningSupport) : Except String Unit :=
  match frontier.findById? support.openingEvent with
  | none =>
      .error
        ("loam: role balances unavailable: opening support for " ++
          support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token ++
          " does not reference one current Event")
  | some event =>
      if eventContainsCoordinate event support.coordinate then
        .ok ()
      else
        .error
          ("loam: role balances unavailable: opening Event " ++
            support.openingEvent.token ++ " does not contain " ++
            support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token)

private def validateOpeningSupports
    (frontier : EventMemory) (supportMap : OpeningSupportMap) : Except String Unit := do
  for support in supportMap.supports do
    validateOpeningSupport frontier support

private def hasOpeningSupport
    (supportMap : OpeningSupportMap) (coordinate : EffectCoordinate) : Bool :=
  (supportMap.supportFor? coordinate).isSome

private def inspectCurrentQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : Except String Quantity :=
  match Loam.Application.inspectQuantity
      events corrections coordinate.locus coordinate.measure with
  | .recorded quantity => .ok quantity
  | .frontierEffective quantity => .ok quantity
  | .missingCorrectionEndpoint =>
      .error "loam: role balances unavailable: correction references are not closed"
  | .frontierRequired =>
      .error "loam: role balances unavailable: event corrections do not justify one frontier"

private def openingBalanceRows
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (coordinates : List EffectCoordinate) : Except String (List Loam.BalanceReview.Row) := do
  coordinates.mapM fun coordinate => do
    let quantity ← inspectCurrentQuantity events corrections coordinate
    return { coordinate := coordinate, quantity := quantity }

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
Compose the current correction frontier, independent zero-origin and opening
support evidence, and the existing quantity answer with explicit AccountingRole
evidence.
-/
def project
    (evidence : Loam.BalanceReview.Evidence)
    (openingSupport : OpeningSupportMap)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let frontier ←
    match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
    | some frontier => pure frontier
    | none => throw "loam: role balances unavailable: event corrections do not justify one frontier"

  validateOpeningSupports frontier openingSupport

  let candidates := candidateCoordinates frontier evidence.coverage openingSupport
  let zeroSupported := candidates.filter fun coordinate => evidence.coverage.covers coordinate
  let openingSupported := candidates.filter fun coordinate =>
    !evidence.coverage.covers coordinate && hasOpeningSupport openingSupport coordinate
  let unsupported := candidates.filter fun coordinate =>
    !evidence.coverage.covers coordinate && !hasOpeningSupport openingSupport coordinate

  let zeroBalances ← Loam.BalanceReview.project
    evidence.events evidence.corrections evidence.coverage zeroSupported
  let openingRows ← openingBalanceRows evidence.events evidence.corrections openingSupported
  let balances : Loam.BalanceReview.Snapshot :=
    { rows := zeroBalances.rows ++ openingRows }

  return {
    rows := classifiedRows balances roles
    unresolvedRoles := unresolvedSupported balances roles ++ unresolvedUnsupported unsupported roles
    unsupportedBalances := unsupportedRows unsupported roles
  }

private def loadOpeningSupport
    (path : System.FilePath) : IO (Except String OpeningSupportMap) := do
  if ← path.pathExists then
    match ← loadOpeningSupportMap? path with
    | some supportMap => return .ok supportMap
    | none => return .error "loam: malformed or unsupported opening support evidence"
  else
    return .ok OpeningSupportMap.empty

/--
Load existing production balance evidence, optional explicit opening support and
explicit AccountingRole evidence, then compose them. No presentation selection
such as `balance-view.tsv` is used.
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
  let openingSupport ←
    match ← loadOpeningSupport (dataDir / "opening-support.loam") with
    | .error message => return .error message
    | .ok supportMap => pure supportMap
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  return project evidence openingSupport roles

end Loam.RoleBalanceReview
