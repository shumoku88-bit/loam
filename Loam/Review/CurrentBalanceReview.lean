import Loam.Application.CorrectionFrontier
import Loam.Application.CurrentSupportRouting
import Loam.Review.BalanceReview
import Loam.Application.CurrentQuantityAnchor
import Loam.Application.CurrentQuantityPresence
import Loam.Authority.OpeningSupportAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.HouseholdPaths

namespace Loam.CurrentBalanceReview

open Loam.Core
open Loam.Persistence
open Loam.Application.CurrentSupportRouting

set_option autoImplicit false

/-!
# Neutral current-balance support review

This boundary answers only the present quantity question. It composes the four
already-retained support families without importing AccountingRole or any
presentation taxonomy:

- explicit zero-origin coverage;
- explicit OpeningSupport;
- exact CurrentQuantityAnchor evidence;
- CurrentQuantityPresence evidence for a coordinate known nonzero whose exact
  amount is unknown.

It deliberately does not widen `BalanceReview`. Historical reconstruction keeps
the stronger zero-origin requirement owned by `BalanceReview` and
`StockFlowReview`.
-/

/-- Current coordinates whose exact Quantity is justified. -/
structure Snapshot where
  rows : List Loam.BalanceReview.Row
  knownPresent : List EffectCoordinate := []
  unsupported : List EffectCoordinate := []
  deriving Repr, DecidableEq

private def validateOpeningSupport
    (frontier : EventMemory) (support : OpeningSupport) : Except String Unit :=
  match frontier.findById? support.openingEvent with
  | none =>
      .error
        ("loam: current balances unavailable: opening support for " ++
          support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token ++
          " does not reference one current Event")
  | some event =>
      if eventContainsCoordinate event support.coordinate then
        .ok ()
      else
        .error
          ("loam: current balances unavailable: opening Event " ++
            support.openingEvent.token ++ " does not contain " ++
            support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token)

private def validateOpeningSupports
    (frontier : EventMemory) (supportMap : OpeningSupportMap) : Except String Unit := do
  for support in supportMap.supports do
    validateOpeningSupport frontier support

private def validateSupportSeparation
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence) : Except String Unit := do
  for support in openingSupport.supports do
    if coverage.covers support.coordinate then
      throw
        ("loam: current balances unavailable: opening support overlaps zero-origin support for " ++
          support.coordinate.locus.token ++ " / " ++ support.coordinate.measure.token)
  for assertion in currentAnchor.assertions do
    if coverage.covers assertion.coordinate || hasOpeningSupport openingSupport assertion.coordinate then
      throw
        ("loam: current balances unavailable: current anchor overlaps existing support for " ++
          assertion.coordinate.locus.token ++ " / " ++ assertion.coordinate.measure.token)
  for coordinate in currentPresence.coordinates do
    if coverage.covers coordinate ||
        hasOpeningSupport openingSupport coordinate ||
        hasCurrentAnchor currentAnchor coordinate then
      throw
        ("loam: current balances unavailable: current presence overlaps exact support for " ++
          coordinate.locus.token ++ " / " ++ coordinate.measure.token)

private def openingRows
    (frontier : EventMemory)
    (coordinates : List EffectCoordinate) : List Loam.BalanceReview.Row :=
  coordinates.map fun coordinate =>
    {
      coordinate := coordinate
      quantity := EventMemory.quantityAtRecorded frontier coordinate.locus coordinate.measure
    }

private def anchorRows
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (anchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinates : List EffectCoordinate) : Except String (List Loam.BalanceReview.Row) := do
  let quantities ← Loam.CurrentQuantityAnchor.inspectQuantities events corrections anchor coordinates
  (coordinates.zip quantities).mapM fun item => do
    let coordinate := item.1
    let some quantity := item.2
      | throw "loam: current balances unavailable: selected anchor coordinate has no assertion"
    return { coordinate := coordinate, quantity := quantity }

private def projectWithOrdinaryFrontier
    (frontier : EventMemory)
    (zeroProject : List EffectCoordinate → Except String Loam.BalanceReview.Snapshot)
    (anchorEvents : EventMemory)
    (anchorCorrections : EventCorrectionMemory)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence) :
    Except String Snapshot := do
  validateOpeningSupports frontier openingSupport
  validateSupportSeparation coverage openingSupport currentAnchor currentPresence

  let candidates :=
    candidateCoordinates frontier coverage openingSupport currentAnchor currentPresence
  let buckets := routeCandidates coverage openingSupport currentAnchor candidates

  let zero ← zeroProject buckets.zeroOrigin
  let opening := openingRows frontier buckets.opening
  let anchored ←
    anchorRows anchorEvents anchorCorrections currentAnchor buckets.currentAnchor
  let exact := zero.rows ++ opening ++ anchored

  let presenceStates ←
    Loam.CurrentQuantityPresence.inspectCurrentPresences
      anchorEvents anchorCorrections currentPresence buckets.unsupported
  let presencePairs := buckets.unsupported.zip presenceStates
  let knownPresent :=
    presencePairs.filterMap fun pair => if pair.2 then some pair.1 else none
  let unsupported :=
    presencePairs.filterMap fun pair => if pair.2 then none else some pair.1

  return { rows := exact, knownPresent := knownPresent, unsupported := unsupported }

/-- Raw/in-memory composition for tests and already-loaded evidence. -/
def project
    (evidence : Loam.BalanceReview.Evidence)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence) :
    Except String Snapshot := do
  let frontier ←
    match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
    | some frontier => pure frontier
    | none => throw "loam: current balances unavailable: event corrections do not justify one frontier"
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
    currentPresence

/-- Compose current support from one already-admitted Actual image. -/
def projectImage
    (image : Loam.ActualAuthority.Image)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence) :
    Except String Snapshot :=
  projectWithOrdinaryFrontier
    image.currentEvents
    (fun coordinates => Loam.BalanceReview.projectImage image coverage coordinates)
    image.evidence.events
    image.evidence.corrections
    coverage
    openingSupport
    currentAnchor
    currentPresence

/-- Load neutral current-balance support from a caller-owned Actual image. -/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image) : IO (Except String Snapshot) := do
  let coverage ←
    match ← Loam.BalanceReview.loadHouseholdCoverage dataDir with
    | .error message => return .error message
    | .ok coverage => pure coverage
  let openingSupport ←
    match ← Loam.OpeningSupportAuthority.loadHouseholdOrEmpty? dataDir with
    | .error message => return .error message
    | .ok support => pure support
  let currentSupport ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? dataDir with
    | .error message => return .error message
    | .ok observed => pure observed.snapshot
  return projectImage
    image coverage openingSupport currentSupport.anchor currentSupport.presence

/-- Load one admitted Actual image and compose neutral current-balance support. -/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImage dataDir image

/-- Exact supported current-balance row for one coordinate, if present. -/
def Snapshot.exactRowFor?
    (snapshot : Snapshot)
    (coordinate : EffectCoordinate) : Option Loam.BalanceReview.Row :=
  snapshot.rows.find? fun row => decide (row.coordinate = coordinate)

/--
Select exact current quantities in caller order.

Known-present/amount-unknown and fully unsupported coordinates are distinct
failure cases. This function never converts either state into zero.
-/
def selectExact
    (snapshot : Snapshot)
    (coordinates : List EffectCoordinate) :
    Except String Loam.BalanceReview.Snapshot := do
  let rows ← coordinates.mapM fun coordinate =>
    match snapshot.exactRowFor? coordinate with
    | some row => pure row
    | none =>
        if snapshot.knownPresent.contains coordinate then
          throw
            ("loam: exact current quantity unknown for " ++ coordinate.locus.token ++
              " / " ++ coordinate.measure.token)
        else
          throw
            ("loam: current quantity support missing for " ++ coordinate.locus.token ++
              " / " ++ coordinate.measure.token)
  return { rows := rows }

end Loam.CurrentBalanceReview
