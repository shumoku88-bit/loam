import Loam.Tests.ActualWorldFixture
import Loam.ActualAuthority
import Loam.EventMerchantPublisher
import Loam.MovementPublisher

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def emptyHistory : ActualValidityHistory String :=
  { facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp }

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"wallet"⟩, ⟨"expense"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := emptyHistory
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def effects (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"expense"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def recordDraft
    (validOn description : String)
    (amount : Int) : Loam.MovementAdmission.Draft := {
  validOn := validOn
  description := some description
  effects := effects amount
  relations := []
  discharges := []
  total := amount }

private def expectDisposition
    (root : System.FilePath)
    (event : EventId)
    (expected : MerchantDisposition) : IO Unit := do
  let .ok evidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload Actual authority")
  expect (decide (evidence.merchants.findDisposition? event = some expected))
    "persisted Merchant disposition did not match the admitted classification"

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let root := System.FilePath.mk dataPath
  let initial ← emptyWorld
  let .ok () ← Loam.Tests.ActualWorldFixture.publishWorld? root initial
    | throw (IO.userError "initialize Actual fixture")

  let .ok merchantEvent ← Loam.MovementPublisher.publishDraft
      root.toString (recordDraft "2026-09-17" "merchant candidate" 640)
    | throw (IO.userError "record merchant target fixture")
  let .ok nonmerchantEvent ← Loam.MovementPublisher.publishDraft
      root.toString (recordDraft "2026-09-17" "nonmerchant candidate" 1200)
    | throw (IO.userError "record nonmerchant target fixture")

  let actualFile := root / Loam.ActualAuthority.actualFileName

  let beforeMissing ← IO.FS.readFile actualFile
  let missing ← Loam.EventMerchantPublisher.publishDisposition
    root.toString { target := ⟨"missing-event"⟩, disposition := .nonmerchant }
  expect (!missing.isOk) "missing Event target was classified"
  expect ((← IO.FS.readFile actualFile) == beforeMissing)
    "missing Event refusal changed Actual authority"

  let beforeMalformed ← IO.FS.readFile actualFile
  let malformed ← Loam.EventMerchantPublisher.publishDisposition
    root.toString {
      target := merchantEvent
      disposition := .merchant ⟨"bad\tparty"⟩ }
  expect (!malformed.isOk) "malformed Merchant party token was admitted"
  expect ((← IO.FS.readFile actualFile) == beforeMalformed)
    "malformed Merchant refusal changed Actual authority"

  let party : ExternalPartyId := ⟨"coffee-shop"⟩
  let .ok () ← Loam.EventMerchantPublisher.publishDisposition
      root.toString { target := merchantEvent, disposition := .merchant party }
    | throw (IO.userError "Merchant classification was refused")
  expectDisposition root merchantEvent (.merchant party)

  let beforeDuplicate ← IO.FS.readFile actualFile
  let duplicate ← Loam.EventMerchantPublisher.publishDisposition
    root.toString { target := merchantEvent, disposition := .nonmerchant }
  expect (!duplicate.isOk) "already-classified Event accepted replacement disposition"
  expect ((← IO.FS.readFile actualFile) == beforeDuplicate)
    "duplicate Merchant refusal changed Actual authority"

  let .ok () ← Loam.EventMerchantPublisher.publishDisposition
      root.toString { target := nonmerchantEvent, disposition := .nonmerchant }
    | throw (IO.userError "explicit nonmerchant classification was refused")
  expectDisposition root nonmerchantEvent .nonmerchant

  let .ok finalEvidence ← Loam.ActualAuthority.loadActual? root
    | throw (IO.userError "reload final Actual authority")
  expect (finalEvidence.events.events.length == 2)
    "Merchant publication changed retained Event count"
  expect (finalEvidence.merchants.entries.length == 2)
    "Merchant publication did not retain exactly one disposition per classified Event"

  IO.println "Event Merchant Publisher: missing target, token validation, first classification, duplicate refusal and atomic publication passed."
