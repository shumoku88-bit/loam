import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualReview
import Loam.BalanceReview

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

private def validateSelectedDates
    (coordinates : List EffectCoordinate) :
    List Loam.ActualReview.Record → Except String Unit
  | [] => .ok ()
  | record :: rest =>
      if !record.isCurrent then
        validateSelectedDates coordinates rest
      else
        let quantity := eventTrackedQuanta coordinates record.event
        if quantity = 0 then
          validateSelectedDates coordinates rest
        else
          match record.date with
          | none =>
              .error
                ("loam: stock-flow unavailable: current selected Event " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                validateSelectedDates coordinates rest
              else
                .error
                  ("loam: stock-flow unavailable: current selected Event " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def boundaryQuanta
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (boundary : String) : Int :=
  records.foldl
    (fun total record =>
      if !record.isCurrent then total
      else
        match record.date with
        | some date =>
            if decide (date < boundary) then
              total + eventTrackedQuanta coordinates record.event
            else
              total
        | none => total)
    0

private def windowChanges
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) : Int × Int :=
  records.foldl
    (fun totals record =>
      if !record.isCurrent then totals
      else
        match record.date with
        | none => totals
        | some date =>
            if decide (start ≤ date ∧ date < endExclusive) then
              let quantity := eventTrackedQuanta coordinates record.event
              if quantity > 0 then
                (totals.1 + quantity, totals.2)
              else if quantity < 0 then
                (totals.1, totals.2 + quantity)
              else
                totals
            else
              totals)
    (0, 0)

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
  validateSelectedDates coordinates records

  let startQuanta := boundaryQuanta coordinates records start
  let endQuanta := boundaryQuanta coordinates records endExclusive
  let changes := windowChanges coordinates records start endExclusive
  let net := changes.1 + changes.2

  if startQuanta + net != endQuanta then
    throw "loam: stock-flow internal parity failure"

  return {
    start := start
    endExclusive := endExclusive
    reconstructedStart := Quantity.ofQuanta startQuanta
    increasesAcrossEvents := Quantity.ofQuanta changes.1
    decreasesAcrossEvents := Quantity.ofQuanta changes.2
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
