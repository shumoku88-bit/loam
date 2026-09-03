import Loam.ActualDate
import Loam.ActualValidityPersistence
import Loam.MovementEntry
import Loam.MovementUi
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementCli

set_option autoImplicit false

private structure MovementDraft where
  validOn : String
  effects : List Loam.Core.Effect
  total : Int

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
Read the current memory before interactive input only as a convenience and
malformation preflight. The returned snapshot is never publication authority:
known Loci derived from it may be stale by the time the user finishes typing.
The publication boundary re-reads canonical state under writer ownership.
-/
private def preflightForDraft
    (memoryFile : System.FilePath) : IO (Except String Loam.Core.EventMemory) := do
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      return Except.error "loam: malformed or unsupported event-memory file"
  | some memory =>
      let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
      | none =>
          return Except.error "loam: malformed or unsupported actual-validity history"
      | some _ =>
          return Except.ok memory

private def showDraftProgress (progress : Loam.MovementUi.Progress) : IO Unit := do
  IO.println ""
  IO.println "Movement draft"
  match progress.validOn with
  | none => IO.println "  [?] occurrence date"
  | some validOn => IO.println ("  [ok] occurrence date: " ++ validOn)
  match progress.movementTotal with
  | none => IO.println "  [?] balanced FROM / TO movement"
  | some total => IO.println ("  [ok] balanced movement: " ++ toString total ++ " jpy")
  match Loam.MovementUi.obligations progress with
  | [] => IO.println "  ready to request admission"
  | pending =>
      IO.println
        ("  outstanding: " ++
          String.intercalate ", " (pending.map Loam.MovementUi.obligationLabel))

/--
Collect a complete Movement draft without holding cross-process writer
ownership across human think time.

The preflight snapshot only feeds Locus completion hints. The resulting draft is
not canonical data and carries no durable Event or validity identity yet.
-/
private def collectMovementDraft
    (memoryFile : System.FilePath) : IO (Except String MovementDraft) := do
  match ← preflightForDraft memoryFile with
  | Except.error message =>
      return Except.error message
  | Except.ok hintMemory =>
      IO.println "Record one movement. Add FROM entries, then TO entries."
      let initial : Loam.MovementUi.Progress := {}
      showDraftProgress initial
      match ← Loam.ActualDate.practicalOccurrenceDate with
      | Except.error message =>
          return Except.error message
      | Except.ok validOn =>
          let afterDate : Loam.MovementUi.Progress := { validOn := some validOn }
          showDraftProgress afterDate
          let knownLoci := Loam.CompletionPrompt.knownLoci hintMemory
          match ← Loam.MovementEntry.collectMovementEffects knownLoci with
          | Except.error message =>
              return Except.error message
          | Except.ok (effects, total) =>
              let ready : Loam.MovementUi.Progress := {
                validOn := some validOn
                movementTotal := some total
              }
              showDraftProgress ready
              return Except.ok { validOn := validOn, effects := effects, total := total }

/--
Expose only the admission boundaries that the practical movement entrance has
actually crossed before publication. This is deliberately not a generic proof
UI and does not claim balance sufficiency, accounting roles, or a Core-wide
conservation law.
-/
private def showAdmissionPreview
    (total : Int)
    (validOn : String)
    (eventId : Loam.Core.EventId)
    (factId : Loam.Core.ActualValidityFactId) : IO Unit := do
  IO.println ""
  IO.println "Admission preview"
  IO.println ("  movement: " ++ toString total ++ " jpy")
  IO.println ("  date: " ++ validOn)
  IO.println ("  event: " ++ eventId.token)
  IO.println ("  validity fact: " ++ factId.token)
  IO.println "  [ok] movement totals agree"
  IO.println "  [ok] effect identities admitted"
  IO.println "  [ok] Event identity admitted in memory"
  IO.println "  [ok] validity fact identity admitted in retained history"
  IO.println "  ready to publish"

/--
Re-read current canonical state and publish one already-collected draft while
holding the existing writer-ownership boundary.

Fresh durable identities are chosen here, not while the user is typing. This is
the practical Movement instance of the Observation 118 rule that render/input
state is not activation-time authority.
-/
private def publishDraftUnderOwnership
    (memoryPath : String)
    (draft : MovementDraft) : IO UInt32 := do
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
          match freshRecordEventId? memory history, freshValidityFactId? history with
          | some eventId, some factId =>
              match Loam.Core.Event.ofEffects? eventId draft.effects with
              | none =>
                  IO.eprintln "loam: could not admit generated movement event"
                  return 2
              | some event =>
                  let fact : Loam.Core.ActualValidityFact String := {
                    id := factId
                    event := eventId
                    validOn := draft.validOn
                  }
                  match Loam.Core.EventMemory.add? memory event, history.addFact? fact with
                  | some updatedEvents, some updatedHistory =>
                      showAdmissionPreview draft.total draft.validOn eventId factId
                      if ← Loam.Persistence.saveActualValidityHistory?
                          validityFile updatedHistory then
                        if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                          IO.println
                            ("Recorded movement: " ++ toString draft.total ++
                              " jpy. Date: " ++ draft.validOn ++ ".")
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

/--
Record one balanced human-facing JPY movement with one occurrence date and one
or more FROM / TO loci.

Interactive input is deliberately collected without writer ownership. Only once
the draft is complete does the entrance acquire ownership, re-read current
canonical state, re-run world-dependent admission, allocate fresh durable
identities, and publish.

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
  match ← collectMovementDraft memoryFile with
  | Except.error message =>
      IO.eprintln message
      return 2
  | Except.ok draft =>
      Loam.WriterOwnership.withOwnership
        memoryFile
        (publishDraftUnderOwnership memoryPath draft)

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
  | [memoryPath] => recordMovement memoryPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.MovementCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
