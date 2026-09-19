import Loam.RoleBalanceReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def findRow?
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (locus : String) : Option Loam.RoleBalanceReview.Row :=
  snapshot.rows.find? fun row => row.coordinate.locus.token == locus

private def findUnresolved?
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (locus : String) : Option Loam.RoleBalanceReview.UnresolvedRole :=
  snapshot.unresolvedRoles.find? fun row => row.coordinate.locus.token == locus

private def findUnsupported?
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (locus : String) : Option Loam.RoleBalanceReview.UnsupportedBalance :=
  snapshot.unsupportedBalances.find? fun row => row.coordinate.locus.token == locus

def main : IO Unit := do
  let receipt ← requireSome
    (Event.ofEffects? ⟨"receipt"⟩
      [effect "wallet-in" "wallet" 100, effect "income-out" "income" (-100)])
    "receipt event"
  let purchase ← requireSome
    (Event.ofEffects? ⟨"purchase"⟩
      [effect "wallet-out" "wallet" (-30), effect "food-in" "food" 30])
    "purchase event"
  let ambiguous ← requireSome
    (Event.ofEffects? ⟨"ambiguous"⟩
      [effect "wallet-out-2" "wallet" (-5), effect "mystery-in" "mystery" 5])
    "ambiguous event"
  let ghostEvent ← requireSome
    (Event.ofEffects? ⟨"opaque"⟩
      [effect "ghost-a-in" "ghost-a" 7, effect "ghost-b-out" "ghost-b" (-7)])
    "opaque event"
  let debtOpening ← requireSome
    (Event.ofEffects? ⟨"debt-opening"⟩ [effect "debt-opening-effect" "debt" (-100)])
    "debt opening event"
  let debtRepayment ← requireSome
    (Event.ofEffects? ⟨"debt-repayment"⟩ [effect "debt-repayment-effect" "debt" 20])
    "debt repayment event"

  let events ← requireSome
    (EventMemory.ofEvents? [receipt, purchase, ambiguous, ghostEvent, debtOpening, debtRepayment])
    "event memory"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? []) "correction memory"

  let wallet : EffectCoordinate := ⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let mystery : EffectCoordinate := ⟨⟨"mystery"⟩, ⟨"jpy"⟩⟩
  let debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩
  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [wallet, cash, mystery])
    "zero-origin coverage"
  let openingSupport ← requireSome
    (OpeningSupportMap.ofSupports? [{ coordinate := debt, openingEvent := debtOpening.id }])
    "opening support"
  let currentAnchor := Loam.CurrentQuantityAnchor.Evidence.empty

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"wallet"⟩, role := .asset },
      { locus := ⟨"cash"⟩, role := .asset },
      { locus := ⟨"debt"⟩, role := .liability },
      { locus := ⟨"income"⟩, role := .income },
      { locus := ⟨"food"⟩, role := .expense }
    ])
    "role map"

  let evidence : Loam.BalanceReview.Evidence := {
    events := events
    corrections := corrections
    coverage := coverage
  }
  let .ok snapshot := Loam.RoleBalanceReview.project evidence openingSupport currentAnchor roles
    | throw (IO.userError "role balance fixture refused")

  let walletRow ← requireSome (findRow? snapshot "wallet") "wallet balance row"
  let cashRow ← requireSome (findRow? snapshot "cash") "cash balance row"
  let debtRow ← requireSome (findRow? snapshot "debt") "opening-supported debt row"
  expect (walletRow.quantity.quanta == 65) "wallet current balance changed"
  expect (cashRow.quantity.quanta == 0) "covered zero balance disappeared"
  expect (debtRow.quantity.quanta == -80) "opening-supported debt balance changed"
  expect (decide (walletRow.role = AccountingRole.asset)) "wallet role changed"
  expect (decide (cashRow.role = AccountingRole.asset)) "cash role changed"
  expect (decide (debtRow.role = AccountingRole.liability)) "debt role changed"

  let mysteryRow ← requireSome (findUnresolved? snapshot "mystery") "missing unresolved role row"
  expect (mysteryRow.quantity.quanta == 5) "supported unresolved quantity changed"

  let incomeUnsupported ← requireSome (findUnsupported? snapshot "income") "missing income support frontier"
  let foodUnsupported ← requireSome (findUnsupported? snapshot "food") "missing expense support frontier"
  expect
    (match incomeUnsupported.role with | some .income => true | _ => false)
    "unsupported income classification disappeared"
  expect
    (match foodUnsupported.role with | some .expense => true | _ => false)
    "unsupported expense classification disappeared"
  expect (findUnsupported? snapshot "debt").isNone
    "opening-supported debt remained in unsupported frontier"

  let ghostUnsupported ← requireSome
    (findUnsupported? snapshot "ghost-a")
    "missing quantity-and-role unsupported coordinate"
  expect ghostUnsupported.role.isNone
    "quantity-unsupported coordinate unexpectedly gained a role"
  expect (findUnresolved? snapshot "ghost-a").isNone
    "quantity-and-role unsupported coordinate was duplicated across frontiers"

  let .ok physical := Loam.BalanceReview.project events corrections coverage [wallet, cash, mystery]
    | throw (IO.userError "neighboring BalanceReview refused covered coordinates")
  let physicalWallet ← requireSome
    (physical.rows.find? fun row => row.coordinate.locus.token == "wallet")
    "physical wallet row"
  expect (physicalWallet.quantity.quanta == walletRow.quantity.quanta)
    "RoleBalance introduced a second quantity calculation"

  expect
    (match Loam.BalanceReview.project events corrections coverage [debt] with
      | .error _ => true
      | .ok _ => false)
    "opening support leaked into zero-origin BalanceReview"

  -- Canonical admitted-image projection must reuse the carried current Event
  -- frontier while preserving the raw/in-memory answer.
  let correctedPurchase ← requireSome
    (Event.ofEffects? ⟨"purchase-corrected"⟩
      [effect "wallet-out-corrected" "wallet" (-40),
       effect "food-in-corrected" "food" 40])
    "corrected purchase event"
  let correctedEvents ← requireSome
    (EventMemory.ofEvents?
      [receipt, purchase, correctedPurchase, ambiguous, ghostEvent])
    "corrected event memory"
  let correctedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := purchase.id, replacement := correctedPurchase.id }])
    "corrected correction memory"
  let correctedValidity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base receipt.id "2026-09-01",
      .base purchase.id "2026-09-02",
      .base correctedPurchase.id "2026-09-03",
      .base ambiguous.id "2026-09-04",
      .base ghostEvent.id "2026-09-05"
    ] [])
    "corrected validity history"
  let correctedActual : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := correctedEvents
      validity := correctedValidity
      corrections := correctedCorrections
  }
  let correctedImage ← requireSome
    (Loam.Persistence.admitActualImage? correctedActual)
    "corrected admitted Actual image"
  let .ok imageSnapshot :=
      Loam.RoleBalanceReview.projectImage
        correctedImage coverage OpeningSupportMap.empty currentAnchor roles
    | throw (IO.userError "admitted-image Role Balance refused corrected fixture")
  let imageWallet ← requireSome (findRow? imageSnapshot "wallet")
    "missing admitted-image wallet row"
  expect (imageWallet.quantity.quanta == 55)
    "admitted-image Role Balance did not follow corrected current Event frontier"

  let correctedEvidence : Loam.BalanceReview.Evidence := {
    events := correctedEvents
    corrections := correctedCorrections
    coverage := coverage
  }
  let .ok rawCorrected :=
      Loam.RoleBalanceReview.project correctedEvidence OpeningSupportMap.empty currentAnchor roles
    | throw (IO.userError "raw Role Balance refused corrected fixture")
  expect (decide (imageSnapshot = rawCorrected))
    "admitted-image and raw Role Balance projections diverged"

  let .ok withoutOpening :=
      Loam.RoleBalanceReview.project evidence OpeningSupportMap.empty currentAnchor roles
    | throw (IO.userError "empty opening-support fixture refused")
  let debtUnsupported ← requireSome
    (findUnsupported? withoutOpening "debt")
    "missing debt frontier without opening support"
  expect
    (match debtUnsupported.role with | some .liability => true | _ => false)
    "unsupported debt role disappeared"

  let encoded ← requireSome
    (Loam.Persistence.encodeOpeningSupportMap? openingSupport)
    "opening support encoding"
  let decoded ← requireSome
    (Loam.Persistence.decodeOpeningSupportMap? encoded)
    "opening support decoding"
  expect (decide (decoded = openingSupport)) "opening support persistence roundtrip changed"
  expect
    (OpeningSupportMap.ofSupports? [
      { coordinate := debt, openingEvent := debtOpening.id },
      { coordinate := debt, openingEvent := debtRepayment.id }
    ]).isNone
    "duplicate opening support coordinate was admitted"

  expect (snapshot.unsupportedBalances.length == 4)
    "unsupported balance frontier changed unexpectedly"

  IO.println
    "Role Balance Review: zero-origin, opening and optional current-anchor support compose one current view."
