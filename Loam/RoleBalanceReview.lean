import Loam.Application.CorrectionFrontier
import Loam.BalanceReview
import Loam.CurrentQuantityAnchor
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.OpeningSupportPersistence

namespace Loam.RoleBalanceReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Role-aware current balance projection basis

This boundary composes existing current balance evidence with explicit
AccountingRole evidence. It does not add a second correction engine and it does
not infer completeness from Event activity or role assignment.

The coordinate universe is the union of:

- coordinates on the current correction frontier;
- coordinates with explicit zero-origin coverage;
- coordinates with explicit opening-Event support;
- coordinates with an explicit current quantity anchor assertion.

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

/-- One coordinate whose current quantity support is absent. -/
structure UnsupportedBalance where
  coordinate : EffectCoordinate
  role : Option AccountingRole
  deriving Repr, DecidableEq

/--
Shared role-aware current balance answer.

The three lists are a disjoint partition of represented coordinates:
classified supported, role-unresolved supported, and quantity-unsupported.
A coordinate with neither quantity nor role support lives only in
`unsupportedBalances` with `role = none`; presentation may project that one
record into both quantity and role blocker views without duplicating the answer.
-/
structure Snapshot where
  rows : List Row
  unresolvedRoles : List UnresolvedRole
  unsupportedBalances : List UnsupportedBalance
  deriving Repr, DecidableEq

private def eventCoordinates (events : EventMemory) : List EffectCoordinate :=
  events.events.flatMap fun event => event.effects.map fun effect => effect.coordinate

private def candidateCoordinates
    (frontier : EventMemory)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence) : List EffectCoordinate :=
  (eventCoordinates frontier ++ coverage.coordinates ++ openingSupport.coordinates ++
      currentAnchor.coordinates).eraseDups

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

private def hasCurrentAnchor
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : Bool :=
  (currentAnchor.assertionFor? coordinate).isSome

private inductive SupportRoute where
  | zeroOrigin
  | opening
  | currentAnchor
  | unsupported
  deriving Repr, DecidableEq

/--
The one production decision boundary for current-balance support routing.

`project` calls `validateSupportSeparation` before using this function, so the
branch order is not a precedence policy for conflicting evidence. It is only an
exhaustive representation of the four admitted routing cases.
-/
private def supportRoute
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : SupportRoute :=
  if coverage.covers coordinate then
    .zeroOrigin
  else if hasOpeningSupport openingSupport coordinate then
    .opening
  else if hasCurrentAnchor currentAnchor coordinate then
    .currentAnchor
  else
    .unsupported

/-- DAG leaf Z: zero-origin evidence routes to the zero-origin bucket. -/
private theorem zero_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .zeroOrigin := by
  simp [supportRoute, hzero]

/-- DAG leaf O: absent zero-origin plus opening evidence routes to opening. -/
private theorem opening_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .opening := by
  simp [supportRoute, hzero, hopening]

/-- DAG leaf A: absent earlier support plus an anchor routes to current-anchor. -/
private theorem anchor_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .currentAnchor := by
  simp [supportRoute, hzero, hopening, hanchor]

/-- DAG leaf U: absence of all support routes to the unsupported bucket. -/
private theorem unsupported_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = false) :
    supportRoute coverage openingSupport currentAnchor coordinate = .unsupported := by
  simp [supportRoute, hzero, hopening, hanchor]

/--
DAG root: every coordinate reaches one constructor of the same production route.
Constructor disjointness supplies exclusivity; the root adds no proof-only state.
-/
private theorem support_partition_root
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) :
    supportRoute coverage openingSupport currentAnchor coordinate = .zeroOrigin ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .opening ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .currentAnchor ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .unsupported := by
  cases hzero : coverage.covers coordinate with
  | false =>
      cases hopening : hasOpeningSupport openingSupport coordinate with
      | false =>
          cases hanchor : hasCurrentAnchor currentAnchor coordinate with
          | false =>
              exact Or.inr (Or.inr (Or.inr
                (unsupported_leaf coverage openingSupport currentAnchor coordinate
                  hzero hopening hanchor)))
          | true =>
              exact Or.inr (Or.inr (Or.inl
                (anchor_leaf coverage openingSupport currentAnchor coordinate
                  hzero hopening hanchor)))
      | true =>
          exact Or.inr (Or.inl
            (opening_leaf coverage openingSupport currentAnchor coordinate hzero hopening))
  | true =>
      exact Or.inl (zero_leaf coverage openingSupport currentAnchor coordinate hzero)

private structure SupportBuckets where
  zeroOrigin : List EffectCoordinate := []
  opening : List EffectCoordinate := []
  currentAnchor : List EffectCoordinate := []
  unsupported : List EffectCoordinate := []

/--
Apply the proved production routing decision exactly once per candidate coordinate.
The recursive shape preserves candidate order inside each support family while
making the runtime partition match the one-root/four-leaf obligation DAG.
-/
private def routeCandidates
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence) :
    List EffectCoordinate → SupportBuckets
  | [] => {}
  | coordinate :: rest =>
      let later := routeCandidates coverage openingSupport currentAnchor rest
      match supportRoute coverage openingSupport currentAnchor coordinate with
      | .zeroOrigin => { later with zeroOrigin := coordinate :: later.zeroOrigin }
      | .opening => { later with opening := coordinate :: later.opening }
      | .currentAnchor => { later with currentAnchor := coordinate :: later.currentAnchor }
      | .unsupported => { later with unsupported := coordinate :: later.unsupported }

private def validateSupportSeparation
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence) : Except String Unit := do
  for support in openingSupport.supports do
    if coverage.covers support.coordinate then
      throw
        ("loam: role balances unavailable: opening support overlaps zero-origin support for " ++
          support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token)
  for assertion in currentAnchor.assertions do
    if coverage.covers assertion.coordinate || hasOpeningSupport openingSupport assertion.coordinate then
      throw
        ("loam: role balances unavailable: current anchor overlaps existing support for " ++
          assertion.coordinate.locus.token ++ " / " ++ assertion.coordinate.measure.token)

/--
Opening support lives in the same ordinary correction frontier already admitted
for Role Balance. Reuse that Event world rather than re-admitting it per row.
-/
private def openingBalanceRows
    (frontier : EventMemory)
    (coordinates : List EffectCoordinate) : List Loam.BalanceReview.Row :=
  coordinates.map fun coordinate =>
    {
      coordinate := coordinate
      quantity := EventMemory.quantityAtRecorded frontier coordinate.locus coordinate.measure
    }

/--
All selected anchor coordinates belong to one `CurrentQuantityAnchor.Evidence`
image, so its reflected-root cut is admitted once and shared across the bucket.
-/
private def currentAnchorRows
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinates : List EffectCoordinate) : Except String (List Loam.BalanceReview.Row) := do
  let quantities ←
    Loam.CurrentQuantityAnchor.inspectQuantities
      events corrections currentAnchor coordinates
  (coordinates.zip quantities).mapM fun item => do
    let coordinate := item.1
    let some quantity := item.2
      | throw "loam: role balances unavailable: selected current anchor coordinate has no assertion"
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
    | none => some { coordinate := row.coordinate, quantity := row.quantity }

private def unsupportedRows
    (coordinates : List EffectCoordinate)
    (roles : AccountingRoleMap) : List UnsupportedBalance :=
  coordinates.map fun coordinate =>
    { coordinate := coordinate, role := roles.roleOf? coordinate.locus }

/--
Compose one Role Balance snapshot from an already-established ordinary frontier.

The caller supplies the zero-origin projection entrance so raw/in-memory callers
can preserve BalanceReview's own fail-closed admission, while canonical callers
can reuse a proof-carrying ActualAuthority.Image. Current-anchor projection keeps
its separate reflected-root delta world.
-/
private def projectWithOrdinaryFrontier
    (frontier : EventMemory)
    (zeroProject : List EffectCoordinate → Except String Loam.BalanceReview.Snapshot)
    (anchorEvents : EventMemory)
    (anchorCorrections : EventCorrectionMemory)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  validateOpeningSupports frontier openingSupport
  validateSupportSeparation coverage openingSupport currentAnchor

  let candidates := candidateCoordinates frontier coverage openingSupport currentAnchor
  let buckets := routeCandidates coverage openingSupport currentAnchor candidates

  let zeroBalances ← zeroProject buckets.zeroOrigin
  let openingRows := openingBalanceRows frontier buckets.opening
  let anchorRows ← currentAnchorRows
    anchorEvents anchorCorrections currentAnchor buckets.currentAnchor
  let balances : Loam.BalanceReview.Snapshot :=
    { rows := zeroBalances.rows ++ openingRows ++ anchorRows }

  return {
    rows := classifiedRows balances roles
    unresolvedRoles := unresolvedSupported balances roles
    unsupportedBalances := unsupportedRows buckets.unsupported roles
  }

/--
Compose the current correction frontier, independent zero-origin, opening and
current-anchor support evidence, and explicit AccountingRole evidence.

This raw/in-memory entrance keeps its own correction admission and delegates
zero-origin projection to BalanceReview's raw fail-closed boundary.
-/
def project
    (evidence : Loam.BalanceReview.Evidence)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot := do
  let frontier ←
    match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
    | some frontier => pure frontier
    | none => throw "loam: role balances unavailable: event corrections do not justify one frontier"

  projectWithOrdinaryFrontier
    frontier
    (fun coordinates =>
      Loam.BalanceReview.project
        evidence.events evidence.corrections evidence.coverage coordinates)
    evidence.events
    evidence.corrections
    evidence.coverage
    openingSupport
    currentAnchor
    roles

/--
Compose Role Balance from one fully admitted Actual read image.

The ordinary current world reuses `image.currentEvents` for candidate discovery,
opening support, and zero-origin projection. The current-anchor path deliberately
keeps retained raw Events + Corrections because its reflected-root delta frontier
is a different semantic world.
-/
def projectImage
    (image : Loam.ActualAuthority.Image)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : Except String Snapshot :=
  projectWithOrdinaryFrontier
    image.currentEvents
    (fun coordinates => Loam.BalanceReview.projectImage image coverage coordinates)
    image.evidence.events
    image.evidence.corrections
    coverage
    openingSupport
    currentAnchor
    roles

private def loadOpeningSupport
    (path : System.FilePath) : IO (Except String OpeningSupportMap) := do
  if ← path.pathExists then
    match ← loadOpeningSupportMap? path with
    | some supportMap => return .ok supportMap
    | none => return .error "loam: malformed or unsupported opening support evidence"
  else
    return .ok OpeningSupportMap.empty

private def loadCurrentAnchor
    (path : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if ← path.pathExists then
    match ← loadCurrentQuantityAnchor? path with
    | some anchor => return .ok anchor
    | none => return .error "loam: malformed or unsupported current quantity anchor evidence"
  else
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty

/--
Load one admitted production Actual image, independent zero-origin coverage,
optional opening/current support, and explicit AccountingRole evidence, then
compose them. No presentation selection such as `balance-view.tsv` is used.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let rolesPath := dataDir / "accounting-role.loam"
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"

  let actualPath :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  let coverage ←
    match ← Loam.BalanceReview.loadCoverage (dataDir / "zero-origin-coverage.loam") with
    | .error message => return .error message
    | .ok coverage => pure coverage
  let openingSupport ←
    match ← loadOpeningSupport (dataDir / "opening-support.loam") with
    | .error message => return .error message
    | .ok supportMap => pure supportMap
  let currentAnchor ←
    match ← loadCurrentAnchor (dataDir / "current-quantity-anchor.loam") with
    | .error message => return .error message
    | .ok anchor => pure anchor
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  return projectImage image coverage openingSupport currentAnchor roles

end Loam.RoleBalanceReview
