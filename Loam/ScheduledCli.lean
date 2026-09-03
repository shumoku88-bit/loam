import Loam.ActualDate
import Loam.ActualValidityPersistence
import Loam.CompletionPrompt
import Loam.MovementEntry
import Loam.ScheduledCompletionPersistence
import Loam.ScheduledPersistence
import Loam.WriterOwnership
import Std

namespace Loam.ScheduledCli

open Loam.Core

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def loadEventMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return EventMemory.ofEvents? []

private def freshScheduledIdFrom
    (memory : ScheduledMemory String) : Nat → Nat → Option ScheduledId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : ScheduledId := ⟨"scheduled-" ++ toString index⟩
      match ScheduledMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshScheduledIdFrom memory (index + 1) fuel

private def freshScheduledId?
    (memory : ScheduledMemory String) : Option ScheduledId :=
  freshScheduledIdFrom memory 1 (memory.occurrences.length + 1)

private def addLocusIfAbsent (loci : List String) (locus : String) : List String :=
  if locus ∈ loci then loci else loci ++ [locus]

private def knownScheduledLoci (memory : ScheduledMemory String) : List String :=
  memory.occurrences.foldl
    (fun loci occurrence =>
      occurrence.movement.changes.foldl
        (fun current change => addLocusIfAbsent current change.coordinate.token)
        loci)
    []

private def knownCompletionLoci
    (scheduledMemory : ScheduledMemory String)
    (eventMemory : EventMemory) : List String :=
  (knownScheduledLoci scheduledMemory).foldl
    addLocusIfAbsent
    (Loam.CompletionPrompt.knownLoci eventMemory)

private def scheduledFromEffects?
    (id : ScheduledId)
    (scheduledOn : String)
    (effects : List Effect) : Option (ScheduledOccurrence String) := do
  if !Loam.ActualDate.validIsoDate scheduledOn then
    none
  else if effects.any (fun effect => effect.measure != ⟨"jpy"⟩) then
    none
  else
    let changes : List (MovementChange LocusId) :=
      effects.map fun effect =>
        { coordinate := effect.locus, quantity := effect.quantity }
    let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
    pure { id := id, scheduledOn := scheduledOn, movement := movement }

private def recordScheduledUnlocked (scheduledPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  match ← loadScheduledMemoryOrEmpty? scheduledFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported scheduled file"
      return 2
  | some memory =>
      let day ← promptLine "Scheduled date (YYYY-MM-DD): "
      if !Loam.ActualDate.validIsoDate day then
        IO.eprintln "loam: scheduled date must be a real calendar date in YYYY-MM-DD form"
        return 2
      else
        IO.println "Enter the expected movement. Add FROM entries, then TO entries."
        match ← Loam.MovementEntry.collectMovementEffects (knownScheduledLoci memory) with
        | Except.error message =>
            IO.eprintln message
            return 2
        | Except.ok (effects, total) =>
            match freshScheduledId? memory with
            | none =>
                IO.eprintln "loam: could not generate a fresh scheduled identity"
                return 2
            | some scheduledId =>
                match scheduledFromEffects? scheduledId day effects with
                | none =>
                    IO.eprintln "loam: expected movement could not be admitted"
                    return 2
                | some occurrence =>
                    match ScheduledMemory.add? memory occurrence with
                    | none =>
                        IO.eprintln "loam: generated scheduled identity already remembered"
                        return 2
                    | some updated =>
                        if ← Loam.Persistence.saveScheduledMemory? scheduledFile updated then
                          IO.println
                            ("Scheduled movement recorded: " ++ scheduledId.token ++
                              " on " ++ day ++ " = " ++ toString total ++ " jpy.")
                          return 0
                        else
                          IO.eprintln "loam: scheduled movement could not be published"
                          return 2

/-- Add one Scheduled occurrence under scheduled-file writer ownership. -/
def recordScheduled (scheduledPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk scheduledPath)
    (recordScheduledUnlocked scheduledPath)

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  for change in occurrence.movement.changes do
    IO.println
      ("  " ++ change.coordinate.token ++ ": " ++
        toString change.quantity.quanta ++ " " ++ occurrence.measure.token)

/-- Show retained Scheduled occurrences without treating file order as chronology. -/
def showScheduled (scheduledPath : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  match ← loadScheduledMemoryOrEmpty? scheduledFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported scheduled file"
      return 2
  | some memory =>
      match memory.occurrences with
      | [] =>
          IO.println "No scheduled movements."
          return 0
      | occurrences =>
          IO.println "Scheduled movements (each date is explicit; display order has no time meaning):"
          for occurrence in occurrences do
            printOccurrence occurrence
          return 0

private def completionEventId (scheduled : ScheduledId) : EventId :=
  ⟨"scheduled-completion:" ++ scheduled.token⟩

private def completionValidityFactId (scheduled : ScheduledId) : ActualValidityFactId :=
  ⟨"scheduled-completion-validity:" ++ scheduled.token⟩

private def historyMentionsEvent
    (history : ActualValidityHistory String)
    (eventId : EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = eventId)

private def completionReferencesKnownScheduled
    (scheduledMemory : ScheduledMemory String)
    (completionMemory : ScheduledCompletionMemory) : Bool :=
  completionMemory.completions.all fun completion =>
    match ScheduledMemory.findById? scheduledMemory completion.scheduled with
    | some _ => true
    | none => false

private def completeScheduledUnlocked
    (scheduledPath memoryPath scheduledToken : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let memoryFile := System.FilePath.mk memoryPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile

  if !(← scheduledFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ scheduledPath)
    return 2
  else
    match ← Loam.Persistence.loadScheduledMemory? scheduledFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported scheduled file"
        return 2
    | some scheduledMemory =>
        let scheduledId : ScheduledId := ⟨scheduledToken⟩
        match ScheduledMemory.findById? scheduledMemory scheduledId with
        | none =>
            IO.eprintln "loam: scheduled identity not found"
            return 1
        | some occurrence =>
            match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported scheduled-completion file"
                return 2
            | some completionMemory =>
                if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                  IO.eprintln "loam: scheduled-completion file refers to an unknown Scheduled identity"
                  return 2
                else
                  match ← loadEventMemoryOrEmpty? memoryFile with
                  | none =>
                      IO.eprintln "loam: malformed or unsupported event-memory file"
                      return 2
                  | some eventMemory =>
                      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
                      | none =>
                          IO.eprintln "loam: malformed or unsupported actual-validity history"
                          return 2
                      | some history =>
                          let existingCompletion :=
                            ScheduledCompletionMemory.findByScheduled? completionMemory scheduledId
                          let actualId :=
                            match existingCompletion with
                            | some completion => completion.actual
                            | none => completionEventId scheduledId
                          let factId := completionValidityFactId scheduledId
                          let existingFact := history.findFactById? factId

                          match EventMemory.findById? eventMemory actualId with
                          | some _ =>
                              match existingCompletion, existingFact with
                              | some _, some fact =>
                                  if fact.event = actualId then
                                    IO.println
                                      ("Scheduled movement already completed: " ++
                                        scheduledId.token ++ " -> " ++ actualId.token ++ ".")
                                    return 1
                                  else
                                    IO.eprintln
                                      "loam: completion Event exists but retained completion-date evidence points elsewhere"
                                    return 2
                              | _, _ =>
                                  IO.eprintln
                                    "loam: completion Event identity already exists without the expected completion evidence"
                                  return 2
                          | none =>
                              if existingCompletion.isNone &&
                                  (historyMentionsEvent history actualId ||
                                    (ScheduledCompletionMemory.findByActual? completionMemory actualId).isSome) then
                                IO.eprintln
                                  "loam: generated completion Event identity collides with retained evidence"
                                return 2
                              else
                                let validOnResult ←
                                  match existingFact with
                                  | some fact =>
                                      if fact.event = actualId then
                                        IO.println
                                          ("Using retained Actual date from interrupted completion: " ++
                                            fact.validOn)
                                        pure (Except.ok fact.validOn)
                                      else
                                        pure
                                          (Except.error
                                            "loam: retained completion-date identity points to another Event")
                                  | none =>
                                      if historyMentionsEvent history actualId then
                                        pure
                                          (Except.error
                                            "loam: completion Event identity already has unrelated date evidence")
                                      else
                                        Loam.ActualDate.practicalOccurrenceDate
                                match validOnResult with
                                | Except.error message =>
                                    IO.eprintln message
                                    return 2
                                | Except.ok validOn =>
                                    IO.println "Scheduled expectation:"
                                    printOccurrence occurrence
                                    IO.println "Enter what actually happened. Add FROM entries, then TO entries."
                                    match ← Loam.MovementEntry.collectMovementEffects
                                        (knownCompletionLoci scheduledMemory eventMemory) with
                                    | Except.error message =>
                                        IO.eprintln message
                                        return 2
                                    | Except.ok (effects, total) =>
                                        match Event.ofEffects? actualId effects with
                                        | none =>
                                            IO.eprintln "loam: could not admit generated completion Event"
                                            return 2
                                        | some event =>
                                            let completion : ScheduledCompletion := {
                                              scheduled := scheduledId
                                              actual := actualId
                                            }
                                            let fact : ActualValidityFact String := {
                                              id := factId
                                              event := actualId
                                              validOn := validOn
                                            }
                                            let updatedCompletions? :=
                                              match existingCompletion with
                                              | some _ => some completionMemory
                                              | none => completionMemory.add? completion
                                            let updatedHistory? :=
                                              match existingFact with
                                              | some _ => some history
                                              | none => history.addFact? fact
                                            match updatedCompletions?, updatedHistory?,
                                                EventMemory.add? eventMemory event with
                                            | some updatedCompletions, some updatedHistory,
                                                some updatedEvents =>
                                                match existingCompletion with
                                                | none =>
                                                    if !(← Loam.Persistence.saveScheduledCompletionMemory?
                                                        completionFile updatedCompletions) then
                                                      IO.eprintln
                                                        "loam: completion relation could not be published"
                                                      return 2
                                                | some _ => pure ()
                                                match existingFact with
                                                | none =>
                                                    if !(← Loam.Persistence.saveActualValidityHistory?
                                                        validityFile updatedHistory) then
                                                      IO.eprintln
                                                        "loam: Actual date was not published; the already-published completion relation remains inert"
                                                      return 2
                                                | some _ => pure ()
                                                if ← Loam.Persistence.saveEventMemory?
                                                    memoryFile updatedEvents then
                                                  IO.println
                                                    ("Completed scheduled movement: " ++
                                                      scheduledId.token ++ " -> " ++ actualId.token ++
                                                      ", " ++ toString total ++ " jpy. Date: " ++
                                                      validOn ++ ".")
                                                  return 0
                                                else
                                                  IO.eprintln
                                                    "loam: Actual Event was not published; retained completion/date evidence remains inert until that EventId exists"
                                                  return 2
                                            | _, _, _ =>
                                                IO.eprintln
                                                  "loam: could not append completion, Actual date, and Event evidence"
                                                return 2

/--
Complete one Scheduled occurrence into a separately entered Actual Event.

The Scheduled content is shown as expectation context, but Actual quantities are
entered independently. Publication is relation first, then Actual date, then
Event; the earlier streams remain semantically inert if publication is
interrupted before the Event appears. The Event-memory path is the writer
ownership anchor for the coordinated practical publication.
-/
def completeScheduled
    (scheduledPath memoryPath scheduledToken : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk memoryPath)
    (completeScheduledUnlocked scheduledPath memoryPath scheduledToken)

end Loam.ScheduledCli
