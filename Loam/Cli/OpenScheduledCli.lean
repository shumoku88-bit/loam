import Loam.Cli.ScheduledBalanceCli
import Loam.Cli.ScheduledDayEvidenceCli
import Loam.ScheduledReview

namespace Loam.OpenScheduledCli

open Loam.Core

set_option autoImplicit false

private def insertByScheduledDay
    (occurrence : ScheduledOccurrence String) :
    List (ScheduledOccurrence String) → List (ScheduledOccurrence String)
  | [] => [occurrence]
  | current :: rest =>
      match compare occurrence.scheduledOn current.scheduledOn with
      | Ordering.gt => current :: insertByScheduledDay occurrence rest
      | _ => occurrence :: current :: rest

private def sortByScheduledDay
    (occurrences : List (ScheduledOccurrence String)) :
    List (ScheduledOccurrence String) :=
  occurrences.foldr insertByScheduledDay []

private def fromChanges
    (occurrence : ScheduledOccurrence String) : List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta < 0

private def toChanges
    (occurrence : ScheduledOccurrence String) : List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta > 0

private def zeroChanges
    (occurrence : ScheduledOccurrence String) : List (MovementChange LocusId) :=
  occurrence.movement.changes.filter fun change => change.quantity.quanta = 0

private def printMagnitude
    (indent : String)
    (change : MovementChange LocusId)
    (amount : Int)
    (measure : MeasureId) : IO Unit := do
  IO.println
    (indent ++ change.coordinate.token ++ ": " ++
      toString amount ++ " " ++ measure.token)

private def printMovement (occurrence : ScheduledOccurrence String) : IO Unit := do
  let sources := fromChanges occurrence
  let destinations := toChanges occurrence
  let zeros := zeroChanges occurrence
  match sources, destinations, zeros with
  | [source], [destination], [] =>
      IO.println
        ("  " ++ source.coordinate.token ++ " -> " ++ destination.coordinate.token ++ ": " ++
          toString destination.quantity.quanta ++ " " ++ occurrence.measure.token)
  | _, _, _ =>
      if !sources.isEmpty then
        IO.println "  FROM"
        for change in sources do
          printMagnitude "    " change (-change.quantity.quanta) occurrence.measure
      if !destinations.isEmpty then
        IO.println "  TO"
        for change in destinations do
          printMagnitude "    " change change.quantity.quanta occurrence.measure
      if !zeros.isEmpty then
        IO.println "  ZERO"
        for change in zeros do
          printMagnitude "    " change 0 occurrence.measure
      if occurrence.movement.changes.isEmpty then
        IO.println "  (no quantity changes)"

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  printMovement occurrence

/--
Show retained Scheduled occurrences whose expectation remains current-open.

This command consumes the same complete Scheduled lifecycle image and selected
Actual authority frontier as production TUI readers. It is deliberately
read-only; mutation is owned by the shared Scheduled publishers.
-/
def showOpenScheduled (scheduledPath actualRoot : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk actualRoot
  match ← Loam.ScheduledReview.loadEvidenceFromActual scheduledFile root with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok snapshot =>
      match Loam.ScheduledReview.currentOpenRecords snapshot with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok openOccurrences =>
          match sortByScheduledDay openOccurrences with
          | [] =>
              IO.println "No explicit current-open Scheduled movements are retained."
              IO.println
                "Missing future Scheduled rows remain Unknown; this is not evidence that no obligation is due."
              return 0
          | occurrences =>
              IO.println "Explicit current-open Scheduled movements (ordered by scheduled date):"
              for occurrence in occurrences do
                printOccurrence occurrence
              IO.println
                "Coverage: explicit Scheduled evidence only; unmaterialized future obligations remain Unknown."
              return 0

end Loam.OpenScheduledCli

def main (args : List String) : IO UInt32 :=
  match args with
  | ["day-evidence", scheduledPath, actualRoot, day] =>
      Loam.ScheduledDayEvidenceCli.report scheduledPath actualRoot day
  | ["balance-effects", rootPath, endExclusive] =>
      Loam.ScheduledBalanceCli.report rootPath endExclusive
  | [scheduledPath, actualRoot] =>
      Loam.OpenScheduledCli.showOpenScheduled scheduledPath actualRoot
  | _ => do
      IO.eprintln
        "Usage: loamOpenScheduled day-evidence SCHEDULED_FILE ACTUAL_ROOT YYYY-MM-DD | balance-effects DATA_ROOT END | SCHEDULED_FILE ACTUAL_ROOT"
      return 2
