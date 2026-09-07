import Loam.BalanceReview
import Loam.Persistence.QuantityBasisPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect (id locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨id⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def movementWorld : IO Loam.MovementAdmission.World := do
  let event ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [effect "wallet-out" "wallet" (-30), effect "food-in" "food" 30])
    "event"
  let events ← requireSome (EventMemory.ofEvents? [event]) "event memory"
  let validity : ActualValidityHistory String := {
    facts := [{ id := ⟨"validity-1"⟩, event := ⟨"actual-1"⟩, validOn := "2026-09-07" }]
    factIdNodup := by decide
    corrections := []
    correctionIdNodup := by simp
  }
  return {
    events := events
    validity := validity
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := .empty
  }

private def findRow?
    (snapshot : Loam.BalanceReview.Snapshot)
    (locus : String) : Option Loam.BalanceReview.Row :=
  snapshot.rows.find? fun row => row.coordinate.locus.token == locus


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let manifestRoot := root / "movement-authority"
  IO.FS.createDirAll root

  let wallet := QuantityBasis.ofQuantity
    ⟨"basis-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
  let cash := QuantityBasis.ofQuantity
    ⟨"basis-cash"⟩ ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 0)
  let bases ← requireSome (QuantityBasisMemory.ofBases? [wallet, cash]) "basis memory"
  expect (← Loam.Persistence.saveQuantityBasisMemory? (root / "basis.loam") bases)
    "save basis memory"
  IO.FS.writeFile (root / "balance-view.tsv") "wallet\tjpy\ncash\tjpy\nwallet\tjpy\n"

  let world ← movementWorld
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? manifestRoot world
    | throw (IO.userError "publish selected Movement world")

  -- Frozen pre-cutover Movement sidecars must not influence the production balance view.
  IO.FS.writeFile (root / "memory.loam") "THIS FROZEN SIDECAR MUST NOT BE READ\n"

  let .ok snapshot ← Loam.BalanceReview.loadSnapshot root manifestRoot
    | throw (IO.userError "balance review refused valid fixture")
  expect (snapshot.rows.length == 2) "balance-view duplicate was not normalized"
  let walletRow ← requireSome (findRow? snapshot "wallet") "missing wallet row"
  expect (walletRow.quantity.quanta == 70) "wallet balance did not compose basis and manifest Event"
  let cashRow ← requireSome (findRow? snapshot "cash") "missing cash row"
  expect (cashRow.quantity.quanta == 0) "explicit zero balance disappeared"

  IO.FS.writeFile (root / "balance-view.tsv") "food\tjpy\n"
  let missingBasis ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!missingBasis.isOk) "selected coordinate without basis did not fail closed"

  IO.FS.writeFile (root / "balance-view.tsv") "wallet\tjpy\n"
  IO.FS.writeFile (root / "basis-corrections.loam") "BROKEN\n"
  let brokenBasisFrontier ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!brokenBasisFrontier.isOk) "malformed basis-correction evidence did not refuse"

  IO.println "Balance Review: manifest authority, explicit zero, view selection and fail-closed basis evidence passed."
