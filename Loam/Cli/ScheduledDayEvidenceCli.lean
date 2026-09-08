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
Movement manifest frontier as the TUI. `UNKNOWN` means only that no explicit
current-open Scheduled occurrence is retained for the queried day; it is not
`NOT_DUE`.
-/
def report (scheduledPath manifestRoot day : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate day then
    IO.eprintln "loam: Scheduled day evidence requires a real YYYY-MM-DD calendar date"
    return 2
  else
    let scheduledFile := System.FilePath.mk scheduledPath
    let root := System.FilePath.mk manifestRoot
    match ← Loam.ScheduledReview.loadEvidenceFromManifest scheduledFile root with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot =>
        match Loam.ScheduledReview.dayEvidence snapshot day with
        | .due first rest => printDue day first rest
        | .unknown =>
            IO.println ("UNKNOWN\t" ++ day)
            IO.println
              "No explicit current-open Scheduled evidence is retained for this day."
            IO.println
              "This does not establish NOT_DUE; unmaterialized future obligations remain unknown."
            return 0
        | .unknownCompletionScheduled =>
            IO.eprintln "loam: Scheduled completion refers to an unknown Scheduled identity"
            return 2
        | .unknownRetirementScheduled =>
            IO.eprintln "loam: Scheduled retirement refers to an unknown Scheduled identity"
            return 2
        | .unknownReplacementScheduled =>
            IO.eprintln "loam: Scheduled replacement refers to an unknown Scheduled identity"
            return 2
        | .invalidReplacementGraph =>
            IO.eprintln "loam: Scheduled replacement graph is cyclic or otherwise invalid"
            return 2
        | .conflictingTerminalEvidence =>
            IO.eprintln
              "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
            return 2

end Loam.ScheduledDayEvidenceCli
