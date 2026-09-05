import Loam.ActualDate
import Loam.Application.ScheduledInspection
import Loam.MovementEntry
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence
import Loam.WriterOwnership
import Std

namespace Loam.ScheduledReplacementCli

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

private def addLocusIfAbsent (loci : List String) (locus : String) : List String :=
  if locus ∈ loci then loci else loci ++ [locus]

private def knownScheduledLoci (memory : ScheduledMemory String) : List String :=
  memory.occurrences.foldl
    (fun loci occurrence =>
      occurrence.movement.changes.foldl
        (fun current change => addLocusIfAbsent current change.coordinate.token)
        loci)
    []

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

private def printOccurrence (occurrence : ScheduledOccurrence String) : IO Unit := do
  IO.println (occurrence.scheduledOn ++ "  [" ++ occurrence.id.token ++ "]")
  for change in occurrence.movement.changes do
    IO.println
      ("  " ++ change.coordinate.token ++ ": " ++
        toString change.quantity.quanta ++ " " ++ occurrence.measure.token)

private def replacementDay (defaultDay : String) : IO (Except String String) := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let interactive := (← stdin.isTty) && (← stdout.isTty)
  let prompt :=
    if interactive then
      "Replacement date [" ++ defaultDay ++ "] (YYYY-MM-DD): "
    else
      "Replacement date (YYYY-MM-DD): "
  let entered ← promptLine prompt
  let day := if interactive && entered.isEmpty then defaultDay else entered
  if Loam.ActualDate.validIsoDate day then
    return Except.ok day
  else
    return Except.error
      "loam: replacement date must be a real calendar date in YYYY-MM-DD form"

/-- Human-entered replacement content prepared before writer ownership is acquired. -/
structure ReplacementDraft where
  scheduledOn : String
  effects : List Effect
  total : Int

/--
Prepare one replacement Scheduled occurrence without retaining edit-kind semantics.

The old Scheduled occurrence supplies only editable human defaults. The draft is
not authority. Activation re-reads every Scheduled lifecycle stream under the
Scheduled writer lock before publishing any canonical evidence.
-/
def prepareReplacementDraft
    (scheduledPath sourceToken : String) : IO (Except UInt32 ReplacementDraft) := do
  let scheduledFile := System.FilePath.mk scheduledPath
  if !(← scheduledFile.pathExists) then
    IO.eprintln ("loam: file not found: " ++ scheduledPath)
    return Except.error 2
  else
    match ← Loam.Persistence.loadScheduledMemory? scheduledFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported scheduled file"
        return Except.error 2
    | some memory =>
        let source : ScheduledId := ⟨sourceToken⟩
        match ScheduledMemory.findById? memory source with
        | none =>
            IO.eprintln "loam: scheduled identity not found"
            return Except.error 1
        | some occurrence =>
            IO.println "Scheduled expectation to replace:"
            printOccurrence occurrence
            match ← replacementDay occurrence.scheduledOn with
            | Except.error message =>
                IO.eprintln message
                return Except.error 2
            | Except.ok day =>
                IO.println
                  "Enter the replacement movement. Interactive entry may keep the old movement values."
                match ← Loam.MovementEntry.collectMovementEffectsWithDefaults
                    (knownScheduledLoci memory) occurrence.movement with
                | Except.error message =>
                    IO.eprintln message
                    return Except.error 2
                | Except.ok (effects, total) =>
                    return Except.ok {
                      scheduledOn := day
                      effects := effects
                      total := total
                    }

private def containsScheduled
    (occurrences : List (ScheduledOccurrence String))
    (id : ScheduledId) : Bool :=
  occurrences.any fun occurrence => occurrence.id = id

private def reportFrontierRefusal
    (result : CurrentOpenScheduledWithReplacementResult String) : IO UInt32 := do
  match result with
  | .unknownCompletionScheduled =>
      IO.eprintln "loam: scheduled-completion file refers to an unknown Scheduled identity"
      return 2
  | .unknownRetirementScheduled =>
      IO.eprintln "loam: scheduled-retirement file refers to an unknown Scheduled identity"
      return 2
  | .unknownReplacementScheduled =>
      IO.eprintln "loam: scheduled-replacement file refers to an unknown Scheduled identity"
      return 2
  | .invalidReplacementGraph =>
      IO.eprintln "loam: scheduled-replacement graph is cyclic or otherwise invalid"
      return 2
  | .conflictingTerminalEvidence =>
      IO.eprintln
        "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
      return 2
  | .open _ => return 0

private def admitReplacementOccurrence?
    (memory : ScheduledMemory String)
    (id : ScheduledId)
    (draft : ReplacementDraft) : Option (ScheduledMemory String × ScheduledOccurrence String) := do
  let occurrence ← scheduledFromEffects? id draft.scheduledOn draft.effects
  let updated ← ScheduledMemory.add? memory occurrence
  pure (updated, occurrence)

private def resumeInterruptedReplacement
    (scheduledFile : System.FilePath)
    (scheduledMemory : ScheduledMemory String)
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory)
    (replacementMemory : ScheduledReplacementMemory)
    (eventMemory : EventMemory)
    (retained : ScheduledReplacement)
    (draft : ReplacementDraft) : IO UInt32 := do
  match ScheduledMemory.findById? scheduledMemory retained.replacement with
  | some _ =>
      IO.eprintln
        ("loam: Scheduled identity already replaced: " ++ retained.source.token ++
          " -> " ++ retained.replacement.token)
      return 1
  | none =>
      match admitReplacementOccurrence? scheduledMemory retained.replacement draft with
      | none =>
          IO.eprintln "loam: replacement Scheduled movement could not be admitted"
          return 2
      | some (updatedScheduled, _) =>
          match Loam.Application.currentOpenScheduledWithReplacement
              updatedScheduled completionMemory retirementMemory replacementMemory eventMemory with
          | .open _ =>
              if (Loam.Persistence.encodeScheduledMemory? updatedScheduled).isNone then
                IO.eprintln "loam: replacement Scheduled movement could not be encoded"
                return 2
              else if ← Loam.Persistence.saveScheduledMemory? scheduledFile updatedScheduled then
                IO.println
                  ("Resumed interrupted Scheduled replacement: " ++ retained.source.token ++
                    " -> " ++ retained.replacement.token ++ " on " ++ draft.scheduledOn ++
                    " = " ++ toString draft.total ++ " jpy.")
                IO.println
                  "Replacement Scheduled routing is independent; route the new Scheduled identity explicitly when needed."
                return 0
              else
                IO.eprintln "loam: replacement Scheduled movement could not be published"
                return 2
          | refusal => reportFrontierRefusal refusal

private def replaceScheduledWithDraftUnlocked
    (scheduledPath memoryPath sourceToken : String)
    (draft : ReplacementDraft) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let memoryFile := System.FilePath.mk memoryPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile
  let replacementFile :=
    Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledFile

  match ← loadScheduledMemoryOrEmpty? scheduledFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported scheduled file"
      return 2
  | some scheduledMemory =>
      match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported scheduled-completion file"
          return 2
      | some completionMemory =>
          match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported scheduled-retirement file"
              return 2
          | some retirementMemory =>
              match ← Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementFile with
              | none =>
                  IO.eprintln "loam: malformed or unsupported scheduled-replacement file"
                  return 2
              | some replacementMemory =>
                  match ← loadEventMemoryOrEmpty? memoryFile with
                  | none =>
                      IO.eprintln "loam: malformed or unsupported event-memory file"
                      return 2
                  | some eventMemory =>
                      let source : ScheduledId := ⟨sourceToken⟩
                      match ScheduledMemory.findById? scheduledMemory source with
                      | none =>
                          IO.eprintln "loam: scheduled identity not found"
                          return 1
                      | some _ =>
                          match ScheduledReplacementMemory.findBySource? replacementMemory source with
                          | some retained =>
                              resumeInterruptedReplacement
                                scheduledFile scheduledMemory completionMemory retirementMemory
                                replacementMemory eventMemory retained draft
                          | none =>
                              match Loam.Application.currentOpenScheduledWithReplacement
                                  scheduledMemory completionMemory retirementMemory replacementMemory
                                  eventMemory with
                              | .open openOccurrences =>
                                  if !containsScheduled openOccurrences source then
                                    IO.eprintln
                                      "loam: only a currently open Scheduled identity can be replaced"
                                    return 1
                                  else
                                    match freshScheduledId? scheduledMemory with
                                    | none =>
                                        IO.eprintln
                                          "loam: could not generate a fresh replacement Scheduled identity"
                                        return 2
                                    | some replacementId =>
                                        match admitReplacementOccurrence?
                                            scheduledMemory replacementId draft with
                                        | none =>
                                            IO.eprintln
                                              "loam: replacement Scheduled movement could not be admitted"
                                            return 2
                                        | some (updatedScheduled, _) =>
                                            let relation : ScheduledReplacement :=
                                              { source := source, replacement := replacementId }
                                            match ScheduledReplacementMemory.add?
                                                replacementMemory relation with
                                            | none =>
                                                IO.eprintln
                                                  "loam: replacement relation violates one-to-one endpoint ownership"
                                                return 2
                                            | some updatedReplacements =>
                                                match Loam.Application.currentOpenScheduledWithReplacement
                                                    updatedScheduled completionMemory retirementMemory
                                                    updatedReplacements eventMemory with
                                                | .open _ =>
                                                    if (Loam.Persistence.encodeScheduledMemory?
                                                        updatedScheduled).isNone ||
                                                        (Loam.Persistence.encodeScheduledReplacementMemory?
                                                          updatedReplacements).isNone then
                                                      IO.eprintln
                                                        "loam: replacement publication could not be encoded"
                                                      return 2
                                                    else if !(← Loam.Persistence.saveScheduledReplacementMemory?
                                                        replacementFile updatedReplacements) then
                                                      IO.eprintln
                                                        "loam: replacement relation could not be published"
                                                      return 2
                                                    else if ← Loam.Persistence.saveScheduledMemory?
                                                        scheduledFile updatedScheduled then
                                                      IO.println
                                                        ("Replaced scheduled movement: " ++ source.token ++
                                                          " -> " ++ replacementId.token ++ " on " ++
                                                          draft.scheduledOn ++ " = " ++
                                                          toString draft.total ++ " jpy.")
                                                      IO.println
                                                        "Replacement Scheduled routing is independent; route the new Scheduled identity explicitly when needed."
                                                      return 0
                                                    else
                                                      IO.eprintln
                                                        ("loam: replacement relation retained as " ++
                                                          source.token ++ " -> " ++ replacementId.token ++
                                                          ", but the replacement Scheduled movement was not published; rerun replace to resume fail-closed recovery")
                                                      return 2
                                                | refusal => reportFrontierRefusal refusal
                              | refusal => reportFrontierRefusal refusal

/--
Replace one currently open Scheduled occurrence under Scheduled writer ownership.

Publication is deliberately relation-first. If publication is interrupted between
the relation and the replacement occurrence, replacement-aware readers see an
unknown endpoint and fail closed instead of double-counting old and new intent.
A later invocation for the same source reuses the retained replacement identity
and publishes only the missing Scheduled occurrence.
-/
def replaceScheduled
    (scheduledPath memoryPath sourceToken : String) : IO UInt32 := do
  match ← prepareReplacementDraft scheduledPath sourceToken with
  | Except.error status => return status
  | Except.ok draft =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk scheduledPath)
        (replaceScheduledWithDraftUnlocked scheduledPath memoryPath sourceToken draft)

end Loam.ScheduledReplacementCli
