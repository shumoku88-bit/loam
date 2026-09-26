import Loam.ActualAuthority
import Loam.ActualDate
import Loam.BalanceReview
import Loam.BalanceViewConfig
import Loam.CurrentBalanceReview
import Loam.HouseholdPaths
import Loam.ScheduledReview

namespace Loam.ConditionalBalancePathReview

open Loam.Core

set_option autoImplicit false

/-!
# Conditional selected-balance path review

This read-only review implements only the arithmetic and provenance boundary
qualified by Observations 229 and 231.

It starts from the replaceable balance-view selection projected through neutral
`CurrentBalanceReview` support, reads the current-open Scheduled frontier, and applies one
caller-supplied completeness assumption through an inclusive calendar horizon.

The assumption is not retained evidence. The result is therefore conditional,
not a forecast, qualified knowledge, safe-to-spend authority, or canonical
liquidity. An overdue selected Scheduled effect is refused because current
retained evidence does not justify placing it on any future day.
-/

structure Point where
  date : String
  scheduledChange : Quantity
  balance : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  asOf : String
  assumedCompleteThrough : String
  measure : MeasureId
  currentSelected : Quantity
  points : List Point
  deriving Repr, DecidableEq

namespace Snapshot

/-- Balance at the inclusive assumption horizon, derived from the retained path. -/
def finalAtHorizon (snapshot : Snapshot) : Quantity :=
  snapshot.points.foldl (fun _ point => point.balance) snapshot.currentSelected

/-- Lowest emitted day-boundary balance, including the retained current baseline. -/
def lowWater (snapshot : Snapshot) : Quantity :=
  snapshot.points.foldl
    (fun low point => if point.balance.quanta < low.quanta then point.balance else low)
    snapshot.currentSelected

end Snapshot

private def selectedCoordinates
    (balances : Loam.BalanceReview.Snapshot) : List EffectCoordinate :=
  balances.rows.map (fun row => row.coordinate)

private def selectedMeasure
    (balances : Loam.BalanceReview.Snapshot) : Except String MeasureId :=
  match balances.rows with
  | [] =>
      .error "loam: conditional outlook unavailable: balance-view selection is empty"
  | first :: rest =>
      if rest.all (fun row => decide (row.coordinate.measure = first.coordinate.measure)) then
        .ok first.coordinate.measure
      else
        .error
          "loam: conditional outlook unavailable: selected balances span multiple measures"

private def currentSelectedQuanta (balances : Loam.BalanceReview.Snapshot) : Int :=
  balances.rows.foldl (fun total row => total + row.quantity.quanta) 0

private def occurrenceSelectedQuanta
    (coordinates : List EffectCoordinate)
    (occurrence : ScheduledOccurrence String) : Int :=
  coordinates.foldl
    (fun total coordinate =>
      if occurrence.measure = coordinate.measure then
        total + (occurrence.quantityAt coordinate.locus).quanta
      else
        total)
    0

private def currentOpenOccurrences
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot) :
    Except String (List (ScheduledOccurrence String)) :=
  match Loam.Application.currentOpenScheduled
      scheduled.scheduled scheduled.terminals scheduled.events with
  | .open occurrences => .ok occurrences
  | .unknownCompletionScheduled =>
      .error "loam: conditional outlook unavailable: Scheduled completion endpoint is unknown"
  | .unknownRetirementScheduled =>
      .error "loam: conditional outlook unavailable: Scheduled retirement endpoint is unknown"
  | .unknownReplacementScheduled =>
      .error "loam: conditional outlook unavailable: Scheduled replacement endpoint is unknown"
  | .invalidReplacementGraph =>
      .error "loam: conditional outlook unavailable: Scheduled replacement graph is invalid"
  | .conflictingTerminalEvidence =>
      .error "loam: conditional outlook unavailable: Scheduled terminal evidence conflicts"

private def collectSelectedChanges
    (coordinates : List EffectCoordinate)
    (asOf assumedCompleteThrough : String) :
    List (ScheduledOccurrence String) → Except String (List (String × Int))
  | [] => .ok []
  | occurrence :: rest => do
      let quantity := occurrenceSelectedQuanta coordinates occurrence
      if quantity = 0 then
        collectSelectedChanges coordinates asOf assumedCompleteThrough rest
      else if !Loam.ActualDate.validIsoDate occurrence.scheduledOn then
        throw
          ("loam: conditional outlook unavailable: selected Scheduled " ++
            occurrence.id.token ++ " has an invalid date")
      else if decide (occurrence.scheduledOn < asOf) then
        throw
          ("loam: conditional outlook unavailable: selected Scheduled " ++
            occurrence.id.token ++ " is overdue and has no justified future settlement date")
      else
        let later ← collectSelectedChanges coordinates asOf assumedCompleteThrough rest
        if decide (occurrence.scheduledOn ≤ assumedCompleteThrough) then
          return (occurrence.scheduledOn, quantity) :: later
        else
          return later

private def addDayChange
    (date : String) (quantity : Int) : List (String × Int) → List (String × Int)
  | [] => [(date, quantity)]
  | (existingDate, existingQuantity) :: rest =>
      if existingDate = date then
        (existingDate, existingQuantity + quantity) :: rest
      else
        (existingDate, existingQuantity) :: addDayChange date quantity rest

private def bucketChanges (changes : List (String × Int)) : List (String × Int) :=
  changes.foldl
    (fun buckets change => addDayChange change.1 change.2 buckets)
    []

private def sortBuckets (buckets : List (String × Int)) : List (String × Int) :=
  buckets.mergeSort fun left right => left.1 ≤ right.1

private def buildPoints
    (current : Int) : List (String × Int) → List Point
  | [] => []
  | bucket :: rest =>
      let nextBalance := current + bucket.2
      { date := bucket.1
      , scheduledChange := Quantity.ofQuanta bucket.2
      , balance := Quantity.ofQuanta nextBalance } ::
        buildPoints nextBalance rest

/--
Run one conditional path calculation from already-admitted shared review answers.
The assumption horizon is inclusive. Same-day Scheduled effects are netted before
one day-boundary point is emitted, so no intraday ordering claim is made.
-/
def project
    (balances : Loam.BalanceReview.Snapshot)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (asOf assumedCompleteThrough : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate asOf then
    throw "loam: conditional outlook as-of date must be a real YYYY-MM-DD calendar date"
  if !Loam.ActualDate.validIsoDate assumedCompleteThrough then
    throw "loam: conditional completeness horizon must be a real YYYY-MM-DD calendar date"
  if !(decide (asOf ≤ assumedCompleteThrough)) then
    throw "loam: conditional completeness horizon must not be earlier than today"

  let measure ← selectedMeasure balances
  let coordinates := selectedCoordinates balances
  let occurrences ← currentOpenOccurrences scheduled
  let changes ← collectSelectedChanges coordinates asOf assumedCompleteThrough occurrences
  let buckets := sortBuckets (bucketChanges changes)
  let current := currentSelectedQuanta balances
  let points := buildPoints current buckets

  return {
    asOf := asOf
    assumedCompleteThrough := assumedCompleteThrough
    measure := measure
    currentSelected := Quantity.ofQuanta current
    points := points
  }

private def loadWithinActualObservation
    (dataDir actualRoot : System.FilePath)
    (today assumedCompleteThrough : String) : IO (Except String Snapshot) := do
  let current ←
    match ← Loam.CurrentBalanceReview.loadSnapshot dataDir actualRoot with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let selected ←
    match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView dataDir) with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some coordinates => pure coordinates
  let balances ←
    match Loam.CurrentBalanceReview.selectExact current selected with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let scheduled ←
    match ← Loam.ScheduledReview.loadHouseholdEvidence dataDir actualRoot with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  return project balances scheduled today assumedCompleteThrough

/--
Compose existing production readers without adding a new canonical authority.
`today` is read from the same host-local date adapter already used by the TUI.

Current Balance Review and Scheduled Review both depend on normalized `actual.loam`:
current balances compose qualified present support while Scheduled lifecycle
admission uses its Event identities to validate terminal evidence. Their two
reads therefore run inside one short Actual ownership interval so one conditional
path answer cannot mix those obligations across different Actual generations.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (assumedCompleteThrough : String) : IO (Except String Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: conditional outlook unavailable: could not determine the local date"
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  Loam.ActualAuthority.withActualFileOwnership actualPath
    (loadWithinActualObservation dataDir actualRoot today assumedCompleteThrough)

end Loam.ConditionalBalancePathReview
