import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualReview
import Loam.BalanceReview
import Loam.HouseholdPaths

namespace Loam.StockFlowReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared Stock–Flow review

This report boundary derives one explicit half-open window over the same
correction-aware Actual records and selected current balances already used by
production surfaces. It does not infer accounting roles or retain opening/closing
report state.

Because selected balances are admitted only through `BalanceReview`, every
selected coordinate already carries explicit zero-origin evidence. Historical
window boundaries can therefore be reconstructed by summing the current Event
frontier before each boundary. A current selected Event without a usable date
refuses the report because it cannot safely be placed on either side of a
boundary.
-/

structure Snapshot where
  start : String
  endExclusive : String
  reconstructedStart : Quantity
  increasesAcrossEvents : Quantity
  decreasesAcrossEvents : Quantity
  currentTracked : Quantity
  deriving Repr, DecidableEq

/-- Exact selected-window change derived from its signed Event partitions. -/
def Snapshot.netChange (snapshot : Snapshot) : Quantity :=
  snapshot.increasesAcrossEvents + snapshot.decreasesAcrossEvents

/-- Exact reconstructed end boundary derived after the project parity check. -/
def Snapshot.reconstructedEnd (snapshot : Snapshot) : Quantity :=
  snapshot.reconstructedStart + snapshot.netChange

/-- The exposed reconstructed end is exactly start plus the two signed partitions. -/
@[simp] theorem Snapshot.reconstructedEnd_eq_components (snapshot : Snapshot) :
    snapshot.reconstructedEnd =
      snapshot.reconstructedStart +
        (snapshot.increasesAcrossEvents + snapshot.decreasesAcrossEvents) :=
  rfl

private def selectedCoordinates
    (balances : Loam.BalanceReview.Snapshot) : List EffectCoordinate :=
  balances.rows.map (fun row => row.coordinate)

private def eventTrackedQuanta
    (coordinates : List EffectCoordinate) (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ coordinates then total + effect.quantity.quanta else total)
    0

private structure Scan where
  startBoundary : Int
  endBoundary : Int
  positiveWindow : Int
  negativeWindow : Int

private def zeroScan : Scan :=
  {
    startBoundary := 0
    endBoundary := 0
    positiveWindow := 0
    negativeWindow := 0
  }

private def updateFromQuantity
    (start endExclusive : String)
    (state : Scan)
    (date : String)
    (quantity : Int) : Scan :=
  let nextStart :=
    if decide (date < start) then
      state.startBoundary + quantity
    else
      state.startBoundary
  let nextEnd :=
    if decide (date < endExclusive) then
      state.endBoundary + quantity
    else
      state.endBoundary
  let changes :=
    if decide (start ≤ date ∧ date < endExclusive) then
      if quantity > 0 then
        (state.positiveWindow + quantity, state.negativeWindow)
      else if quantity < 0 then
        (state.positiveWindow, state.negativeWindow + quantity)
      else
        (state.positiveWindow, state.negativeWindow)
    else
      (state.positiveWindow, state.negativeWindow)
  {
    startBoundary := nextStart
    endBoundary := nextEnd
    positiveWindow := changes.1
    negativeWindow := changes.2
  }

/--
Scan selected current Records exactly once.

For each current Record the selected Event quantity is computed once, then that
same value drives date admission and all Stock-Flow arithmetic coordinates.
Superseded Records remain inert, and zero selected quantity still does not
require an occurrence date.
-/
private def scanRecords
    (coordinates : List EffectCoordinate)
    (start endExclusive : String) :
    List Loam.ActualReview.Record → Scan → Except String Scan
  | [], state => .ok state
  | record :: rest, state =>
      if !record.isCurrent then
        scanRecords coordinates start endExclusive rest state
      else
        let quantity := eventTrackedQuanta coordinates record.event
        if quantity = 0 then
          scanRecords coordinates start endExclusive rest state
        else
          match record.date with
          | none =>
              .error
                ("loam: stock-flow unavailable: current selected Event " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                scanRecords coordinates start endExclusive rest
                  (updateFromQuantity start endExclusive state date quantity)
              else
                .error
                  ("loam: stock-flow unavailable: current selected Event " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def currentTrackedQuanta (balances : Loam.BalanceReview.Snapshot) : Int :=
  balances.rows.foldl (fun total row => total + row.quantity.quanta) 0

/--
Derive one Stock–Flow answer from already admitted shared review answers.
The boundary reconstruction uses the current correction frontier represented by
`ActualReview.Record.isCurrent`; superseded Events never contribute twice.
-/
def project
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "loam: stock-flow start must be earlier than end"

  let coordinates := selectedCoordinates balances
  let scan ← scanRecords coordinates start endExclusive records zeroScan
  let net := scan.positiveWindow + scan.negativeWindow

  if scan.startBoundary + net != scan.endBoundary then
    throw "loam: stock-flow internal parity failure"

  return {
    start := start
    endExclusive := endExclusive
    reconstructedStart := Quantity.ofQuanta scan.startBoundary
    increasesAcrossEvents := Quantity.ofQuanta scan.positiveWindow
    decreasesAcrossEvents := Quantity.ofQuanta scan.negativeWindow
    currentTracked := Quantity.ofQuanta (currentTrackedQuanta balances)
  }

private def loadWithinActualObservation
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let balances ←
    match ← Loam.BalanceReview.loadSnapshot dataDir actualRoot with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let records ←
    match ← Loam.ActualReview.loadRecordsFromActual actualRoot with
    | .error message => return .error message
    | .ok records => pure records
  return project balances records start endExclusive

/--
Load one Stock–Flow answer from a caller-supplied admitted Actual image.

This entrance is for composed presentation surfaces that already own one Actual
generation. Balance selection and zero-origin evidence remain independent
configuration/evidence gates; only the Actual generation is shared.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let coverage ←
    match ← Loam.BalanceReview.loadCoverage (Loam.HouseholdPaths.zeroOriginCoverage dataDir) with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView dataDir) with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected
  let balances ←
    match Loam.BalanceReview.projectImage image coverage coordinates with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let records := Loam.ActualReview.recordsFromActualImage image
  return project balances records start endExclusive

/--
Load the two existing production read answers and compose them.

Balance Review and Actual Review both observe normalized `actual.loam`. Their two
reads therefore run inside one short Actual ownership interval so one Stock–Flow
answer cannot mix balances from one Actual generation with records from another.
Canonical interpretation remains owned by the existing readers; this boundary
adds no second Event decoder or report authority.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  Loam.ActualAuthority.withActualFileOwnership actualPath
    (loadWithinActualObservation dataDir actualRoot start endExclusive)

end Loam.StockFlowReview
