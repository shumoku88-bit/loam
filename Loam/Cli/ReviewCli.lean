import Loam.ActualReview

namespace Loam.ReviewCli

open Loam.Core Loam.ActualReview

set_option autoImplicit false

private def detail (records : List Record) (record : Record) : IO Unit := do
  for line in detailLines records record do
    IO.println line

/-- Explicit raw inspection, separate from the ordinary correction-aware review. -/
def reviewRawEvents (memoryPath : String) : IO UInt32 := do
  match ← Loam.ActualReview.loadRecords memoryPath none with
  | .error message => IO.eprintln message; return 2
  | .ok records =>
      IO.println "Recorded facts (all raw Events; current occurrence dates; display order has no time meaning):"
      if records.isEmpty then IO.println "No recorded events."
      for record in records do detail records record
      return 0

private def queryLabel : Query → String
  | .week ending => "Week through " ++ ending ++ " (occurrence dates, not entry time)"
  | .day date => "Day " ++ date ++ " (occurrence date, not entry time)"
  | .search text => "Search all recorded Events, all dates + correction history: " ++ shortText 60 text
  | .undated => "Current records with date unknown"

def parseQuery (today text : String) : Option Query :=
  if text == "t" then some (.week today)
  else if text == "u" then some .undated
  else if Loam.ActualDate.validIsoDate text then some (.day text)
  else if text.startsWith "/" && text.length > 1 then
    some (.search (String.ofList (text.toList.drop 1)))
  else none

private def moveWindow (query : Query) (offset : Int) : Option Query :=
  match query with
  | .week ending => (Loam.ActualDate.shiftDays? ending offset).map Query.week
  | .day date => (Loam.ActualDate.shiftDays? date offset).map Query.day
  | _ => none

private def pageSize : Nat := 10

private def showPage (records : List Record) (query : Query) (offset : Nat) : IO (List Record) := do
  IO.println ("\n" ++ queryLabel query)
  let undated := (select records .undated).length
  IO.println ("Date unknown (current): " ++ toString undated ++ " (u). Snapshot; r reload.")
  let days := match query with
    | .week ending | .day ending => weekDays ending
    | _ => []
  if !days.isEmpty then
    IO.println (String.intercalate "  " (days.map fun date =>
      String.ofList (date.toList.drop 5) ++ ":" ++ toString (select records (.day date)).length))
  let selected := select records query
  let page := (selected.drop offset).take pageSize
  if selected.isEmpty then
    IO.println "No matches in this scope; this does not prove something was never recorded."
  else
    IO.println ("Showing " ++ toString (offset + 1) ++ "-" ++ toString (offset + page.length) ++
      " of " ++ toString selected.length ++ " matches.")
  let mut previousDate : Option String := none
  for (record, index) in page.zipIdx do
    let date := record.date.getD "date unknown"
    if previousDate != some date then IO.println date
    previousDate := some date
    IO.println ("  " ++ toString (index + 1) ++ ". " ++ summary record)
  return page

private def help : String :=
  "YYYY-MM-DD day | p/n +/-week | t recent | /text search all | u undated\n" ++
  "1-10 detail | #EventId raw detail | more/back | r reload | q return"

private def promptLine : IO String := do
  IO.print "> "
  (← IO.getStdout).flush
  return (← (← IO.getStdin).getLine).trimAscii.toString

private partial def browse (memoryPath correctionPath today : String)
    (records : List Record) (query : Query) (offset : Nat := 0) : IO UInt32 := do
  let page ← showPage records query offset
  IO.println help
  let input ← promptLine
  if input.isEmpty || input == "q" then return 0
  if input == "r" then
    match ← Loam.ActualReview.loadRecords memoryPath (some correctionPath) with
    | .error message => IO.eprintln message; return 2
    | .ok fresh => return ← browse memoryPath correctionPath today fresh query
  let mut next := query
  let mut start := offset
  if let some selected := parseQuery today input then
    next := selected
    start := 0
  else if input == "p" || input == "n" then
    match moveWindow query (if input == "p" then -7 else 7) with
    | some moved => next := moved; start := 0
    | none => IO.eprintln "loam: choose a date first, or calendar boundary reached"
  else if input == "more" then
    if offset + pageSize < (select records query).length then start := offset + pageSize
  else if input == "back" then
    start := offset - pageSize
  else
    let selected := if input.startsWith "#" then
        records.find? fun record => record.event.id.token == String.ofList (input.toList.drop 1)
      else do
        let number ← input.toNat?
        if number == 0 then none else page[number - 1]?
    match selected with
    | none => IO.eprintln "loam: choose a displayed number, date, or /search"
    | some record =>
        IO.println ""
        detail records record
        IO.println "Enter for the list; q return."
        if (← promptLine) == "q" then return 0
  browse memoryPath correctionPath today records next start

/-- Read-only, bounded review. Redirected input is never consumed by browsing. -/
def review (memoryPath correctionPath : String) (queryText : Option String := none) : IO UInt32 := do
  let some today ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local date"; return 2
  let some query := parseQuery today (queryText.getD "t")
    | IO.eprintln "loam: review expects YYYY-MM-DD, /text, u (undated), or t (recent week)"; return 2
  match ← Loam.ActualReview.loadRecords memoryPath (some correctionPath) with
  | .error message => IO.eprintln message; return 2
  | .ok records =>
      if (← (← IO.getStdin).isTty) && (← (← IO.getStdout).isTty) then
        browse memoryPath correctionPath today records query
      else
        let _ ← showPage records query 0
        return 0

end Loam.ReviewCli
