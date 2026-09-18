import Loam.ActualDate
import Loam.ScheduledCoverageConfig
import Loam.ScheduledReview

namespace Loam.ScheduledCoverageReview

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled future coverage projection

This read-only projection compares explicit current-open Scheduled evidence with
replaceable monitoring rules. A missing cell means only "the configured coverage
expectation has no matching explicit current-open Scheduled occurrence in this
month". It is not a canonical NotDue/Due claim and it does not infer recurrence
from finite Scheduled evidence.
-/

abbrev Record := Loam.ScheduledReview.Record
abbrev Rule := Loam.ScheduledCoverageConfig.Rule

structure MonthCell where
  month : String
  expected : Bool
  explicitCount : Nat
  deriving Repr, DecidableEq

structure Row where
  rule : Rule
  cells : List MonthCell
  firstMissing : Option String
  deriving Repr, DecidableEq

structure Snapshot where
  observedAt : String
  months : List String
  rows : List Row
  deriving Repr, DecidableEq

private def padded (width value : Nat) : String :=
  let text := toString value
  String.ofList (List.replicate (width - text.length) '0') ++ text

private def monthIndex? (date : String) : Option Nat := do
  if !Loam.ActualDate.validIsoDate date then none else
    let [yearText, monthText, _] := date.splitOn "-" | none
    let year ← yearText.toNat?
    let month ← monthText.toNat?
    pure (year * 12 + (month - 1))

private def monthText (index : Nat) : String :=
  let year := index / 12
  let month := index % 12 + 1
  padded 4 year ++ "-" ++ padded 2 month

private def positiveLocusTokens (record : Record) : List String :=
  ((record.movement.changes.filterMap fun change =>
      if change.quantity.quanta > 0 then some change.coordinate.token else none).eraseDups)
    |>.mergeSort (fun left right => left <= right)

private def expectedAt (rule : Rule) (target : Nat) : Bool :=
  if rule.everyMonths = 0 then
    false
  else
    match monthIndex? rule.anchor with
    | none => false
    | some anchor =>
        decide (anchor <= target) && ((target - anchor) % rule.everyMonths == 0)

private def explicitCountAt
    (rule : Rule) (records : List Record) (target : Nat) : Nat :=
  (records.filter fun record =>
    positiveLocusTokens record == rule.positiveLoci &&
      match monthIndex? record.scheduledOn with
      | some index => index == target
      | none => false).length

private def rowFor
    (records : List Record) (indices : List Nat) (rule : Rule) : Row :=
  let cells := indices.map fun index => {
    month := monthText index
    expected := expectedAt rule index
    explicitCount := explicitCountAt rule records index
  }
  let firstMissing :=
    (cells.find? fun cell => cell.expected && cell.explicitCount == 0).map (·.month)
  { rule, cells, firstMissing }

/--
Project a finite future month grid from already-selected Scheduled records.

The first displayed month is the month after `observedAt`; this avoids treating a
current-month occurrence that has already reached terminal evidence as a future
coverage gap.
-/
def projectRecords
    (rules : List Rule) (records : List Record)
    (observedAt : String) (monthCount : Nat := 8) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate observedAt then
    throw "loam: Scheduled coverage observation must be a real YYYY-MM-DD calendar date"
  if !(records.all fun record => Loam.ActualDate.validIsoDate record.scheduledOn) then
    throw "loam: Scheduled coverage received an invalid retained Scheduled date"
  let some observedMonth := monthIndex? observedAt
    | throw "loam: Scheduled coverage could not resolve the observation month"
  let indices := (List.range monthCount).map fun offset => observedMonth + 1 + offset
  return {
    observedAt := observedAt
    months := indices.map monthText
    rows := rules.map (rowFor records indices)
  }

/--
Load canonical current-open Scheduled evidence and compare it with replaceable
coverage-monitor configuration. The config does not become Scheduled authority.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (observedAt : String) (monthCount : Nat := 8) :
    IO (Except String Snapshot) := do
  let rules ←
    try
      match ← Loam.ScheduledCoverageConfig.load?
          (dataDir / "config" / "scheduled-coverage.tsv") with
      | none => return .error "loam: Scheduled coverage config is malformed"
      | some rules => pure rules
    catch error =>
      return .error ("loam: Scheduled coverage config unreadable: " ++ error.toString)
  let evidence ←
    match ← Loam.ScheduledReview.loadHouseholdEvidence dataDir actualRoot with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let records ←
    match Loam.ScheduledReview.currentOpenRecords evidence with
    | .error message => return .error message
    | .ok records => pure records
  return projectRecords rules records observedAt monthCount

end Loam.ScheduledCoverageReview
