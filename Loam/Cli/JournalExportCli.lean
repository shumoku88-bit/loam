import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.Persistence.SiblingStage
import Loam.WriterOwnership

namespace Loam.JournalExportCli

open Loam.Core

set_option autoImplicit false

private def renderEffect (effect : Effect) : String :=
  "  " ++ effect.coordinate.locus.token ++ "\t" ++
    toString effect.quantity.quanta ++ "\t" ++ effect.coordinate.measure.token

private def renderEntry (entry : Loam.ActualJournalProjection.Entry) : List String :=
  let heading :=
    entry.validOn ++ "\t" ++ entry.event.id.token ++
      match entry.description with
      | some text => "\t" ++ text
      | none => ""
  heading :: entry.event.effects.map renderEffect

private def renderJournal (entries : List Loam.ActualJournalProjection.Entry) : String :=
  let lines := entries.flatMap renderEntry
  if lines.isEmpty then "" else String.intercalate "\n" lines ++ "\n"

private def conflictsWithCanonicalPath
    (actualPath outputPath : String) : Bool :=
  outputPath == actualPath

/--
Regenerate one human-readable Actual journal from one fully admitted normalized Actual image.
-/
def exportJournal
    (actualPath outputPath : String) : IO UInt32 := do
  if conflictsWithCanonicalPath actualPath outputPath then
    IO.eprintln "loam: journal output must not replace a canonical Actual evidence stream"
    return 2

  let actualFile := System.FilePath.mk actualPath
  let outputFile := System.FilePath.mk outputPath

  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok image => pure image

  match Loam.ActualJournalProjection.fromImage? image with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok entries =>
      Loam.Persistence.replaceTextViaSiblingStage
        outputFile (renderJournal entries)
      IO.println ("Regenerated readable Actual journal: " ++ outputPath)
      return 0

private def usage : String :=
  "Usage: loam export journal ACTUAL_FILE OUTPUT_FILE"

/-- Command dispatcher for regenerating the human-readable Actual journal. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [actualPath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (exportJournal actualPath outputPath)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.JournalExportCli
