import Loam.ActualDate
import Loam.ScheduledReview

namespace Loam.ScheduledDayEvidenceCli

open Loam.Core

set_option autoImplicit false

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println
    ("SCHEDULED\t" ++ occurrence.id.token ++ "\t" ++ occurrence.scheduledOn ++
      "\t" ++ occurrence.measure.token)
  for change in occurrence.movement.changes do
    IO.println
      ("CHANGE\t" ++ change.coordinate.token ++ "\t" ++
        toString change.quantity.quanta)

private def printDue
    (day : String)
    (first : ScheduledOccurrence String)
    (rest : List (ScheduledOccurrence String)) : IO UInt32 := do
  IO.println ("DUE\t" ++ day)
  printOccurrence first
  for occurrence in rest do
    printOccurrence occurrence
  return 0

/--
Print one exact-day open-world Scheduled answer for machine or AI consumers.

Production reads use the same complete Scheduled lifecycle image and selected
Actual authority frontier as the TUI. `UNKNOWN` means only that no explicit
current-open Scheduled occurrence is retained for the queried day; it is not
`NOT_DUE`.
-/
def report (scheduledPath actualRoot day : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate day then
    IO.eprintln "loam: Scheduled day evidence requires a real YYYY-MM-DD calendar date"
    return 2
  else
    let scheduledFile := System.FilePath.mk scheduledPath
    let root := System.FilePath.mk actualRoot
    match ← Loam.ScheduledReview.loadEvidenceFromActual scheduledFile root with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot =>
        match Loam.ScheduledReview.dayEvidence snapshot day with
        | .error message =>
            IO.eprintln message
            return 2
        | .ok (.due first rest) => printDue day first rest
        | .ok .unknown =>
            IO.println ("UNKNOWN\t" ++ day)
            IO.println
              "No explicit current-open Scheduled evidence is retained for this day."
            IO.println
              "This does not establish NOT_DUE; unmaterialized future obligations remain unknown."
            return 0

end Loam.ScheduledDayEvidenceCli
