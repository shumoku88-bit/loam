import Loam.ActualAuthority
import Loam.Persistence.ZeroOriginCoveragePersistence

open Loam.Core

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def balancedEvent
    (id : String)
    (wallet food : Int) : IO Event := do
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      Effect.ofAnonymousQuantity ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta wallet),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta food)
    ])
    ("event admission failed: " ++ id)

def main (args : List String) : IO Unit := do
  let root ←
    match args with
    | [path] => pure (System.FilePath.mk path)
    | _ => throw <| IO.userError "expected temporary root"
  IO.FS.createDirAll (root / "config")

  let original ← balancedEvent "quantity-original" (-100) 100
  let replacement ← balancedEvent "quantity-replacement" (-60) 60
  let untouched ← balancedEvent "quantity-untouched" (-15) 15

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

  match ← Loam.ActualAuthority.publishActualFile? (root / "actual.loam") evidence with
  | .error message => throw <| IO.userError ("publish Actual fixture: " ++ message)
  | .ok () => pure ()

  let coverage : ZeroOriginCoverage := {
    coordinates := [
      ⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩,
      ⟨⟨"food"⟩, ⟨"jpy"⟩⟩,
      ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
    ]
    nodup := by decide
  }
  unless ← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") coverage do
    throw <| IO.userError "save zero-origin coverage"

  IO.FS.writeFile (root / "config" / "balance-view.tsv")
    "wallet\tjpy\ncash\tjpy\n"

  IO.println "Actual quantity CLI fixture written."
