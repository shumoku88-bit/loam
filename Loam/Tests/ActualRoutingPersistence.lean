import Loam.Application.ActualRoutingInspection
import Loam.Persistence.ActualRoutingPersistence

open Loam.Core
open Loam.Application
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def food : PurposeId := ⟨"food"⟩
private def household : PurposeId := ⟨"household"⟩
private def groceries : LocusId := ⟨"groceries"⟩
private def coffee : LocusId := ⟨"coffee"⟩
private def paypay : LocusId := ⟨"paypay"⟩

def main : IO Unit := do
  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := groceries,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some food },
       { subject := groceries,
         effectiveOn := RoutingEffective.from "2026-08-17",
         purpose := some household },
       { subject := coffee,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := none }])
    "initial-aware Actual routing fixture was not admitted"

  expect (routing.statusAt groceries (.from "2026-08-16") == .managed food)
    "initial route was not visible before the first dated override"
  expect (routing.statusAt groceries (.from "2026-08-17") == .managed household)
    "first-day dated override did not supersede the distinct initial route"
  expect (routing.statusAt coffee (.from "2026-08-17") == .unmanaged)
    "explicitly unmanaged initial route was lost"
  expect (routing.statusAt ⟨"unseen"⟩ (.from "2026-08-17") == .unrouted)
    "absence of routing evidence stopped being unrouted"

  let encoded ← requireSome
    (encodeActualRoutingHistory? routing)
    "Actual routing fixture could not be encoded"
  let decoded ← requireSome
    (decodeActualRoutingHistory? encoded)
    "encoded Actual routing fixture did not decode"
  let reencoded ← requireSome
    (encodeActualRoutingHistory? decoded)
    "decoded Actual routing fixture could not be re-encoded"
  expect (encoded == reencoded)
    "Actual routing decode/encode changed canonical bytes"
  expect (decoded.statusAt groceries (.from "2026-08-17") == .managed household)
    "Actual routing persistence changed selected route"

  let permuted ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := none },
       { subject := groceries,
         effectiveOn := RoutingEffective.from "2026-08-17",
         purpose := some household },
       { subject := groceries,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some food }])
    "permuted Actual routing fixture was not admitted"
  expect
    (routing.statusAt groceries (.from "2026-08-16") ==
      permuted.statusAt groceries (.from "2026-08-16"))
    "routing row order changed pre-override answer"
  expect
    (routing.statusAt groceries (.from "2026-08-17") ==
      permuted.statusAt groceries (.from "2026-08-17"))
    "routing row order changed dated override answer"

  expect
    ((RoutingHistory.ofEntries?
      [{ subject := groceries,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some food },
       { subject := groceries,
         effectiveOn := (RoutingEffective.initial : RoutingEffective String),
         purpose := some household }]).isNone)
    "duplicate initial routing coordinate was admitted"

  let badDate :=
    "LOAM-ACTUAL-ROUTING\t1\n" ++
    "ROUTE\tgroceries\tFROM\t2026-02-29\tMANAGED\tfood\n"
  expect ((decodeActualRoutingHistory? badDate).isNone)
    "impossible dated routing coordinate was admitted"

  let earlyActual ← requireSome
    (Event.ofEffects? ⟨"actual-early"⟩
      [Effect.ofQuantity ⟨"early-pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"early-use"⟩ groceries yen (Quantity.ofQuanta 30)])
    "early Actual fixture was not admitted"
  let laterActual ← requireSome
    (Event.ofEffects? ⟨"actual-later"⟩
      [Effect.ofQuantity ⟨"later-pay"⟩ paypay yen (Quantity.ofQuanta (-40)),
       Effect.ofQuantity ⟨"later-use"⟩ groceries yen (Quantity.ofQuanta 40)])
    "later Actual fixture was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [earlyActual, laterActual])
    "Actual memory fixture was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-early"⟩, validOn := "2026-08-16" },
       { event := ⟨"actual-later"⟩, validOn := "2026-08-17" }])
    "Actual validity fixture was not admitted"

  let foodConsumption ← requireSome
    (consumptionAtRecordedEffectiveRouting? events validities decoded food yen)
    "food Consumption failed closed"
  let householdConsumption ← requireSome
    (consumptionAtRecordedEffectiveRouting? events validities decoded household yen)
    "household Consumption failed closed"
  expect (foodConsumption.quanta == 30)
    s!"expected initial-routed food Consumption 30, got {foodConsumption.quanta}"
  expect (householdConsumption.quanta == 40)
    s!"expected dated-routed household Consumption 40, got {householdConsumption.quanta}"

  IO.println "Actual routing persistence practical story succeeded."
