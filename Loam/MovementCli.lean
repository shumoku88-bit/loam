import Loam.ActualDate
import Loam.ActualValidityPersistence
import Loam.MovementEntry
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementCli

set_option autoImplicit false

private def historyMentionsEvent
    (history : Loam.Core.ActualValidityHistory String)
    (id : Loam.Core.EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = id)

/--
Search the bounded operational Event-id namespace used by the practical CLI.
A candidate must be unused by both Event memory and retained validity history,
so an orphan validity fact left by an interrupted validity-first publication
cannot be reused accidentally. Numeric suffixes are collision avoidance only.
-/
private def freshRecordEventIdFrom
    (memory : Loam.Core.EventMemory)
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"record-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate with
      | none =>
          if historyMentionsEvent history candidate then
            freshRecordEventIdFrom memory history (index + 1) fuel
          else
            some candidate
      | some _ => freshRecordEventIdFrom memory history (index + 1) fuel

private def freshRecordEventId?
    (memory : Loam.Core.EventMemory)
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.EventId :=
  freshRecordEventIdFrom memory history 1
    (memory.events.length + history.facts.length + 1)

private def freshValidityFactIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityFactId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityFactId :=
        ⟨"validity-" ++ toString index⟩
      match history.findFactById? candidate with
      | none => some candidate
      | some _ => freshValidityFactIdFrom history (index + 1) fuel

private def freshValidityFactId?
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.ActualValidityFactId :=
  freshValidityFactIdFrom history 1 (history.facts.length + 1)

private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Record one balanced human-facing JPY movement with one occurrence date and one
or more FROM / TO loci.

The occurrence date is retained as an identified append-only Actual-validity
fact; `Event` remains date-free. Interactive empty date input accepts the
host-local current day, while backdated recording accepts an explicit ISO date.

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
      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported actual-validity history"
          return 2
      | some history =>
          IO.println "Record one movement. Add FROM entries, then TO entries."
          match ← Loam.ActualDate.practicalOccurrenceDate with
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
                  match freshRecordEventId? memory history, freshValidityFactId? history with
                  | some eventId, some factId =>
                      match Loam.Core.Event.ofEffects? eventId effects with
                      | none =>
                          IO.eprintln "loam: could not admit generated movement event"
                          return 2
                      | some event =>
                          let fact : Loam.Core.ActualValidityFact String := {
                            id := factId
                            event := eventId
                            validOn := validOn
                          }
                          match Loam.Core.EventMemory.add? memory event, history.addFact? fact with
                          | some updatedEvents, some updatedHistory =>
                              if ← Loam.Persistence.saveActualValidityHistory?
                                  validityFile updatedHistory then
                                if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                                  IO.println
                                    ("Recorded movement: " ++ toString total ++
                                      " jpy. Date: " ++ validOn ++ ".")
                                  return 0
                                else
                                  IO.eprintln
                                    "loam: event was not published; its already-published date fact remains inert until that EventId exists"
                                  return 2
                              else
                                IO.eprintln "loam: occurrence date evidence could not be published"
                                return 2
                          | _, _ =>
                              IO.eprintln "loam: could not append movement and occurrence-date evidence"
                              return 2
                  | _, _ =>
                      IO.eprintln "loam: could not generate fresh recording identities"
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
