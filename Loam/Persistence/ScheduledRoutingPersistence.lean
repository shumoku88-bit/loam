import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Scheduled historical-routing persistence

This stream is the practical persistence adapter for the Scheduled routing
coordinate qualified by Observations 107 and 153:

```text
ScheduledId × LocusId
+ dated effective coordinate
+ Purpose? (`managed` or explicitly unmanaged)
```

It deliberately reuses `RoutingHistory` for duplicate-coordinate admission and
latest-visible selection, while keeping Scheduled syntax and authority separate
from Actual routing. It does not persist Commitment, Remaining, Headroom,
Envelope identity, or a generic routing registry.
-/

/-- Version marker for the first concrete Scheduled-routing stream. -/
def scheduledRoutingHeader : String := "LOAM-SCHEDULED-ROUTING\t1"

private def encodeScheduledRoutingRow?
    (entry : RoutingEntry ScheduledRoutingSubject String) : Option String := do
  let scheduled := entry.subject.scheduled.token
  let locus := entry.subject.locus.token
  let date := entry.effectiveOn
  if !validToken scheduled || !validToken locus || !Loam.ActualDate.validIsoDate date then
    none
  else
    match entry.purpose with
    | some purpose =>
        if validToken purpose.token then
          some (String.intercalate "\t"
            ["ROUTE", scheduled, locus, "FROM", date, "MANAGED", purpose.token])
        else
          none
    | none =>
        some (String.intercalate "\t"
          ["ROUTE", scheduled, locus, "FROM", date, "UNMANAGED"])

private def decodeScheduledRoutingRow?
    (row : String) : Option (RoutingEntry ScheduledRoutingSubject String) :=
  match row.splitOn "\t" with
  | ["ROUTE", scheduled, locus, "FROM", date, "MANAGED", purpose] =>
      if validToken scheduled && validToken locus && validToken purpose &&
          Loam.ActualDate.validIsoDate date then
        some {
          subject := { scheduled := ⟨scheduled⟩, locus := ⟨locus⟩ }
          effectiveOn := date
          purpose := some ⟨purpose⟩
        }
      else
        none
  | ["ROUTE", scheduled, locus, "FROM", date, "UNMANAGED"] =>
      if validToken scheduled && validToken locus && Loam.ActualDate.validIsoDate date then
        some {
          subject := { scheduled := ⟨scheduled⟩, locus := ⟨locus⟩ }
          effectiveOn := date
          purpose := none
        }
      else
        none
  | _ => none

/-- Encode Scheduled routing without assigning authority to row order. -/
def encodeScheduledRoutingHistory?
    (history : ScheduledRoutingHistory String) : Option String := do
  let rows ← history.entries.mapM encodeScheduledRoutingRow?
  return String.intercalate "\n" (scheduledRoutingHeader :: rows) ++ "\n"

/-- Decode and re-admit duplicate `(ScheduledId × LocusId, date)` coordinates. -/
def decodeScheduledRoutingHistory?
    (input : String) : Option (ScheduledRoutingHistory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != scheduledRoutingHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => do
            let entries ← reversedRows.reverse.mapM decodeScheduledRoutingRow?
            RoutingHistory.ofEntries? entries
        | _ => none
  | _ => none

private def scheduledRoutingStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one complete Scheduled-routing stream by sibling staging plus rename. -/
def saveScheduledRoutingHistory?
    (path : System.FilePath)
    (history : ScheduledRoutingHistory String) : IO Bool := do
  match encodeScheduledRoutingHistory? history with
  | none => return false
  | some text =>
      let stagePath := scheduledRoutingStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one concrete Scheduled-routing stream. -/
def loadScheduledRoutingHistory?
    (path : System.FilePath) : IO (Option (ScheduledRoutingHistory String)) := do
  let input ← IO.FS.readFile path
  return decodeScheduledRoutingHistory? input

end Loam.Persistence
