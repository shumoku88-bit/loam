import Loam.ScheduledCli
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledRetirementPersistence
import Loam.WriterOwnership
import Std

namespace Loam.ScheduledLifecycleCli

open Loam.Core

set_option autoImplicit false

/-!
# Practical Scheduled terminal operations

Create, completion, and cancellation all observe the same Scheduled stream.
Cancellation is retained as explicit retirement evidence rather than mutating a
Scheduled occurrence.

The Scheduled file is the shared ownership anchor for terminal admission.
Completion now prepares all human input before taking mutation ownership. On
activation it acquires Scheduled ownership and then EventMemory ownership,
giving one fixed lock order:

  human draft (no writer lock)
      -> Scheduled
      -> EventMemory

The draft is not authority. Both ownership boundaries re-read current evidence
before publication. This prevents a stale Complete affordance from competing
with a cancellation that happened while the user was entering Actual details.

A raw completion relation whose Actual Event is not yet published remains inert
to readers, but cancellation conservatively treats any retained completion
relation as an in-progress terminal claim. The interrupted completion must be
retried or repaired before a competing retirement can be admitted.
-/

private def completionReferencesKnownScheduled
    (scheduledMemory : ScheduledMemory String)
    (completionMemory : ScheduledCompletionMemory) : Bool :=
  completionMemory.completions.all fun completion =>
    match ScheduledMemory.findById? scheduledMemory completion.scheduled with
    | some _ => true
    | none => false

private def retirementReferencesKnownScheduled
    (scheduledMemory : ScheduledMemory String)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    match ScheduledMemory.findById? scheduledMemory retirement.scheduled with
    | some _ => true
    | none => false

private def terminalEvidenceCompatible
    (completionMemory : ScheduledCompletionMemory)
    (retirementMemory : ScheduledRetirementMemory) : Bool :=
  retirementMemory.retirements.all fun retirement =>
    (ScheduledCompletionMemory.findByScheduled?
      completionMemory retirement.scheduled).isNone

/--
Read the terminal evidence before asking the human for completion details.

This is only a usability preflight. It does not reserve the Scheduled identity;
activation repeats the same checks while holding Scheduled ownership.
-/
private def preflightCompletionTerminal
    (scheduledPath scheduledToken : String) : IO (Except UInt32 Unit) := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile

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
        | some _ =>
            match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported scheduled-completion file"
                return Except.error 2
            | some completionMemory =>
                match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile with
                | none =>
                    IO.eprintln "loam: malformed or unsupported scheduled-retirement file"
                    return Except.error 2
                | some retirementMemory =>
                    if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                      IO.eprintln
                        "loam: scheduled-completion file refers to an unknown Scheduled identity"
                      return Except.error 2
                    else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
                      IO.eprintln
                        "loam: scheduled-retirement file refers to an unknown Scheduled identity"
                      return Except.error 2
                    else if !terminalEvidenceCompatible completionMemory retirementMemory then
                      IO.eprintln
                        "loam: Scheduled terminal evidence conflicts between completion and retirement"
                      return Except.error 2
                    else
                      match ScheduledRetirementMemory.findByScheduled?
                          retirementMemory scheduledId with
                      | some _ =>
                          IO.println
                            ("Scheduled movement already cancelled: " ++ scheduledId.token ++ ".")
                          return Except.error 1
                      | none => return Except.ok ()

private def completeScheduledUnlocked
    (scheduledPath memoryPath scheduledToken : String)
    (draft : Loam.ScheduledCli.CompletionDraft) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile

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
                match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile with
                | none =>
                    IO.eprintln "loam: malformed or unsupported scheduled-retirement file"
                    return 2
                | some retirementMemory =>
                    if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                      IO.eprintln
                        "loam: scheduled-completion file refers to an unknown Scheduled identity"
                      return 2
                    else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
                      IO.eprintln
                        "loam: scheduled-retirement file refers to an unknown Scheduled identity"
                      return 2
                    else if !terminalEvidenceCompatible completionMemory retirementMemory then
                      IO.eprintln
                        "loam: Scheduled terminal evidence conflicts between completion and retirement"
                      return 2
                    else
                      match ScheduledRetirementMemory.findByScheduled?
                          retirementMemory scheduledId with
                      | some _ =>
                          IO.println
                            ("Scheduled movement changed while the completion draft was open: " ++
                              scheduledId.token ++ " is now cancelled.")
                          return 1
                      | none =>
                          Loam.ScheduledCli.activateCompletionDraft
                            scheduledPath memoryPath scheduledToken draft

/--
Complete one Scheduled occurrence without holding mutation ownership across
human input.

A read-only preflight first avoids soliciting details for an already-cancelled
occurrence. The completion draft is then collected with no writer lock. Only
activation acquires Scheduled ownership, re-admits terminal evidence, then
enters the EventMemory-owned completion publisher. A stale draft therefore
cannot publish across a concurrent cancellation.
-/
def completeScheduled
    (scheduledPath memoryPath scheduledToken : String) : IO UInt32 := do
  match ← preflightCompletionTerminal scheduledPath scheduledToken with
  | Except.error status => return status
  | Except.ok _ =>
      match ← Loam.ScheduledCli.prepareCompletionDraft
          scheduledPath memoryPath scheduledToken with
      | Except.error status => return status
      | Except.ok draft =>
          Loam.WriterOwnership.withOwnership
            (System.FilePath.mk scheduledPath)
            (completeScheduledUnlocked scheduledPath memoryPath scheduledToken draft)

private def cancelScheduledUnlocked
    (scheduledPath scheduledToken : String) : IO UInt32 := do
  let scheduledFile := System.FilePath.mk scheduledPath
  let completionFile :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledFile
  let retirementFile :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledFile

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
                match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementFile with
                | none =>
                    IO.eprintln "loam: malformed or unsupported scheduled-retirement file"
                    return 2
                | some retirementMemory =>
                    if !completionReferencesKnownScheduled scheduledMemory completionMemory then
                      IO.eprintln
                        "loam: scheduled-completion file refers to an unknown Scheduled identity"
                      return 2
                    else if !retirementReferencesKnownScheduled scheduledMemory retirementMemory then
                      IO.eprintln
                        "loam: scheduled-retirement file refers to an unknown Scheduled identity"
                      return 2
                    else if !terminalEvidenceCompatible completionMemory retirementMemory then
                      IO.eprintln
                        "loam: Scheduled terminal evidence conflicts between completion and retirement"
                      return 2
                    else
                      match ScheduledRetirementMemory.findByScheduled?
                          retirementMemory scheduledId with
                      | some _ =>
                          IO.println
                            ("Scheduled movement already cancelled: " ++ scheduledId.token ++ ".")
                          return 1
                      | none =>
                          match ScheduledCompletionMemory.findByScheduled?
                              completionMemory scheduledId with
                          | some _ =>
                              IO.println
                                ("Scheduled movement has retained completion evidence and cannot be cancelled: " ++
                                  scheduledId.token ++ ".")
                              return 1
                          | none =>
                              let retirement : ScheduledRetirement := {
                                scheduled := scheduledId
                              }
                              match retirementMemory.add? retirement with
                              | none =>
                                  IO.eprintln "loam: could not append Scheduled retirement evidence"
                                  return 2
                              | some updated =>
                                  if ← Loam.Persistence.saveScheduledRetirementMemory?
                                      retirementFile updated then
                                    IO.println
                                      ("Cancelled scheduled movement: " ++ scheduledId.token ++
                                        " on " ++ occurrence.scheduledOn ++ ".")
                                    return 0
                                  else
                                    IO.eprintln
                                      "loam: Scheduled retirement evidence could not be published"
                                    return 2

/-- Retire one Scheduled occurrence under the shared Scheduled ownership boundary. -/
def cancelScheduled
    (scheduledPath scheduledToken : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk scheduledPath)
    (cancelScheduledUnlocked scheduledPath scheduledToken)

end Loam.ScheduledLifecycleCli
