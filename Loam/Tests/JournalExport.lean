import Loam.ActualAuthority
import Loam.Cli.JournalExportCli

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def balancedEvent (id : String) (amount : Int) : IO Event := do
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      Effect.ofAnonymousQuantity ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
    ])
    ("event admission failed: " ++ id)

def main (args : List String) : IO Unit := do
  let root ←
    match args with
    | [path] => pure (System.FilePath.mk path)
    | _ => throw <| IO.userError "expected temporary root"
  IO.FS.createDirAll root
  let actualFile := root / "actual.loam"
  let outputFile := root / "actual-journal.txt"

  let original ← balancedEvent "journal-original" 100
  let replacement ← balancedEvent "journal-replacement" 120
  let untouched ← balancedEvent "journal-untouched" 40

  let events ← requireSome
    (EventMemory.ofEvents? [original, replacement, untouched])
    "event memory admission failed"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [
      { target := original.id, replacement := replacement.id }
    ])
    "correction memory admission failed"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base original.id "2026-09-01",
      .base replacement.id "2026-09-02",
      .base untouched.id "2026-09-03"
    ] [])
    "validity history admission failed"

  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      validity := validity
      corrections := corrections
  }

  match ← Loam.ActualAuthority.publishActualFile? actualFile evidence with
  | .error message => throw <| IO.userError ("publish Actual fixture: " ++ message)
  | .ok () => pure ()

  let code ← Loam.JournalExportCli.exportJournal actualFile.toString outputFile.toString
  expect (code == 0) "journal export returned nonzero"

  let output ← IO.FS.readFile outputFile
  expect (output.containsSubstr "journal-replacement")
    "journal export lost current correction replacement"
  expect (output.containsSubstr "journal-untouched")
    "journal export lost untouched current Event"
  expect (!output.containsSubstr "journal-original")
    "journal export retained superseded correction target"
  expect (output.containsSubstr "2026-09-02")
    "journal export lost replacement occurrence date"
  expect (output.containsSubstr "2026-09-03")
    "journal export lost untouched occurrence date"

  IO.println "Journal export consumed admitted current Actual views successfully."
