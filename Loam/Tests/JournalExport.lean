import Loam.ActualAuthority

open Loam.Core

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

  IO.println "Journal export canonical fixture written."
