import Loam.ActualAuthority
import Loam.BalanceReview
import Loam.Persistence.ZeroOriginCoveragePersistence

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
  let opening ← requireSome
    (Event.ofEffects? ⟨"opening"⟩
      [effect "opening-source" "opening-source" (-100), effect "opening-wallet" "wallet" 100])
    "opening event"
  let purchase ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [effect "wallet-out" "wallet" (-30), effect "food-in" "food" 30])
    "purchase event"
  let events ← requireSome (EventMemory.ofEvents? [opening, purchase]) "event memory"
  let validity : ActualValidityHistory String := {
    facts := [
      .base ⟨"opening"⟩ "2026-09-01",
      .base ⟨"actual-1"⟩ "2026-09-07"
    ]
    factRefNodup := by decide
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

private def validCoverage : ZeroOriginCoverage :=
  { coordinates := [⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩, ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩]
    nodup := by decide }


def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let manifestRoot := root / "movement-authority"
  IO.FS.createDirAll (root / "config")

  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") validCoverage)
    "save zero-origin coverage"
  IO.FS.writeFile (root / "config" / "balance-view.tsv")
    "wallet\tjpy\ncash\tjpy\nwallet\tjpy\n"

  let world ← movementWorld
  let .ok _ ← Loam.ActualAuthority.publishWorld? manifestRoot world
    | throw (IO.userError "publish selected Movement world")

  -- Frozen pre-cutover Movement sidecars must not influence the production balance view.
  IO.FS.writeFile (root / "memory.loam") "THIS FROZEN SIDECAR MUST NOT BE READ\n"

  let .ok snapshot ← Loam.BalanceReview.loadSnapshot root manifestRoot
    | throw (IO.userError "balance review refused valid fixture")
  expect (snapshot.rows.length == 2) "balance-view duplicate was not normalized"
  let walletRow ← requireSome (findRow? snapshot "wallet") "missing wallet row"
  expect (walletRow.quantity.quanta == 70)
    "wallet balance did not derive from reconstructed zero-origin Event history"
  let cashRow ← requireSome (findRow? snapshot "cash") "missing cash row"
  expect (cashRow.quantity.quanta == 0) "explicit covered zero disappeared"

  -- Event activity and presentation selection do not create origin completeness.
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "food\tjpy\n"
  let missingCoverage ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!missingCoverage.isOk) "Event activity outside zero-origin coverage became known"

  -- Duplicate coverage is malformed evidence, not a set-normalization hint.
  IO.FS.writeFile (root / "zero-origin-coverage.loam")
    "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\twallet\tjpy\nCOORDINATE\twallet\tjpy\n"
  let duplicateCoverage ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!duplicateCoverage.isOk) "duplicate zero-origin coverage did not fail closed"

  IO.FS.writeFile (root / "zero-origin-coverage.loam") "BROKEN\n"
  let malformedCoverage ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!malformedCoverage.isOk) "malformed zero-origin coverage did not fail closed"

  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") validCoverage)
    "restore zero-origin coverage"
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "wallet\tjpy\n"
  IO.FS.writeFile (manifestRoot / "actual.loam")
    "LOAM_ACTUAL_v1\nTX\tactual-2\t2026-09-08\treplaces:missing\n  wallet\t-10\tjpy\n  food\t10\tjpy\n"
  let brokenEventCorrection ← Loam.BalanceReview.loadSnapshot root manifestRoot
  expect (!brokenEventCorrection.isOk) "missing Event correction endpoint did not refuse"

  IO.println
    "Balance Review: manifest authority, zero-origin coverage, independent view selection and fail-closed Event corrections passed."