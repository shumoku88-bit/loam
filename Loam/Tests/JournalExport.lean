import Loam.ActualAuthority
import Loam.Persistence.AccountingRolePersistence

open Loam.Core

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def balancedEvent
    (id measure : String) (amount : Int) : IO Event := do
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      Effect.ofAnonymousQuantity ⟨"wallet"⟩ ⟨measure⟩ (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨measure⟩ (Quantity.ofQuanta amount)
    ])
    ("event admission failed: " ++ id)

def main (args : List String) : IO Unit := do
  let root ←
    match args with
    | [path] => pure (System.FilePath.mk path)
    | _ => throw <| IO.userError "expected temporary root"
  IO.FS.createDirAll root
  let actualFile := root / "actual.loam"
  let roleFile := root / "accounting-role.loam"

  let original ← balancedEvent "journal-original" "jpy" 100
  let replacement ← balancedEvent "journal-replacement" "jpy" 120
  let untouched ← balancedEvent "journal-untouched" "jpy" 40
  let usd ← balancedEvent "journal-usd" "usd" 1234
  let ils ← balancedEvent "journal-ils" "ils" 2790

  let events ← requireSome
    (EventMemory.ofEvents? [original, replacement, untouched, usd, ils])
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
      .base untouched.id "2026-09-03",
      .base usd.id "2026-09-04",
      .base ils.id "2026-09-05"
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

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"wallet"⟩, role := .asset }
      , { locus := ⟨"food"⟩, role := .expense }
      ])
    "AccountingRole fixture admission failed"
  unless ← Loam.Persistence.saveAccountingRoleMap? roleFile roles do
    throw <| IO.userError "save AccountingRole fixture"

  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile (root / "config" / "measure-presentation.tsv")
    "# measure\tdecimal-scale\njpy\t0\nusd\t2\nils\t2\n"

  IO.println "Journal export canonical multi-Measure fixture written."
