import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.MovementManifestAuthority

namespace Loam.ReviewCli

open Loam.Core

set_option autoImplicit false

/-- Transient presentation evidence, never persisted or used for writer admission. -/
structure Record where
  event : Event
  date : Option String
  description : String
  replacement : Option EventId
  isCurrent : Bool := true

inductive Query where
  | week (ending : String)
  | day (date : String)
  | search (text : String)
  | undated
  deriving BEq

def weekDays (ending : String) : List String :=
  (List.range 7).filterMap fun n => Loam.ActualDate.shiftDays? ending (Int.ofNat n - 6)

/-- Escape line breaks and neutralize terminal controls without changing evidence. -/
def displayText (text : String) : String :=
  (Loam.Persistence.escapeText text).map fun c =>
    if c.toNat < 32 || (c.toNat >= 127 && c.toNat < 160) then '�' else c

private def shortText (limit : Nat) (text : String) : String :=
  let text := displayText text
  if text.length <= limit then text
  else String.ofList (text.toList.take limit) ++ "…"

private def effectText (effect : Effect) : String :=
  effect.locus.token ++ ": " ++ toString effect.quantity.quanta ++ " " ++ effect.measure.token

/-- Literal search observes retained evidence, not just the elided screen text. -/
def containsText (text : String) (record : Record) : Bool :=
  let fields := [record.event.id.token, record.date.getD "", record.description] ++
    record.event.effects.flatMap fun effect =>
      [effect.locus.token, effect.measure.token, toString effect.quantity.quanta]
  fields.any fun field => (field.toLower.splitOn text.toLower).length > 1

/-- Daily views are current; search explicitly includes marked correction history. -/
def select (records : List Record) (query : Query) : List Record :=
  let days := match query with
    | .week ending => weekDays ending
    | _ => []
  let selected := records.filter fun record =>
    match query with
    | .search text => containsText text record
    | .undated => record.isCurrent && record.date.isNone
    | .day date => record.isCurrent && record.date == some date
    | .week _ => record.isCurrent && (record.date.any fun date => date ∈ days)
  selected.mergeSort fun a b =>
    if a.date == b.date then a.event.id.token <= b.event.id.token
    else a.date.getD "" > b.date.getD ""

private def correctionLabel (record : Record) : String :=
  match record.replacement with
  | some id => "  [corrected -> #" ++ displayText id.token ++ "]"
  | none => ""

def summary (record : Record) : String :=
  let effects := record.event.effects
  let lines := effects.take 2 |>.map fun effect =>
    shortText 24 effect.locus.token ++ ": " ++ toString effect.quantity.quanta ++
      " " ++ shortText 12 effect.measure.token
  let more := if effects.length > 2 then "  (+" ++ toString (effects.length - 2) ++ " effects; detail)" else ""
  let description := if record.description.isEmpty then "(no description)" else shortText 36 record.description
  description ++ "  | " ++
    (if effects.isEmpty then "(no quantity effects)" else String.intercalate "; " lines) ++
    more ++ correctionLabel record

private def detail (records : List Record) (record : Record) : IO Unit := do
  IO.println (record.date.getD "date unknown" ++ "  " ++
    (if record.description.isEmpty then "" else displayText record.description ++ "  ") ++
    "[" ++ displayText record.event.id.token ++ "]" ++ correctionLabel record)
  for original in records.filter (fun r => r.replacement == some record.event.id) do
    IO.println ("  corrects #" ++ displayText original.event.id.token)
  if record.event.effects.isEmpty then IO.println "  (no quantity effects)"
  for effect in record.event.effects do
    IO.println ("  " ++ displayText (effectText effect))

private def loadOrEmpty {α : Type} (path : System.FilePath)
    (loader : System.FilePath → IO (Option α)) (empty : α) : IO (Option α) := do
  if ← path.pathExists then loader path else return some empty

private structure ReviewMovementWorld where
  events : EventMemory
  validity : Loam.Core.ActualValidityHistory String
  descriptions : EventDescriptionMemory

/--
Load the Movement families from exactly one authority backend.

Without a manifest root, review retains the sidecar behavior used by isolated
regression fixtures. With `LOAM_MOVEMENT_MANIFEST_ROOT`, the selected manifest
generation supplies Event, ActualValidity, and EventDescription evidence;
`loadSelectedWorld?` also verifies the selected RelationUnit and
RelationDischarge objects before review continues. There is no fallback to
sidecars when selected manifest authority is unavailable.
-/
private def loadReviewMovementWorld?
    (memoryFile : System.FilePath) : IO (Except String ReviewMovementWorld) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? (System.FilePath.mk rootPath) with
      | .error message => return .error message
      | .ok world =>
          return .ok {
            events := world.events
            validity := world.validity
            descriptions := world.descriptions
          }
  | none =>
      if !(← memoryFile.pathExists) then
        return .error ("loam: file not found: " ++ memoryFile.toString)
      let some memory ← Loam.Persistence.loadEventMemory? memoryFile
        | return .error "loam: malformed or unsupported event-memory file"
      let some history ← Loam.Persistence.loadActualValidityHistoryOrEmpty?
          (Loam.Persistence.actualValidityPathForEventMemory memoryFile)
        | return .error "loam: malformed or unsupported actual-validity history"
      let some descriptions ← loadOrEmpty
          (Loam.Persistence.eventDescriptionPathForEventMemory memoryFile)
          Loam.Persistence.loadEventDescriptionMemory? EventDescriptionMemory.empty
        | return .error "loam: malformed or unsupported event-description memory"
      return .ok {
        events := memory
        validity := history
        descriptions := descriptions
      }

/-- Admit the whole evidence before filtering; a quiet view must not hide refusal. -/
private def loadRecords (memoryPath : String) (correctionPath : Option String) :
    IO (Except String (List Record)) := do
  let memoryFile := System.FilePath.mk memoryPath
  let world ←
    match ← loadReviewMovementWorld? memoryFile with
    | .error message => return .error message
    | .ok world => pure world
  let emptyCorrections : EventCorrectionMemory := { corrections := [], idNodup := by simp }
  let loadedCorrections ← match correctionPath with
    | some path =>
        loadOrEmpty (System.FilePath.mk path) Loam.Persistence.loadEventCorrectionMemory? emptyCorrections
    | none => pure (some emptyCorrections)
  let some corrections := loadedCorrections
    | return .error "loam: malformed or unsupported correction-memory file"
  let some frontier := Loam.Application.correctionFrontierMemory? world.events corrections
    | return .error "loam: movement corrections do not justify one current record frontier"
  let some validities := Loam.Application.admittedActualValidityMemory? world.validity
    | return .error "loam: actual-validity corrections do not justify one current date per event"
  return .ok (world.events.events.map fun event => {
    event := event
    date := validities.findByEventId? event.id
    description := (world.descriptions.findText? event.id).getD ""
    replacement := (corrections.corrections.find? fun c => c.target == event.id).map (·.replacement)
    isCurrent := (frontier.findById? event.id).isSome
  })

/-- Explicit raw inspection, separate from the ordinary correction-aware review. -/
def reviewRawEvents (memoryPath : String) : IO UInt32 := do
  match ← loadRecords memoryPath none with
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
    match ← loadRecords memoryPath (some correctionPath) with
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
  match ← loadRecords memoryPath (some correctionPath) with
  | .error message => IO.eprintln message; return 2
  | .ok records =>
      if (← (← IO.getStdin).isTty) && (← (← IO.getStdout).isTty) then
        browse memoryPath correctionPath today records query
      else
        let _ ← showPage records query 0
        return 0

end Loam.ReviewCli
