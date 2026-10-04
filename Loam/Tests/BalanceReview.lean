import Loam.Tests.ActualWorldFixture
import Loam.Authority.ActualAuthority
import Loam.Review.BalanceReview
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Tests.Support

open Loam.Core
open Loam.Tests.Support

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
  let actualRoot := root
  IO.FS.createDirAll (root / "config")

  let validCoverageBody ← requireSome
    (Loam.Persistence.encodeZeroOriginCoverage? validCoverage)
    "encode Household zero-origin coverage"
  let .ok _ ←
      Loam.Tests.ActualWorldFixture.publishHouseholdSection?
        root "ZeroOrigin" validCoverageBody
    | throw (IO.userError "install Household zero-origin coverage")
  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") ZeroOriginCoverage.empty)
    "save stale legacy zero-origin coverage"
  let frozenLegacyCoverage ← IO.FS.readFile (root / "zero-origin-coverage.loam")
  IO.FS.writeFile (root / "config" / "balance-view.tsv")
    "wallet\tjpy\ncash\tjpy\nwallet\tjpy\n"

  let world ← movementWorld
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? actualRoot world
    | throw (IO.userError "publish selected Movement world")
  let validHouseholdWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.path root)

  -- Frozen pre-cutover Movement sidecars must not influence the production balance view.
  IO.FS.writeFile (root / "memory.loam") "THIS FROZEN SIDECAR MUST NOT BE READ\n"

  let .ok snapshot ← Loam.BalanceReview.loadSnapshot root actualRoot
    | throw (IO.userError "balance review refused valid fixture")
  expect (snapshot.rows.length == 2) "balance-view duplicate was not normalized"
  let walletRow ← requireSome (findRow? snapshot "wallet") "missing wallet row"
  expect (walletRow.quantity.quanta == 70)
    "wallet balance did not derive from reconstructed zero-origin Event history"
  let cashRow ← requireSome (findRow? snapshot "cash") "missing cash row"
  expect (cashRow.quantity.quanta == 0) "explicit covered zero disappeared"

  let wallet : EffectCoordinate := ⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let food : EffectCoordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩

  -- A valid correction world is admitted once and shared by every covered row.
  let validCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := ⟨"opening"⟩, replacement := ⟨"actual-1"⟩ }])
    "valid correction memory"
  let .ok correctedSnapshot :=
      Loam.BalanceReview.project world.events validCorrections validCoverage [wallet, cash]
    | throw (IO.userError "shared correction basis refused valid rows")
  let correctedWallet ← requireSome (findRow? correctedSnapshot "wallet")
    "missing corrected wallet row"
  expect (correctedWallet.quantity.quanta == -30)
    "shared correction basis did not project the admitted Event frontier"
  let correctedCash ← requireSome (findRow? correctedSnapshot "cash")
    "missing corrected cash row"
  expect (correctedCash.quantity.quanta == 0)
    "shared correction basis lost an explicitly covered zero"

  -- The canonical authority path should reuse the already-admitted current Event
  -- basis and return the same correction-aware quantities without rebuilding the
  -- frontier inside BalanceReview.
  let correctedEvidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := world.events
      validity := world.validity
      corrections := validCorrections
  }
  match ← Loam.ActualAuthority.publishActual? actualRoot correctedEvidence with
  | .error message =>
      throw (IO.userError ("publish corrected canonical Actual: " ++ message))
  | .ok () => pure ()
  let .ok canonicalCorrected ← Loam.BalanceReview.loadSnapshot root actualRoot
    | throw (IO.userError "canonical admitted Balance Review refused corrected fixture")
  let canonicalWallet ← requireSome (findRow? canonicalCorrected "wallet")
    "missing canonical corrected wallet row"
  expect (canonicalWallet.quantity.quanta == -30)
    "canonical Balance Review did not reuse admitted correction frontier"
  let canonicalCash ← requireSome (findRow? canonicalCorrected "cash")
    "missing canonical corrected cash row"
  expect (canonicalCash.quantity.quanta == 0)
    "canonical Balance Review lost explicitly covered zero"

  -- Empty selection remains lazy: malformed correction topology is irrelevant
  -- when no balance row is requested.
  let brokenCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := ⟨"opening"⟩, replacement := ⟨"missing"⟩ }])
    "broken correction memory"
  expect
    ((Loam.BalanceReview.project world.events brokenCorrections validCoverage []).isOk)
    "empty Balance Review forced an unused correction obligation"

  -- Refusal ordering is part of the qualified boundary. An uncovered first row
  -- refuses before the shared correction world is forced.
  match Loam.BalanceReview.project
      world.events brokenCorrections validCoverage [food, wallet] with
  | .error message =>
      expect
        (message ==
          "loam: balances unavailable: zero-origin coverage missing for food / jpy")
        "uncovered-first Balance Review changed refusal ordering"
  | .ok _ =>
      throw (IO.userError "uncovered-first Balance Review unexpectedly succeeded")

  -- Once the first row is covered, correction admission still precedes all later
  -- row gates, matching the former row-local inspection path.
  match Loam.BalanceReview.project
      world.events brokenCorrections validCoverage [wallet, food] with
  | .error message =>
      expect
        (message == "loam: balances unavailable: correction references are not closed")
        "covered-first Balance Review changed correction refusal ordering"
  | .ok _ =>
      throw (IO.userError "covered-first broken correction unexpectedly succeeded")

  -- Caller-selected Actual authority is exact; a missing selected root must not
  -- silently fall back to the valid Actual authority under dataDir.
  let missingSelectedRoot := root / "missing-selected-actual"
  let selectedAuthorityMissing ← Loam.BalanceReview.loadSnapshot root missingSelectedRoot
  expect (!selectedAuthorityMissing.isOk)
    "Balance Review silently fell back from the selected Actual authority"

  -- Event activity and presentation selection do not create origin completeness.
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "food\tjpy\n"
  let missingCoverage ← Loam.BalanceReview.loadSnapshot root actualRoot
  expect (!missingCoverage.isOk) "Event activity outside zero-origin coverage became known"

  -- Duplicate Household coverage is malformed evidence, not a
  -- set-normalization hint. Write malformed inner evidence directly because
  -- the qualified Household publisher correctly refuses such a candidate.
  let validHouseholdImage ← requireSome
    (Loam.Persistence.HouseholdImage.decode? validHouseholdWire)
    "decode valid Household fixture"
  let duplicateHouseholdImage ← requireSome
    (Loam.Persistence.HouseholdImage.replaceBody?
      validHouseholdImage "ZeroOrigin"
      "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\twallet\tjpy\nCOORDINATE\twallet\tjpy\n")
    "construct duplicate Household zero-origin fixture"
  let duplicateHouseholdWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? duplicateHouseholdImage)
    "encode duplicate Household zero-origin fixture"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) duplicateHouseholdWire
  let duplicateCoverage ← Loam.BalanceReview.loadSnapshot root actualRoot
  expect (!duplicateCoverage.isOk) "duplicate Household zero-origin coverage did not fail closed"

  let malformedHouseholdImage ← requireSome
    (Loam.Persistence.HouseholdImage.replaceBody?
      validHouseholdImage "ZeroOrigin" "BROKEN\n")
    "construct malformed Household zero-origin fixture"
  let malformedHouseholdWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? malformedHouseholdImage)
    "encode malformed Household zero-origin fixture"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) malformedHouseholdWire
  let malformedCoverage ← Loam.BalanceReview.loadSnapshot root actualRoot
  expect (!malformedCoverage.isOk) "malformed Household zero-origin coverage did not fail closed"

  IO.FS.writeFile (Loam.HouseholdAuthority.path root) validHouseholdWire
  expect ((← IO.FS.readFile (root / "zero-origin-coverage.loam")) == frozenLegacyCoverage)
    "production BalanceReview changed frozen legacy zero-origin evidence"
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "wallet\tjpy\n"
  IO.FS.writeFile (actualRoot / "actual.loam")
    "LOAM_ACTUAL_v1\nTX\tactual-2\t2026-09-08\treplaces:missing\n  wallet\t-10\tjpy\n  food\t10\tjpy\n"
  let staleLegacyIgnored ← Loam.BalanceReview.loadSnapshot root actualRoot
  expect staleLegacyIgnored.isOk
    "stale malformed standalone Actual leaked into production Balance Review"

  IO.println
    "Balance Review: shared correction basis, refusal ordering, Household Actual authority, zero-origin coverage and stale-legacy isolation passed."
