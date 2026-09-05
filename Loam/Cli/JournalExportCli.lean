import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.JournalExportCli

open Loam.Core

set_option autoImplicit false

private structure JournalEntry where
  event : Event
  validOn : String
  description : Option String

private structure MovementView where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory

private def loadCorrectionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return EventCorrectionMemory.ofCorrections? []

private def loadDescriptionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some EventDescriptionMemory.empty

private def loadMovementView?
    (memoryFile : System.FilePath) : IO (Except String MovementView) := do
  match ← IO.getEnv "LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT must not be empty"
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
        return .error ("file not found: " ++ memoryFile.toString)
      let some events ← Loam.Persistence.loadEventMemory? memoryFile
        | return .error "malformed or unsupported event-memory file"
      let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
      let some validity ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile
        | return .error "malformed or unsupported actual-validity history"
      let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
      let some descriptions ← loadDescriptionMemoryOrEmpty? descriptionFile
        | return .error "malformed or unsupported event-description memory"
      return .ok { events, validity, descriptions }

private def journalEntry?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory)
    (event : Event) : Except String JournalEntry :=
  match ActualValidityMemory.findByEventId? validities event.id with
  | none =>
      Except.error
        ("effective Event is missing current Actual occurrence date: " ++ event.id.token)
  | some validOn =>
      Except.ok {
        event := event
        validOn := validOn
        description := EventDescriptionMemory.findText? descriptions event.id
      }

private def journalEntries?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory) :
    List Event → Except String (List JournalEntry)
  | [] => Except.ok []
  | event :: rest => do
      let entry ← journalEntry? validities descriptions event
      let entries ← journalEntries? validities descriptions rest
      pure (entry :: entries)

private def entryOrdering (left right : JournalEntry) : Ordering :=
  match compare left.validOn right.validOn with
  | .eq => compare left.event.id.token right.event.id.token
  | other => other

private def insertEntry (entry : JournalEntry) : List JournalEntry → List JournalEntry
  | [] => [entry]
  | current :: rest =>
      match entryOrdering entry current with
      | .gt => current :: insertEntry entry rest
      | _ => entry :: current :: rest

private def sortEntries : List JournalEntry → List JournalEntry
  | [] => []
  | entry :: rest => insertEntry entry (sortEntries rest)

private def renderHeadingText (entry : JournalEntry) : String :=
  match entry.description with
  | some text =>
      if text.isEmpty then
        "[" ++ entry.event.id.token ++ "]"
      else
        Loam.Persistence.escapeText text
  | none => "[" ++ entry.event.id.token ++ "]"

private def renderEffect (effect : Effect) : String :=
  "    " ++ effect.locus.token ++ "    " ++
    toString effect.quantity.quanta ++ " " ++ effect.measure.token

private def renderEntry (entry : JournalEntry) : String :=
  let heading := entry.validOn ++ " * " ++ renderHeadingText entry
  String.intercalate "\n" (heading :: entry.event.effects.map renderEffect)

private def journalHeader : String :=
  "; GENERATED FROM LOAM CANONICAL DATA\n" ++
  "; DO NOT EDIT AS AUTHORITY\n" ++
  "; Full regeneration from the current Event correction frontier, ActualValidity, and EventDescription.\n" ++
  "; This file is a human-readable projection, not an import surface.\n"

private def renderJournal (entries : List JournalEntry) : String :=
  match entries with
  | [] => journalHeader ++ "\n; No effective Actual events.\n"
  | _ => journalHeader ++ "\n" ++ String.intercalate "\n\n" (entries.map renderEntry) ++ "\n"

private def journalStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

private def publishJournal (path : System.FilePath) (text : String) : IO Unit := do
  let stagePath := journalStagePath path
  IO.FS.writeFile stagePath text
  IO.FS.rename stagePath path

private def conflictsWithCanonicalPath
    (memoryPath correctionPath outputPath : String) : Bool :=
  outputPath == memoryPath ||
    outputPath == correctionPath ||
    outputPath == memoryPath ++ ".actual-validity" ||
    outputPath == memoryPath ++ ".descriptions"

/--
Regenerate one human-readable Actual journal from current canonical evidence.

In sidecar mode this preserves the existing Event / ActualValidity /
EventDescription readers. In explicit manifest mode those three Movement
families come from exactly one selected generation, while EventCorrection
remains its independent canonical stream. Missing or corrupt selected manifest
authority fails closed with no sidecar fallback.
-/
def exportJournal
    (memoryPath correctionPath outputPath : String) : IO UInt32 := do
  if conflictsWithCanonicalPath memoryPath correctionPath outputPath then
    IO.eprintln "loam: journal output must not replace a canonical Event evidence stream"
    return 2

  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  let outputFile := System.FilePath.mk outputPath

  let movement ←
    match ← loadMovementView? memoryFile with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok view => pure view

  match ← loadCorrectionMemoryOrEmpty? correctionFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported correction-memory file"
      return 2
  | some corrections =>
      match Loam.Application.correctionFrontierMemory? movement.events corrections with
      | none =>
          IO.eprintln "loam: corrections do not justify one current Event frontier"
          return 2
      | some frontier =>
          match Loam.Application.admittedActualValidityMemory? movement.validity with
          | none =>
              IO.eprintln
                "loam: actual-validity corrections do not justify one current date per event"
              return 2
          | some validities =>
              match journalEntries? validities movement.descriptions frontier.events with
              | .error message =>
                  IO.eprintln ("loam: " ++ message)
                  return 2
              | .ok entries =>
                  publishJournal outputFile (renderJournal (sortEntries entries))
                  IO.println ("Regenerated readable Actual journal: " ++ outputPath)
                  return 0

end Loam.JournalExportCli

private def journalUsage : String :=
  "Usage: loamJournalExport MEMORY_FILE CORRECTION_FILE OUTPUT_FILE"

private def journalOwnershipAnchor (memoryPath : String) : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT" with
  | none => return .ok (System.FilePath.mk memoryPath)
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "LOAM_EXPERIMENTAL_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok (System.FilePath.mk rootPath / "CURRENT")

def main (args : List String) : IO UInt32 := do
  match args with
  | [memoryPath, correctionPath, outputPath] =>
      match ← journalOwnershipAnchor memoryPath with
      | .error message =>
          IO.eprintln ("loam: " ++ message)
          return 2
      | .ok anchor =>
          Loam.WriterOwnership.withOwnership
            anchor
            (Loam.JournalExportCli.exportJournal memoryPath correctionPath outputPath)
  | _ =>
      IO.eprintln journalUsage
      return 2
