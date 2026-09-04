import Loam.ActualDate
import Loam.Core.HistoricalRouting
import Loam.Core.RoutingEffective
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Actual historical-routing persistence

This stream persists only the concrete Actual routing evidence selected by
Observation 111 and pressured by real household data after Observation 156:

```text
LocusId
+ effective coordinate (`initial` or `dated ISO date`)
+ Purpose? (`managed` or explicitly unmanaged)
```

It does not persist Envelope identity, Account identity, current Consumption,
Remaining, classification labels, or a generic routing-object registry.
-/

/-- Version marker for the first concrete Actual-routing stream. -/
def actualRoutingHeader : String := "LOAM-ACTUAL-ROUTING\t1"

abbrev ActualRoutingHistory := RoutingHistory LocusId (RoutingEffective String)

private def encodeActualRoutingRow?
    (entry : RoutingEntry LocusId (RoutingEffective String)) : Option String := do
  let locus := entry.subject.token
  if !validToken locus then none else
  let routeFields ←
    match entry.purpose with
    | some purpose =>
        if validToken purpose.token then
          some ["MANAGED", purpose.token]
        else
          none
    | none => some ["UNMANAGED"]
  let effectiveFields ←
    match entry.effectiveOn with
    | .initial => some ["INITIAL"]
    | .dated date =>
        if Loam.ActualDate.validIsoDate date then
          some ["FROM", date]
        else
          none
  return String.intercalate "\t" (["ROUTE", locus] ++ effectiveFields ++ routeFields)

private def decodeActualRoutingRow?
    (row : String) : Option (RoutingEntry LocusId (RoutingEffective String)) :=
  match row.splitOn "\t" with
  | ["ROUTE", locus, "INITIAL", "MANAGED", purpose] =>
      if validToken locus && validToken purpose then
        some { subject := ⟨locus⟩, effectiveOn := .initial, purpose := some ⟨purpose⟩ }
      else
        none
  | ["ROUTE", locus, "INITIAL", "UNMANAGED"] =>
      if validToken locus then
        some { subject := ⟨locus⟩, effectiveOn := .initial, purpose := none }
      else
        none
  | ["ROUTE", locus, "FROM", date, "MANAGED", purpose] =>
      if validToken locus && validToken purpose && Loam.ActualDate.validIsoDate date then
        some { subject := ⟨locus⟩, effectiveOn := .dated date, purpose := some ⟨purpose⟩ }
      else
        none
  | ["ROUTE", locus, "FROM", date, "UNMANAGED"] =>
      if validToken locus && Loam.ActualDate.validIsoDate date then
        some { subject := ⟨locus⟩, effectiveOn := .dated date, purpose := none }
      else
        none
  | _ => none

/--
Encode Actual historical routing without assigning authority to row order.
`RoutingHistory` already owns uniqueness of `(LocusId, effective coordinate)`.
-/
def encodeActualRoutingHistory? (history : ActualRoutingHistory) : Option String := do
  let rows ← history.entries.mapM encodeActualRoutingRow?
  return String.intercalate "\n" (actualRoutingHeader :: rows) ++ "\n"

/--
Decode one version-1 Actual-routing stream and re-admit duplicate-coordinate
uniqueness through `RoutingHistory.ofEntries?`.
-/
def decodeActualRoutingHistory? (input : String) : Option ActualRoutingHistory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != actualRoutingHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => do
            let entries ← reversedRows.reverse.mapM decodeActualRoutingRow?
            RoutingHistory.ofEntries? entries
        | _ => none
  | _ => none

private def actualRoutingStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one complete Actual-routing stream by sibling staging plus rename. -/
def saveActualRoutingHistory?
    (path : System.FilePath)
    (history : ActualRoutingHistory) : IO Bool := do
  match encodeActualRoutingHistory? history with
  | none => return false
  | some text =>
      let stagePath := actualRoutingStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true

/-- Read and fail-closed decode one concrete Actual-routing stream. -/
def loadActualRoutingHistory?
    (path : System.FilePath) : IO (Option ActualRoutingHistory) := do
  let input ← IO.FS.readFile path
  return decodeActualRoutingHistory? input

end Loam.Persistence
