import Loam.ActualDate
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

/--
Load the current explicit boundary, Daily Pace pool, current balances, and
current-open Scheduled evidence.

Balance and Scheduled lifecycle interpretation remain owned by their existing
shared readers. This boundary introduces no new canonical state.
-/
def loadSnapshotAt
    (dataDir actualRoot : System.FilePath)
    (observedAt : String) : IO (Except String Snapshot) := do
  let window ←
    match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
    | .error message => return .error message
    | .ok window => pure window
  let selection ←
    match ← Loam.DailyPaceConfig.load (dataDir / "config" / "daily-pace.tsv") with
    | .error message => return .error message
    | .ok coordinates => pure coordinates
  let evidence ←
    match ← Loam.BalanceReview.loadEvidence dataDir actualRoot with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let balances ←
    match Loam.BalanceReview.project
        evidence.events evidence.corrections evidence.coverage selection with
    | .error message => return .error message
    | .ok balances => pure balances
  let scheduled ←
    match ← Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir evidence.events with
    | .error message => return .error message
    | .ok scheduled => pure scheduled
  return project observedAt window.endExclusive selection balances scheduled

end Loam.CycleSpendingPaceReview
