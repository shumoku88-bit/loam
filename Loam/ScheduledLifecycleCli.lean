import Loam.ScheduledCli
import Loam.ScheduledCompletionPersistence
import Loam.ScheduledPersistence
import Loam.ScheduledRetirementPersistence
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
Completion acquires that ownership first and then enters the existing
EventMemory-owned completion writer, giving one fixed lock order:

  Scheduled -> EventMemory

This prevents a completion and cancellation from both being admitted for the
same Scheduled identity while still preserving EventMemory ownership against
ordinary Actual writers.

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

private def completeScheduledUnlocked
    (scheduledPath memoryPath scheduledToken : String) : IO UInt32 := do
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
                            ("Scheduled movement already cancelled: " ++ scheduledId.token ++ ".")
                          return 1
                      | none =>
                          Loam.ScheduledCli.completeScheduled
                            scheduledPath memoryPath scheduledToken

/--
Complete one Scheduled occurrence while holding the Scheduled terminal boundary.

The existing completion writer still owns EventMemory internally, so the
coordinated operation is serialized against both Scheduled lifecycle writers
and ordinary Actual writers.
-/
def completeScheduled
    (scheduledPath memoryPath scheduledToken : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk scheduledPath)
    (completeScheduledUnlocked scheduledPath memoryPath scheduledToken)

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
