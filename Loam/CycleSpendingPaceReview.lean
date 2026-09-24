import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualReview
import Loam.BalanceReview
import Loam.BoundaryPresetConfig
import Loam.DailyPaceConfig
import Loam.ScheduledReview

namespace Loam.CycleSpendingPaceReview

open Loam.Core

set_option autoImplicit false

/-!
# Current cycle spending pace

A read-only answer to one narrow household question:

```text
explicit day-to-day JPY balance pool
- current-open Scheduled outflow from that pool before cycle end
= balance available through cycle end

available through cycle end / remaining calendar days = Daily Pace
```

The selected pool is explicit replaceable query configuration. It is not inferred
from Locus names, AccountingRole, Purpose, balance display selection, or cycle
funding selection.

Scheduled deductions are computed per occurrence from the whole movement's net
effect on the selected pool. A transfer inside the pool therefore deducts zero,
a planned inflow does not increase current capacity before it becomes Actual,
and an overdue current-open occurrence remains protected until terminal evidence
closes it.
-/

structure Snapshot where
  observedAt : String
  endExclusive : String
  remainingDays : Nat
  eligiblePool : Quantity
  automaticDeductions : Quantity
  availableThroughEnd : Quantity
  deriving Repr, DecidableEq

/--
Integer-quanta pace for presentation.

The projection admits only a positive remaining-day count. Returning `Option`
keeps that invariant explicit for manually constructed/test snapshots too.
-/
def Snapshot.dailyPaceQuanta? (snapshot : Snapshot) : Option Int :=
  if snapshot.remainingDays = 0 then
    none
  else
    some (snapshot.availableThroughEnd.quanta / Int.ofNat snapshot.remainingDays)


private def selectedChange
    (selection : List EffectCoordinate)
    (measure : MeasureId)
    (change : MovementChange LocusId) : Bool :=
  selection.any fun coordinate =>
    coordinate.locus == change.coordinate && coordinate.measure == measure

/-- Exact signed effect of one Scheduled occurrence on the explicitly selected pool. -/
private def eligiblePoolEffectQuanta
    (selection : List EffectCoordinate)
    (record : Loam.ScheduledReview.Record) : Int :=
  record.movement.changes.foldl
    (fun total change =>
      if selectedChange selection record.measure change then
        total + change.quantity.quanta
      else
        total)
    0

/--
Only a net drain of the selected pool is protected.

A positive planned effect is not spendable before it becomes Actual. A movement
whose selected-pool net is zero is an internal transfer, not a deduction.
-/
private def deductionQuanta
    (selection : List EffectCoordinate)
    (record : Loam.ScheduledReview.Record) : Int :=
  max 0 (-eligiblePoolEffectQuanta selection record)

private def selectedRowsMatch
    (selection : List EffectCoordinate)
    (balances : Loam.BalanceReview.Snapshot) : Bool :=
  balances.rows.map (·.coordinate) == selection

/--
Compose already-admitted current balances and Scheduled lifecycle evidence.

There is intentionally no lower Scheduled-date bound. Current-open overdue
occurrences still drain the selected pool until completion, retirement, or
replacement removes them from the current-open frontier.
-/
def project
    (observedAt endExclusive : String)
    (selection : List EffectCoordinate)
    (balances : Loam.BalanceReview.Snapshot)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot) :
    Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate observedAt ||
      !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: Daily Pace requires real YYYY-MM-DD observation and cycle-end dates"
  let some distance := Loam.ActualDate.daysBetween? observedAt endExclusive
    | throw "loam: Daily Pace could not determine the remaining calendar horizon"
  if distance <= 0 then
    throw "loam: Daily Pace requires the observation date to precede cycle end"
  if !decide selection.Nodup then
    throw "loam: Daily Pace pool contains duplicate coordinates"
  if !selection.all (fun coordinate => coordinate.measure.token == "jpy") then
    throw "loam: Daily Pace currently requires an explicit JPY pool"
  if !selectedRowsMatch selection balances then
    throw "loam: Daily Pace balance answer does not match the selected pool"

  let records ← Loam.ScheduledReview.currentOpenRecords scheduled
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: Daily Pace current-open Scheduled evidence contains an invalid date"

  let eligible :=
    balances.rows.foldl (fun total row => total + row.quantity.quanta) (0 : Int)
  let deductions :=
    records.foldl
      (fun total record =>
        if decide (record.scheduledOn < endExclusive) then
          total + deductionQuanta selection record
        else
          total)
      (0 : Int)
  let available := eligible - deductions

  return {
    observedAt := observedAt
    endExclusive := endExclusive
    remainingDays := distance.natAbs
    eligiblePool := Quantity.ofQuanta eligible
    automaticDeductions := Quantity.ofQuanta deductions
    availableThroughEnd := Quantity.ofQuanta available
  }

/-!
## Retrospective pace series

The series below retains no Daily Pace observations. Instead it reconstructs each
past day from the **current admitted household truth**:

- the current Event correction frontier is cut by current occurrence dates, just
  as Stock–Flow reconstruction cuts historical quantity boundaries;
- a Scheduled completion is considered closed from the occurrence date of its
  retained Actual endpoint;
- currently retained Scheduled occurrences are treated as part of the current
  truth for every reconstructed day.

This is intentionally not a claim about what LOAM knew or displayed on that past
day. Scheduled creation has no learned-time coordinate, so a later-added
occurrence may appear in an earlier reconstructed point.

Retirement and Scheduled replacement currently have no learned-time coordinate
or dated Actual endpoint. If either would affect the selected Daily Pace pool,
historical reconstruction refuses rather than fabricating a transition date.
-/

private def selectedEventQuanta
    (selection : List EffectCoordinate)
    (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ selection then total + effect.quantity.quanta else total)
    0

private def validateHistoricalActualDates
    (selection : List EffectCoordinate) :
    List Loam.ActualReview.Record → Except String Unit
  | [] => .ok ()
  | record :: rest =>
      if !record.isCurrent then
        validateHistoricalActualDates selection rest
      else
        let quantity := selectedEventQuanta selection record.event
        if quantity = 0 then
          validateHistoricalActualDates selection rest
        else
          match record.date with
          | none =>
              .error
                ("loam: Daily Pace history unavailable: current selected Actual " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                validateHistoricalActualDates selection rest
              else
                .error
                  ("loam: Daily Pace history unavailable: current selected Actual " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def eligiblePoolAtEndOfDay
    (selection : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (date : String) : Int :=
  records.foldl
    (fun total record =>
      if !record.isCurrent then total
      else
        match record.date with
        | some validOn =>
            if decide (validOn ≤ date) then
              total + selectedEventQuanta selection record.event
            else
              total
        | none => total)
    0

private def terminalFor?
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (id : ScheduledId) : Option ScheduledTerminal :=
  scheduled.terminals.terminals.find? fun terminal => terminal.source == id

private def completionDateFor
    (records : List Loam.ActualReview.Record)
    (event : EventId) : Except String String := do
  let some record := records.find? fun record => record.event.id == event
    | throw
        ("loam: Daily Pace history unavailable: Scheduled completion Actual " ++
          event.token ++ " is not retained")
  let some date := record.date
    | throw
        ("loam: Daily Pace history unavailable: Scheduled completion Actual " ++
          event.token ++ " has no occurrence date")
  if Loam.ActualDate.validIsoDate date then
    return date
  throw
    ("loam: Daily Pace history unavailable: Scheduled completion Actual " ++
      event.token ++ " has an invalid occurrence date")

private def historicalDeductionsForDate
    (selection : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (endExclusive pointDate : String) :
    List (ScheduledOccurrence String) → Except String Int
  | [] => .ok 0
  | occurrence :: rest => do
      let later ←
        historicalDeductionsForDate
          selection records scheduled endExclusive pointDate rest
      let deduction := deductionQuanta selection occurrence
      if deduction = 0 || !(decide (occurrence.scheduledOn < endExclusive)) then
        return later
      if !Loam.ActualDate.validIsoDate occurrence.scheduledOn then
        throw
          ("loam: Daily Pace history unavailable: Scheduled " ++
            occurrence.id.token ++ " has an invalid retained date")
      match terminalFor? scheduled occurrence.id with
      | none =>
          return deduction + later
      | some terminal =>
          match terminal.target with
          | some (.actual event) =>
              let completedOn ← completionDateFor records event
              if decide (completedOn ≤ pointDate) then
                return later
              else
                return deduction + later
          | some (.scheduled _) =>
              throw
                ("loam: Daily Pace history unavailable: Scheduled " ++
                  occurrence.id.token ++
                  " was replaced without a learned-time coordinate")
          | none =>
              throw
                ("loam: Daily Pace history unavailable: Scheduled " ++
                  occurrence.id.token ++
                  " was retired without a learned-time coordinate")

private def reconstructedSnapshot
    (endExclusive : String)
    (selection : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (date : String) : Except String Snapshot := do
  let some distance := Loam.ActualDate.daysBetween? date endExclusive
    | throw "loam: Daily Pace history could not determine a remaining calendar horizon"
  if distance <= 0 then
    throw "loam: Daily Pace history point must precede cycle end"
  let eligible := eligiblePoolAtEndOfDay selection records date
  let deductions ←
    historicalDeductionsForDate
      selection records scheduled endExclusive date scheduled.scheduled.occurrences
  return {
    observedAt := date
    endExclusive := endExclusive
    remainingDays := distance.natAbs
    eligiblePool := Quantity.ofQuanta eligible
    automaticDeductions := Quantity.ofQuanta deductions
    availableThroughEnd := Quantity.ofQuanta (eligible - deductions)
  }

private def recentDates
    (windowStart observedAt : String)
    (days : Nat) : List String :=
  (List.range days).filterMap fun index => do
    let offset := Int.ofNat index - Int.ofNat (days - 1)
    let date ← Loam.ActualDate.shiftDays? observedAt offset
    if decide (windowStart ≤ date) then some date else none

/--
Reconstruct up to `days` current-truth Daily Pace points inside the current
explicit cycle, oldest first.

The latest reconstructed point must equal the ordinary current Daily Pace answer.
This parity check prevents the trend from silently using a different balance or
Scheduled interpretation than Home's headline number.
-/
def projectHistory
    (windowStart observedAt endExclusive : String)
    (selection : List EffectCoordinate)
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (days : Nat) : Except String (List Snapshot) := do
  if !Loam.ActualDate.validIsoDate windowStart then
    throw "loam: Daily Pace history requires a real cycle-start date"
  if !(decide (windowStart ≤ observedAt)) then
    throw "loam: Daily Pace history observation precedes the current cycle"
  let current ← project observedAt endExclusive selection balances scheduled
  let _ ← Loam.ScheduledReview.currentOpenRecords scheduled
  validateHistoricalActualDates selection records
  if days = 0 then
    return []
  let dates := recentDates windowStart observedAt days
  let points ← dates.mapM fun date =>
    reconstructedSnapshot endExclusive selection records scheduled date
  match points.reverse with
  | [] => return []
  | latest :: _ =>
      if latest = current then
        return points
      throw
        "loam: Daily Pace history latest point disagrees with the current Daily Pace answer"

/--
Load the current explicit boundary, Daily Pace pool, current balances, and
current-open Scheduled evidence from one caller-supplied admitted Actual image.

This entrance is for composed read boundaries such as Home that need several
Actual-backed answers from one generation. It never reopens `actual.loam`.
-/
def loadSnapshotFromActualImageAt
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (observedAt : String) : IO (Except String Snapshot) := do
  let window ←
    match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
    | .error message => return .error message
    | .ok window => pure window
  let selection ←
    match ← Loam.DailyPaceConfig.load (dataDir / "config" / "daily-pace.tsv") with
    | .error message => return .error message
    | .ok coordinates => pure coordinates
  let coverage ←
    match ← Loam.BalanceReview.loadCoverage (dataDir / "zero-origin-coverage.loam") with
    | .error message => return .error message
    | .ok coverage => pure coverage
  let balances ←
    match Loam.BalanceReview.projectImage image coverage selection with
    | .error message => return .error message
    | .ok balances => pure balances
  let scheduled ←
    match ← Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir image.currentEvents with
    | .error message => return .error message
    | .ok scheduled => pure scheduled
  return project observedAt window.endExclusive selection balances scheduled

/--
Load the current explicit boundary, Daily Pace pool, current balances, and
current-open Scheduled evidence.

Standalone callers still select and load their Actual authority here. Composed
readers that already own one admitted Actual generation should call
`loadSnapshotFromActualImageAt` instead.
-/
def loadSnapshotAt
    (dataDir actualRoot : System.FilePath)
    (observedAt : String) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImageAt dataDir image observedAt

/--
Reconstruct a retrospective current-truth Daily Pace series from one
caller-supplied admitted Actual image.

The same image supplies balances, Scheduled completion Event references, and
Actual review records, so a composed reader cannot mix Actual generations while
building one answer.
-/
def loadHistoryFromActualImageAt
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (observedAt : String)
    (days : Nat) : IO (Except String (List Snapshot)) := do
  let window ←
    match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
    | .error message => return .error message
    | .ok window => pure window
  let selection ←
    match ← Loam.DailyPaceConfig.load (dataDir / "config" / "daily-pace.tsv") with
    | .error message => return .error message
    | .ok coordinates => pure coordinates
  let coverage ←
    match ← Loam.BalanceReview.loadCoverage (dataDir / "zero-origin-coverage.loam") with
    | .error message => return .error message
    | .ok coverage => pure coverage
  let balances ←
    match Loam.BalanceReview.projectImage image coverage selection with
    | .error message => return .error message
    | .ok balances => pure balances
  let scheduled ←
    match ← Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir image.currentEvents with
    | .error message => return .error message
    | .ok scheduled => pure scheduled
  let records := Loam.ActualReview.recordsFromActualImage image
  return projectHistory
    window.start observedAt window.endExclusive
    selection balances records scheduled days

/--
Load a retrospective current-truth Daily Pace series without retaining any pace
observation. The current normalized Actual image is read once and then delegated
to `loadHistoryFromActualImageAt`.
-/
def loadHistoryAt
    (dataDir actualRoot : System.FilePath)
    (observedAt : String)
    (days : Nat) : IO (Except String (List Snapshot)) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadHistoryFromActualImageAt dataDir image observedAt days

end Loam.CycleSpendingPaceReview
