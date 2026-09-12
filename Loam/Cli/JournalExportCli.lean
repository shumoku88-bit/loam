import Loam.ActualAuthority
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence.SiblingStage
import Loam.WriterOwnership

namespace Loam.JournalExportCli

open Loam.Core

set_option autoImplicit false

private structure JournalEntry where
  event : Event
  validOn : String
  description : Option String

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

private def sortEntries (entries : List JournalEntry) : List JournalEntry :=
  entries.foldl (fun acc entry => insertEntry entry acc) []

private def renderEffect (effect : Effect) : String :=
  "  " ++ effect.coordinate.locus.token ++ "\t" ++
    toString effect.quantity.quanta ++ "\t" ++ effect.coordinate.measure.token

private def renderEntry (entry : JournalEntry) : List String :=
  let heading :=
    entry.validOn ++ "\t" ++ entry.event.id.token ++
      match entry.description with
      | some text => "\t" ++ text
      | none => ""
  heading :: entry.event.effects.map renderEffect

private def renderJournal (entries : List JournalEntry) : String :=
  let lines := entries.flatMap renderEntry
  if lines.isEmpty then "" else String.intercalate "\n" lines ++ "\n"

private def conflictsWithCanonicalPath
    (actualPath outputPath : String) : Bool :=
  outputPath == actualPath

/--
Regenerate one human-readable Actual journal from normalized Actual evidence.
-/
def exportJournal
    (actualPath outputPath : String) : IO UInt32 := do
  if conflictsWithCanonicalPath actualPath outputPath then
    IO.eprintln "loam: journal output must not replace a canonical Actual evidence stream"
    return 2

  let actualFile := System.FilePath.mk actualPath
  let outputFile := System.FilePath.mk outputPath

  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok ev => pure ev

  match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
  | none =>
      IO.eprintln "loam: corrections do not justify one current Event frontier"
      return 2
  | some frontier =>
      match Loam.Application.admittedActualValidityMemory? evidence.validity with
      | none =>
          IO.eprintln
            "loam: actual-validity corrections do not justify one current date per event"
          return 2
      | some validities =>
          match journalEntries? validities evidence.descriptions frontier.events with
          | .error message =>
              IO.eprintln ("loam: " ++ message)
              return 2
          | .ok entries =>
              Loam.Persistence.replaceTextViaSiblingStage
                outputFile (renderJournal (sortEntries entries))
              IO.println ("Regenerated readable Actual journal: " ++ outputPath)
              return 0

end Loam.JournalExportCli

private def journalUsage : String :=
  "Usage: loamJournalExport ACTUAL_FILE OUTPUT_FILE"

def main (args : List String) : IO UInt32 :=
  match args with
  | [actualPath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.JournalExportCli.exportJournal actualPath outputPath)
  | _ => do
      IO.eprintln journalUsage
      return 2
