import Loam.ActualAuthority
import Loam.Persistence.AccountingRolePersistence

open Loam.Core

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def balancedEvent (id : String) (locus1 locus2 : String) (amount : Int) : IO Event := do
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      Effect.ofAnonymousQuantity ⟨locus1⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨locus2⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
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

  let e1 ← balancedEvent "event-food" "wallet" "food" 100
  let e2 ← balancedEvent "event-unknown" "wallet" "unknown_locus" 200

  let events ← requireSome
    (EventMemory.ofEvents? [e1, e2])
    "event memory admission failed"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base e1.id "2026-09-01",
      .base e2.id "2026-09-02"
    ] [])
    "validity history admission failed"

  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := events
      validity := validity
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

  IO.println "Beancount export partial canonical fixture written."
