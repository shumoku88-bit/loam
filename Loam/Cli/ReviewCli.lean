import Loam.ActualReview

namespace Loam.ReviewCli

open Loam.Core Loam.ActualReview

set_option autoImplicit false

private def detail (records : List Record) (record : Record) : IO Unit := do
  for line in detailLines records record do
    IO.println line

/-- Explicit raw inspection, separate from the ordinary correction-aware review. -/
def reviewRawEvents (memoryPath : String) : IO UInt32 := do
  match ← Loam.ActualReview.loadRecords memoryPath with
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

private def pageSize : Nat := 10

private def showResult (records : List Record) (query : Query) : IO Unit := do
  IO.println ("\n" ++ queryLabel query)
  let undated := (select records .undated).length
  IO.println ("Date unknown (current): " ++ toString undated ++ ".")
  let days := match query with
    | .week ending | .day ending => weekDays ending
    | _ => []
  if !days.isEmpty then
    IO.println (String.intercalate "  " (days.map fun date =>
      String.ofList (date.toList.drop 5) ++ ":" ++ toString (select records (.day date)).length))
  let selected := select records query
  let page := selected.take pageSize
  if selected.isEmpty then
    IO.println "No matches in this scope; this does not prove something was never recorded."
  else
    IO.println ("Showing 1-" ++ toString page.length ++
      " of " ++ toString selected.length ++ " matches.")
  let mut previousDate : Option String := none
  for (record, index) in page.zipIdx do
    let date := record.date.getD "date unknown"
    if previousDate != some date then IO.println date
    previousDate := some date
    let num := toString (index + 1)
    let padded := if num.length < 2 then " " ++ num else num
    IO.println ("  " ++ padded ++ ". " ++ summary record)

/-- Read-only, bounded one-shot review. Standard input is never consumed. -/
def review (memoryPath _correctionPath : String) (queryText : Option String := none) : IO UInt32 := do
  let some today ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local date"; return 2
  let some query := parseQuery today (queryText.getD "t")
    | IO.eprintln "loam: review expects YYYY-MM-DD, /text, u (undated), or t (recent week)"; return 2
  match ← Loam.ActualReview.loadRecords memoryPath with
  | .error message => IO.eprintln message; return 2
  | .ok records =>
      showResult records query
      return 0

end Loam.ReviewCli
