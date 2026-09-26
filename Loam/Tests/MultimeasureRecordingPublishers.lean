import Loam.ActualAuthority
import Loam.ExchangePublisher
import Loam.OriginalAmountMovementPublisher
import Loam.Tests.ActualWorldFixture

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some item => pure item
  | none => throw (IO.userError message)

private def emptyHistory : ActualValidityHistory String :=
  { facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp }

private def initialWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty EventMemory")
  let some loci := LocusAdmissionVocabulary.ofLoci? [
      ⟨"bank-jpy"⟩,
      ⟨"food"⟩,
      ⟨"cash-jpy"⟩,
      ⟨"cash-usd"⟩,
      ⟨"exchange-fee"⟩
    ]
    | throw (IO.userError "Locus admission fixture")
  return {
    events := events
    validity := emptyHistory
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := loci
  }

private def debitMovement : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-26"
  description := some "debit purchase"
  effects := [
    Effect.ofAnonymousQuantity
      ⟨"bank-jpy"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-4700)),
    Effect.ofAnonymousQuantity
      ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 4700)
  ]
  relations := []
  discharges := []
  total := 4700
}

private def exchangeDraft : Loam.ExchangeAdmission.Draft := {
  validOn := "2026-09-26"
  description := some "cash exchange"
  effects := [
    Effect.ofQuantity
      ⟨"jpy-source"⟩ ⟨"cash-jpy"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-15100)),
    Effect.ofQuantity
      ⟨"fee"⟩ ⟨"exchange-fee"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100),
    Effect.ofQuantity
      ⟨"usd-destination"⟩ ⟨"cash-usd"⟩ ⟨"usd"⟩ (Quantity.ofQuanta 100)
  ]
  source := ⟨"jpy-source"⟩
  destination := ⟨"usd-destination"⟩
}

def main (args : List String) : IO Unit := do
  let [dataPath] := args
    | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let world ← initialWorld
  let .ok () ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "initialize Actual fixture")

  -- 1. Ordinary JPY accounting and original USD amount publish atomically.
  let originalDraft : Loam.OriginalAmountMovementPublisher.Draft := {
    movement := debitMovement
    originalMeasure := ⟨"usd"⟩
    originalQuantity := Quantity.ofQuanta 3000
  }
  let .ok debitEvent ←
      Loam.OriginalAmountMovementPublisher.publish root.toString originalDraft
    | throw (IO.userError "publish Movement + original amount")

  let .ok afterDebit ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload after debit publication")
  let original ← requireSome
    (afterDebit.originalAmounts.findByEvent? debitEvent)
    "original amount missing after atomic publication"
  expect (original.measure == ⟨"usd"⟩ &&
      original.quantity.quanta == 3000)
    "original amount changed across authoritative publication"
  let debitStored ← requireSome
    (afterDebit.events.findById? debitEvent)
    "debit Event missing after publication"
  expect ((debitStored.quantityAt ⟨"bank-jpy"⟩ ⟨"jpy"⟩).quanta == -4700)
    "JPY accounting effect changed while retaining original amount"

  -- 2. Refused original amount leaves authority byte-for-byte unchanged.
  let actualPath := Loam.ActualAuthority.actualPath root
  let beforeBadOriginal ← IO.FS.readFile actualPath
  let badOriginal : Loam.OriginalAmountMovementPublisher.Draft := {
    movement := debitMovement
    originalMeasure := ⟨"usd"⟩
    originalQuantity := Quantity.ofQuanta 0
  }
  let refusedOriginal ←
    Loam.OriginalAmountMovementPublisher.publish root.toString badOriginal
  expect (!refusedOriginal.isOk)
    "zero original amount unexpectedly published"
  expect ((← IO.FS.readFile actualPath) == beforeBadOriginal)
    "refused original amount left a partial Movement publication"

  -- 3. Fee-bearing cross-Measure exchange Event + ExchangeEvidence publish atomically.
  let .ok exchangeEvent ←
      Loam.ExchangePublisher.publish root.toString exchangeDraft
    | throw (IO.userError "publish qualified exchange")

  let .ok afterExchange ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload after exchange publication")
  let retainedExchange ← requireSome
    (afterExchange.exchanges.findByEvent? exchangeEvent)
    "ExchangeEvidence missing after atomic publication"
  expect (retainedExchange.source == ⟨"jpy-source"⟩ &&
      retainedExchange.destination == ⟨"usd-destination"⟩)
    "ExchangeEvidence keys changed across publication"
  let exchangeStored ← requireSome
    (afterExchange.events.findById? exchangeEvent)
    "exchange Event missing after publication"
  expect ((exchangeStored.quantityAt ⟨"cash-jpy"⟩ ⟨"jpy"⟩).quanta == -15100)
    "exchange JPY source changed"
  expect ((exchangeStored.quantityAt ⟨"cash-usd"⟩ ⟨"usd"⟩).quanta == 100)
    "exchange USD destination changed"

  -- 4. Invalid exchange fails before authority switch and leaves no partial Event.
  let beforeBadExchange ← IO.FS.readFile actualPath
  let badExchange : Loam.ExchangeAdmission.Draft := {
    exchangeDraft with
    destination := ⟨"fee"⟩
  }
  let refusedExchange ← Loam.ExchangePublisher.publish root.toString badExchange
  expect (!refusedExchange.isOk)
    "same-Measure selected exchange unexpectedly published"
  expect ((← IO.FS.readFile actualPath) == beforeBadExchange)
    "refused exchange changed Actual authority"

  let .ok finalEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload final Actual authority")
  expect (finalEvidence.events.events.length == 2)
    "atomic multimeasure publishers retained an unexpected Event count"
  expect (finalEvidence.originalAmounts.entries.length == 1)
    "original amount publisher retained an unexpected evidence count"
  expect (finalEvidence.exchanges.entries.length == 1)
    "exchange publisher retained an unexpected evidence count"

  IO.println "Atomic OriginalAmount Movement and Exchange publication passed."
