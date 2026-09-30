import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.Review.BalanceReview
import Loam.Review.CurrentBalanceReview
import Loam.Review.HistoricalBalanceReview
import Loam.HouseholdPaths

namespace Loam.StockFlowReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared Stock–Flow review

Stock–Flow now consumes the shared historical-balance boundary rather than
assuming every selected coordinate has zero-origin history.

For each selected coordinate, historical start quantity may be justified by:

- exact `ZeroOriginCoverage` forward reconstruction; or
- `BoundedHistorySupport + CurrentQuantityAnchor` backward reconstruction.

Current tracked quantity is independently supplied by `CurrentBalanceReview`.
The window flow itself remains ordinary dated, correction-aware Actual. No
opening quantity, closing quantity, or report snapshot becomes canonical state.

One Stock–Flow answer remains single-Measure. Unlike Measures are never summed
into one Quantity.
-/

structure Snapshot where
  start : String
  endExclusive : String
  measure : Option MeasureId
  reconstructedStart : Quantity
  increasesAcrossEvents : Quantity
  decreasesAcrossEvents : Quantity
  currentTracked : Quantity
  deriving Repr, DecidableEq

/-- Exact selected-window change derived from its signed Event partitions. -/
def Snapshot.netChange (snapshot : Snapshot) : Quantity :=
  snapshot.increasesAcrossEvents + snapshot.decreasesAcrossEvents

/-- Exact reconstructed end boundary derived from the supported start plus flow. -/
def Snapshot.reconstructedEnd (snapshot : Snapshot) : Quantity :=
  snapshot.reconstructedStart + snapshot.netChange

@[simp] theorem Snapshot.reconstructedEnd_eq_components (snapshot : Snapshot) :
    snapshot.reconstructedEnd =
      snapshot.reconstructedStart +
        (snapshot.increasesAcrossEvents + snapshot.decreasesAcrossEvents) :=
  rfl

private def selectedMeasure?
    (balances : Loam.BalanceReview.Snapshot) : Except String (Option MeasureId) :=
  match balances.rows with
  | [] => .ok none
  | first :: rest =>
      if rest.all (fun row => row.coordinate.measure == first.coordinate.measure) then
        .ok (some first.coordinate.measure)
      else
        .error "loam: stock-flow selected balances span multiple measures"

private def eventTrackedQuanta
    (coordinates : List EffectCoordinate) (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ coordinates then total + effect.quantity.quanta else total)
    0

private structure WindowScan where
  positive : Int
  negative : Int

private def zeroWindowScan : WindowScan :=
  { positive := 0, negative := 0 }

private def updateWindow
    (state : WindowScan)
    (quantity : Int) : WindowScan :=
  if quantity > 0 then
    { state with positive := state.positive + quantity }
  else if quantity < 0 then
    { state with negative := state.negative + quantity }
  else
    state

/--
Scan the selected half-open window exactly once.

Superseded Records remain inert. A current selected nonzero Event must have a
usable occurrence date before it can be placed inside or outside the window.
-/
private def scanWindow
    (coordinates : List EffectCoordinate)
    (start endExclusive : String) :
    List Loam.ActualReview.Record → WindowScan → Except String WindowScan
  | [], state => .ok state
  | record :: rest, state =>
      if !record.isCurrent then
        scanWindow coordinates start endExclusive rest state
      else
        let quantity := eventTrackedQuanta coordinates record.event
        if quantity = 0 then
          scanWindow coordinates start endExclusive rest state
        else
          match record.date with
          | none =>
              .error
                ("loam: stock-flow unavailable: current selected Event " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if !Loam.ActualDate.validIsoDate date then
                .error
                  ("loam: stock-flow unavailable: current selected Event " ++
                    record.event.id.token ++ " has an invalid occurrence date")
              else if decide (start ≤ date ∧ date < endExclusive) then
                scanWindow coordinates start endExclusive rest
                  (updateWindow state quantity)
              else
                scanWindow coordinates start endExclusive rest state

private def currentTrackedQuanta (balances : Loam.BalanceReview.Snapshot) : Int :=
  balances.rows.foldl (fun total row => total + row.quantity.quanta) 0

private def historicalStartQuanta
    (balances : Loam.HistoricalBalanceReview.Snapshot) : Int :=
  balances.rows.foldl (fun total row => total + row.quantity.quanta) 0

private def historicalCoordinates
    (balances : Loam.HistoricalBalanceReview.Snapshot) : List EffectCoordinate :=
  balances.rows.map (fun row => row.coordinate)

/--
Derive one Stock–Flow answer from an exact current balance selection, one
independently justified historical start boundary, and current-truth Actual
records.

The historical boundary must answer exactly the same coordinate question as the
current balance selection. End quantity remains derived as start + window flow.
-/
def project
    (currentBalances : Loam.BalanceReview.Snapshot)
    (historicalStart : Loam.HistoricalBalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "loam: stock-flow start must be earlier than end"
  if historicalStart.startOfDay != start then
    throw "loam: stock-flow historical balance boundary does not match the requested start"
  let coordinates := currentBalances.coordinates
  if historicalCoordinates historicalStart != coordinates then
    throw "loam: stock-flow historical and current balance selections differ"
  let measure ← selectedMeasure? currentBalances
  let scan ← scanWindow coordinates start endExclusive records zeroWindowScan
  return {
    start := start
    endExclusive := endExclusive
    measure := measure
    reconstructedStart := Quantity.ofQuanta (historicalStartQuanta historicalStart)
    increasesAcrossEvents := Quantity.ofQuanta scan.positive
    decreasesAcrossEvents := Quantity.ofQuanta scan.negative
    currentTracked := Quantity.ofQuanta (currentTrackedQuanta currentBalances)
  }

/--
One prepared Stock–Flow read context over a single admitted Actual generation
and one coherent selection/support read.

It is transient projection material, not retained household state.
-/
structure Prepared where
  image : Loam.ActualAuthority.Image
  currentBalances : Loam.BalanceReview.Snapshot
  historicalEvidence : Loam.HistoricalBalanceReview.Evidence
  records : List Loam.ActualReview.Record

/--
Prepare the current exact balance selection, historical support families, and
Actual records from one caller-owned admitted Actual image.
-/
def prepareFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image) : IO (Except String Prepared) := do
  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView dataDir) with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected.eraseDups
  let current ←
    match ← Loam.CurrentBalanceReview.loadSnapshotFromActualImage dataDir image with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let currentBalances ←
    match Loam.CurrentBalanceReview.selectExact current coordinates with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let historicalEvidence ←
    match ← Loam.HistoricalBalanceReview.loadEvidence dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let records := Loam.ActualReview.recordsFromActualImage image
  return .ok {
    image := image
    currentBalances := currentBalances
    historicalEvidence := historicalEvidence
    records := records
  }

/-- Project one explicit window from a prepared coherent read context. -/
def projectPrepared
    (prepared : Prepared)
    (start endExclusive : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "loam: stock-flow start must be earlier than end"
  let coordinates := prepared.currentBalances.coordinates
  let historicalStart ←
    Loam.HistoricalBalanceReview.projectStartOfDay
      prepared.image prepared.historicalEvidence start coordinates
  project prepared.currentBalances historicalStart prepared.records start endExclusive

/--
Load one Stock–Flow answer from a caller-supplied admitted Actual image.

The Actual generation is not reopened. Current balance support and historical
support remain independent evidence families and fail closed at their shared
review boundaries.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let prepared ←
    match ← prepareFromActualImage dataDir image with
    | .error message => return .error message
    | .ok prepared => pure prepared
  return projectPrepared prepared start endExclusive

private def loadWithinActualObservation
    (dataDir : System.FilePath)
    (actualPath : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImage dataDir image start endExclusive

/--
Load one Stock–Flow answer while holding the selected Actual authority stable.

CurrentQuantityAnchor and BoundedHistorySupport writers also acquire Actual
ownership, so their coupled publication cannot cross this observation window.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  Loam.ActualAuthority.withActualFileOwnership actualPath
    (loadWithinActualObservation dataDir actualPath start endExclusive)

end Loam.StockFlowReview
