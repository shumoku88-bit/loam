import Loam.ActualDate
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.CompletionPrompt
import Loam.MovementEntry
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.ScheduledCompletionUi
import Loam.Persistence.ScheduledPersistence
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

private def loadEventDescriptionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some EventDescriptionMemory.empty

/--
Collect optional EventDescription text for one Scheduled completion draft.

Interactive terminals expose the same small human-recognition field as ordinary
Movement recording. Redirected/scripted callers retain no description unless
`LOAM_DESCRIPTION` is explicitly supplied. Empty text means no description.
-/
private def practicalDescription : IO (Option String) := do
  match ← IO.getEnv "LOAM_DESCRIPTION" with
  | some text =>
      if text.isEmpty then return none else return some text
  | none =>
      let stdin ← IO.getStdin
      let stdout ← IO.getStdout
      if (← stdin.isTty) && (← stdout.isTty) then
        let text ← promptLine "Description (optional): "
        if text.isEmpty then return none else return some text
      else
        return none

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

/-- Provenance of the Actual date held by one in-memory completion draft. -/
inductive CompletionDateSource where
  | entered
  | retained
  deriving DecidableEq, Repr

/--
Human-entered completion material prepared before mutation ownership is acquired.

The expected Actual identity and relation-presence bit are preflight observations,
not authority. Activation re-reads current evidence and refuses incompatible
changes before publishing. A retained EventDescription is likewise preflight
supporting evidence and cannot be replaced on retry.
-/
structure CompletionDraft where
  actual : EventId
  completionRetained : Bool
  validOn : String
  dateSource : CompletionDateSource
  description : Option String
  descriptionRetained : Bool
  effects : List Effect
  total : Int

private def showCompletionProgress
    (progress : Loam.ScheduledCompletionUi.Progress) : IO Unit := do
  let action := Loam.ScheduledCompletionUi.action progress
  IO.println ""
  IO.println "Scheduled completion"
  IO.println ("  action: " ++ Loam.ScheduledCompletionUi.actionLabel action)
  if progress.completionRetained then
    IO.println "  [ok] completion relation retained"
  match progress.actualDate with
  | none => IO.println "  [?] Actual date"
  | some day =>
      if progress.dateRetained then
        IO.println ("  [ok] Actual date: " ++ day ++ " (retained)")
      else
        IO.println ("  [ok] Actual date: " ++ day)
  match progress.movementTotal with
  | none => IO.println "  [?] Actual movement"
  | some total => IO.println ("  [ok] Actual movement: " ++ toString total ++ " jpy")
  let needs := Loam.ScheduledCompletionUi.obligations progress
  match needs with
  | [] => IO.println "  ready to request admission"
  | _ =>
      IO.println
        ("  outstanding: " ++
          String.intercalate ", " (needs.map Loam.ScheduledCompletionUi.obligationLabel))

/--
Prepare one completion draft without holding Scheduled or EventMemory writer
ownership across human think time.

The read-only snapshot supplies expectation context, known-Locus hints, and any
retained completion/date/description evidence. It is deliberately not
publication authority; activation re-reads all canonical evidence under writer
ownership.
-/
def prepareCompletionDraft
    (scheduledPath memoryPath scheduledToken : String) :
    IO (Except UInt32 CompletionDraft) := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let memoryFile := System.FilePath.mk memoryPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile

  if !(← scheduledFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ scheduledPath)
    return Except.error 2
  else
    match ← Loam.Persistence.loadScheduledMemory? scheduledFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported scheduled file"
        return Except.error 2
    | some scheduledMemory =>
        let scheduledId : ScheduledId := ⟨scheduledToken⟩
        match ScheduledMemory.findById? scheduledMemory scheduledId with
        | none =>
            IO.eprintln "loam: scheduled identity not found"
            return Except.error 1
        | some occurrence =>
            match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported scheduled-completion file"
                return Except.error 2
            | some completionMemory =>
                if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                  IO.eprintln "loam: scheduled-completion file refers to an unknown Scheduled identity"
                  return Except.error 2
                else
                  match ← loadEventMemoryOrEmpty? memoryFile with
                  | none =>
                      IO.eprintln "loam: malformed or unsupported event-memory file"
                      return Except.error 2
                  | some eventMemory =>
                      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
                      | none =>
                          IO.eprintln "loam: malformed or unsupported actual-validity history"
                          return Except.error 2
                      | some history =>
                          match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
                          | none =>
                              IO.eprintln "loam: malformed or unsupported event-description memory"
                              return Except.error 2
                          | some descriptions =>
                              let existingCompletion :=
                                ScheduledCompletionMemory.findByScheduled? completionMemory scheduledId
                              let completionRetained :=
                                match existingCompletion with
                                | some _ => true
                                | none => false
                              let actualId :=
                                match existingCompletion with
                                | some completion => completion.actual
                                | none => completionEventId scheduledId
                              let factId := completionValidityFactId scheduledId
                              let existingFact := history.findFactById? factId
                              let retainedDescription :=
                                EventDescriptionMemory.findText? descriptions actualId

                              match EventMemory.findById? eventMemory actualId with
                              | some _ =>
                                  match existingCompletion with
                                  | some _ =>
                                      IO.println
                                        ("Scheduled movement already completed: " ++
                                          scheduledId.token ++ " -> " ++ actualId.token ++ ".")
                                      return Except.error 1
                                  | none =>
                                      IO.eprintln
                                        "loam: completion Event identity already exists without the expected completion relation"
                                      return Except.error 2
                              | none =>
                                  if !completionRetained &&
                                      (historyMentionsEvent history actualId ||
                                        retainedDescription.isSome ||
                                        (ScheduledCompletionMemory.findByActual?
                                          completionMemory actualId).isSome) then
                                    IO.eprintln
                                      "loam: generated completion Event identity collides with retained evidence"
                                    return Except.error 2
                                  else
                                    let retainedDateResult : Except String (Option String) :=
                                      match existingFact with
                                      | some fact =>
                                          if fact.event = actualId then
                                            Except.ok (some fact.validOn)
                                          else
                                            Except.error
                                              "loam: retained completion-date identity points to another Event"
                                      | none =>
                                          if historyMentionsEvent history actualId then
                                            Except.error
                                              "loam: completion Event identity already has unrelated date evidence"
                                          else
                                            Except.ok none
                                    match retainedDateResult with
                                    | Except.error message =>
                                        IO.eprintln message
                                        return Except.error 2
                                    | Except.ok retainedDate =>
                                        if retainedDescription.isSome && retainedDate.isNone then
                                          IO.eprintln
                                            "loam: retained completion description lacks prior completion-date evidence"
                                          return Except.error 2
                                        else
                                          IO.println "Scheduled expectation:"
                                          printOccurrence occurrence
                                          let initialProgress : Loam.ScheduledCompletionUi.Progress := {
                                            completionRetained := completionRetained
                                            actualDate := retainedDate
                                            dateRetained := retainedDate.isSome
                                          }
                                          showCompletionProgress initialProgress

                                          let dateResult ←
                                            match retainedDate with
                                            | some day =>
                                                IO.println
                                                  ("Using retained Actual date from interrupted completion: " ++ day)
                                                pure (Except.ok (day, CompletionDateSource.retained))
                                            | none =>
                                                match ← Loam.ActualDate.practicalOccurrenceDate with
                                                | Except.error message => pure (Except.error message)
                                                | Except.ok day =>
                                                    let withDate := {
                                                      initialProgress with
                                                      actualDate := some day
                                                      dateRetained := false
                                                    }
                                                    showCompletionProgress withDate
                                                    pure (Except.ok (day, CompletionDateSource.entered))
                                          match dateResult with
                                          | Except.error message =>
                                              IO.eprintln message
                                              return Except.error 2
                                          | Except.ok (validOn, dateSource) =>
                                              let descriptionResult ←
                                                match retainedDescription with
                                                | some text =>
                                                    IO.println
                                                      ("Using retained Actual description from interrupted completion: " ++ text)
                                                    pure (some text, true)
                                                | none =>
                                                    let description ← practicalDescription
                                                    pure (description, false)
                                              let (description, descriptionRetained) := descriptionResult
                                              IO.println
                                                "Enter what actually happened. Add FROM entries, then TO entries."
                                              match ← Loam.MovementEntry.collectMovementEffectsWithDefaults
                                                  (knownCompletionLoci scheduledMemory eventMemory)
                                                  occurrence.movement with
                                              | Except.error message =>
                                                  IO.eprintln message
                                                  return Except.error 2
                                              | Except.ok (effects, total) =>
                                                  showCompletionProgress {
                                                    completionRetained := completionRetained
                                                    actualDate := some validOn
                                                    dateRetained := decide (dateSource = .retained)
                                                    movementTotal := some total
                                                  }
                                                  return Except.ok {
                                                    actual := actualId
                                                    completionRetained := completionRetained
                                                    validOn := validOn
                                                    dateSource := dateSource
                                                    description := description
                                                    descriptionRetained := descriptionRetained
                                                    effects := effects
                                                    total := total
                                                  }

private def completeScheduledWithDraftUnlocked
    (scheduledPath memoryPath scheduledToken : String)
    (draft : CompletionDraft) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let memoryFile := System.FilePath.mk memoryPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile

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
        | some _ =>
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
                          match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
                          | none =>
                              IO.eprintln "loam: malformed or unsupported event-description memory"
                              return 2
                          | some descriptions =>
                              let existingCompletion :=
                                ScheduledCompletionMemory.findByScheduled? completionMemory scheduledId
                              let actualId :=
                                match existingCompletion with
                                | some completion => completion.actual
                                | none => completionEventId scheduledId
                              let factId := completionValidityFactId scheduledId
                              let existingFact := history.findFactById? factId
                              let existingDescription :=
                                EventDescriptionMemory.findText? descriptions actualId

                              if actualId != draft.actual then
                                IO.eprintln
                                  "loam: Scheduled completion state changed while the draft was open; refresh and retry"
                                return 1
                              else if draft.completionRetained && existingCompletion.isNone then
                                IO.eprintln
                                  "loam: retained completion evidence changed while the draft was open; refresh and retry"
                                return 1
                              else
                                match EventMemory.findById? eventMemory actualId with
                                | some _ =>
                                    match existingCompletion with
                                    | some _ =>
                                        IO.println
                                          ("Scheduled movement already completed: " ++
                                            scheduledId.token ++ " -> " ++ actualId.token ++ ".")
                                        return 1
                                    | none =>
                                        IO.eprintln
                                          "loam: completion Event identity already exists without the expected completion relation"
                                        return 2
                                | none =>
                                    if existingCompletion.isNone &&
                                        (historyMentionsEvent history actualId ||
                                          existingDescription.isSome ||
                                          (ScheduledCompletionMemory.findByActual?
                                            completionMemory actualId).isSome) then
                                      IO.eprintln
                                        "loam: generated completion Event identity collides with retained evidence"
                                      return 2
                                    else
                                      let dateAdmission : Except String Bool :=
                                        match existingFact with
                                        | some fact =>
                                            if fact.event != actualId then
                                              Except.error
                                                "loam: retained completion-date identity points to another Event"
                                            else if fact.validOn != draft.validOn then
                                              Except.error
                                                "loam: Actual date changed while the completion draft was open; refresh and retry"
                                            else
                                              Except.ok true
                                        | none =>
                                            if historyMentionsEvent history actualId then
                                              Except.error
                                                "loam: completion Event identity already has unrelated date evidence"
                                            else
                                              match draft.dateSource with
                                              | .retained =>
                                                  Except.error
                                                    "loam: retained Actual date disappeared while the completion draft was open; refresh and retry"
                                              | .entered => Except.ok false
                                      match dateAdmission with
                                      | Except.error message =>
                                          IO.eprintln message
                                          return 1
                                      | Except.ok dateAlreadyRetained =>
                                          let descriptionAdmission : Except String Bool :=
                                            if draft.descriptionRetained then
                                              match draft.description with
                                              | none =>
                                                  Except.error
                                                    "loam: retained Actual description draft is internally inconsistent"
                                              | some expected =>
                                                  match existingDescription with
                                                  | none =>
                                                      Except.error
                                                        "loam: retained Actual description disappeared while the completion draft was open; refresh and retry"
                                                  | some current =>
                                                      if current = expected then
                                                        Except.ok true
                                                      else
                                                        Except.error
                                                          "loam: Actual description changed while the completion draft was open; refresh and retry"
                                            else
                                              match existingDescription with
                                              | none => Except.ok false
                                              | some _ =>
                                                  Except.error
                                                    "loam: Actual description changed while the completion draft was open; refresh and retry"
                                          match descriptionAdmission with
                                          | Except.error message =>
                                              IO.eprintln message
                                              return 1
                                          | Except.ok descriptionAlreadyRetained =>
                                              match Event.ofEffects? actualId draft.effects with
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
                                                    validOn := draft.validOn
                                                  }
                                                  let updatedCompletions? :=
                                                    match existingCompletion with
                                                    | some _ => some completionMemory
                                                    | none => completionMemory.add? completion
                                                  let updatedHistory? :=
                                                    if dateAlreadyRetained then
                                                      some history
                                                    else
                                                      history.addFact? fact
                                                  let updatedDescriptions? :=
                                                    if descriptionAlreadyRetained then
                                                      some descriptions
                                                    else
                                                      match draft.description with
                                                      | none => some descriptions
                                                      | some text =>
                                                          EventDescriptionMemory.ofEntries?
                                                            (descriptions.entries ++
                                                              [{ event := actualId, text := text }])
                                                  match updatedCompletions?, updatedHistory?,
                                                      updatedDescriptions?, EventMemory.add? eventMemory event with
                                                  | some updatedCompletions, some updatedHistory,
                                                      some updatedDescriptions, some updatedEvents =>
                                                      match existingCompletion with
                                                      | none =>
                                                          if !(← Loam.Persistence.saveScheduledCompletionMemory?
                                                              completionFile updatedCompletions) then
                                                            IO.eprintln
                                                              "loam: completion relation could not be published"
                                                            return 2
                                                      | some _ => pure ()
                                                      if !dateAlreadyRetained then
                                                        if !(← Loam.Persistence.saveActualValidityHistory?
                                                            validityFile updatedHistory) then
                                                          IO.eprintln
                                                            "loam: Actual date was not published; the already-published completion relation remains inert"
                                                          return 2
                                                      if !descriptionAlreadyRetained then
                                                        match draft.description with
                                                        | none => pure ()
                                                        | some _ =>
                                                            if !(← Loam.Persistence.saveEventDescriptionMemory?
                                                                descriptionFile updatedDescriptions) then
                                                              IO.eprintln
                                                                "loam: Actual description was not published; the already-published completion/date evidence remains inert"
                                                              return 2
                                                      if ← Loam.Persistence.saveEventMemory?
                                                          memoryFile updatedEvents then
                                                        IO.println
                                                          ("Completed scheduled movement: " ++
                                                            scheduledId.token ++ " -> " ++ actualId.token ++
                                                            ", " ++ toString draft.total ++ " jpy. Date: " ++
                                                            draft.validOn ++ ".")
                                                        return 0
                                                      else
                                                        IO.eprintln
                                                          "loam: Actual Event was not published; retained completion/date/description evidence remains inert until that EventId exists"
                                                        return 2
                                                  | _, _, _, _ =>
                                                      IO.eprintln
                                                        "loam: could not append completion, Actual date, description, and Event evidence"
                                                      return 2

/--
Activate one already-prepared Scheduled completion draft against current
EventMemory state.

The caller is expected to hold the Scheduled terminal ownership boundary. This
function acquires EventMemory ownership only for the current-state re-read,
admission, and publication window. Human input must already be complete.
-/
def activateCompletionDraft
    (scheduledPath memoryPath scheduledToken : String)
    (draft : CompletionDraft) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk memoryPath)
    (completeScheduledWithDraftUnlocked scheduledPath memoryPath scheduledToken draft)

end Loam.ScheduledCli