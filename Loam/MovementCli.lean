import Loam.ActualDate
import Loam.ActualValidityPersistence
import Loam.MovementEntry
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementCli

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def validateOccurrenceDate (text : String) : Except String String :=
  if Loam.ActualDate.validIsoDate text then
    Except.ok text
  else
    Except.error "loam: date must be a real calendar date in YYYY-MM-DD form"

private def defaultOccurrenceDate : IO (Except String String) := do
  match ← Loam.ActualDate.todayIso? with
  | some today => return Except.ok today
  | none =>
      return Except.error
        "loam: could not determine the local date; set LOAM_OCCURRENCE_DATE=YYYY-MM-DD"

/--
Choose the practical occurrence date with no unnecessary scripted input.

On a real terminal the user sees `Date [today]:` and may press Enter for today
or enter another ISO day. Redirected/scripted callers do not consume an extra
stdin line: they may set `LOAM_OCCURRENCE_DATE`, otherwise the host-local current
day is used. This keeps interactive backdating explicit without breaking the
existing movement stream shape used by automation.
-/
private def occurrenceDate : IO (Except String String) := do
  let stdin ← IO.getStdin
  if !(← stdin.isTty) then
    match ← IO.getEnv "LOAM_OCCURRENCE_DATE" with
    | some configured => return validateOccurrenceDate configured
    | none => defaultOccurrenceDate
  else
    match ← Loam.ActualDate.todayIso? with
    | some today =>
        let entered ← promptLine ("Date [" ++ today ++ "]: ")
        if entered.isEmpty then
          return Except.ok today
        else
          return validateOccurrenceDate entered
    | none =>
        let entered ← promptLine "Date (YYYY-MM-DD): "
        return validateOccurrenceDate entered

/--
Search the bounded operational Event-id namespace used by the practical CLI.
A candidate must be unused by both Event memory and retained validity evidence,
so an orphan validity left by an interrupted validity-first publication cannot
block a later retry. The numeric suffix is collision avoidance only and has no
temporal meaning.
-/
private def freshRecordEventIdFrom
    (memory : Loam.Core.EventMemory)
    (validities : Loam.Core.ActualValidityMemory String) :
    Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"record-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate,
          Loam.Core.ActualValidityMemory.findByEventId? validities candidate with
      | none, none => some candidate
      | _, _ => freshRecordEventIdFrom memory validities (index + 1) fuel

private def freshRecordEventId?
    (memory : Loam.Core.EventMemory)
    (validities : Loam.Core.ActualValidityMemory String) : Option Loam.Core.EventId :=
  freshRecordEventIdFrom memory validities 1
    (memory.events.length + validities.entries.length + 1)

private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Record one balanced human-facing JPY movement with one occurrence date and one
or more FROM / TO loci.

The occurrence date is retained as separate `ActualValidity String` evidence;
`Event` remains date-free. Interactive empty date input accepts the host-local
current day, while backdated recording accepts an explicit ISO date.

The entrance requires the two entered totals to agree, then persists one generic
Event containing negative Effects for the FROM side and positive Effects for the
TO side. This is an adapter-level shape only. It does not add Account,
ExpenseCategory, EventKind, debit/credit, Transfer, Income, Spending, or a global
conservation law to Core.
-/
def recordMovement (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      match ← Loam.Persistence.loadActualValidityMemoryOrEmpty? validityFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported actual-validity file"
          return 2
      | some validities =>
          IO.println "Record one movement. Add FROM entries, then TO entries."
          match ← occurrenceDate with
          | Except.error message =>
              IO.eprintln message
              return 2
          | Except.ok validOn =>
              let knownLoci := Loam.CompletionPrompt.knownLoci memory
              match ← Loam.MovementEntry.collectMovementEffects knownLoci with
              | Except.error message =>
                  IO.eprintln message
                  return 2
              | Except.ok (effects, total) =>
                  match freshRecordEventId? memory validities with
                  | none =>
                      IO.eprintln "loam: could not generate a fresh event identity"
                      return 2
                  | some eventId =>
                      match Loam.Core.Event.ofEffects? eventId effects with
                      | none =>
                          IO.eprintln "loam: could not admit generated movement event"
                          return 2
                      | some event =>
                          match Loam.Core.EventMemory.add? memory event,
                              Loam.Core.ActualValidityMemory.ofEntries?
                                (validities.entries ++ [{ event := eventId, validOn := validOn }]) with
                          | some updatedEvents, some updatedValidities =>
                              if ← Loam.Persistence.saveActualValidityMemory?
                                  validityFile updatedValidities then
                                if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                                  IO.println
                                    ("Recorded movement: " ++ toString total ++
                                      " jpy. Date: " ++ validOn ++ ".")
                                  return 0
                                else
                                  IO.eprintln
                                    "loam: event was not published; its already-published date evidence remains inert until that EventId exists"
                                  return 2
                              else
                                IO.eprintln "loam: occurrence date evidence could not be published"
                                return 2
                          | _, _ =>
                              IO.eprintln "loam: could not append movement and occurrence-date evidence"
                              return 2

private def usage : String :=
  "Record one balanced JPY movement:\n" ++
  "  ./tools/loam movement MEMORY_FILE\n\n" ++
  "Interactive recording: press Enter at Date [today] to use today, or enter YYYY-MM-DD.\n" ++
  "Scripted recording: set LOAM_OCCURRENCE_DATE=YYYY-MM-DD to backdate; otherwise today is used.\n" ++
  "Enter one or more FROM loci and amounts, blank the next FROM locus, then\n" ++
  "enter one or more TO loci and amounts and blank the next TO locus.\n" ++
  "The FROM and TO totals must match exactly."

def run (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk memoryPath)
        (recordMovement memoryPath)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.MovementCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
