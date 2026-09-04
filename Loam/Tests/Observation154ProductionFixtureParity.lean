import Loam.Application.ActualValidityFrontier
import Loam.Observations.Observation152
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private structure SidecarBytes where
  events : String
  validity : String
  descriptions : String
  corrections : Option String
  deriving Repr, BEq

private structure ProductionProjection where
  eventCount : Nat
  effectCount : Nat
  firstWallet : Int
  secondWallet : Int
  firstDate : Option String
  secondDate : Option String
  firstDescription : Option String
  secondDescription : Option String
  correctionCount : Nat
  correctionsProject : Bool
  deriving Repr, BEq

private def fixtureEventMemory : String :=
  "LOAM-EVENT-MEMORY\t1\n" ++
  "EVENT\tevent-1\n" ++
  "EFFECT\teffect-a\twallet\tjpy\t-1000\n" ++
  "EFFECT\teffect-b\tmerchant\tjpy\t1000\n" ++
  "EVENT\tevent-2\n" ++
  "EFFECT\teffect-c\twallet\tjpy\t-1200\n" ++
  "EFFECT\teffect-d\tmerchant\tjpy\t1200\n"

private def fixtureValidity : String :=
  "LOAM-ACTUAL-VALIDITY-HISTORY\t2\n" ++
  "BASE\tevent-1\t2026-09-01\n" ++
  "BASE\tevent-2\t2026-09-02\n"

private def fixtureDescriptions : String :=
  "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
  "DESC\tevent-1\tpublic original\n" ++
  "DESC\tevent-2\tpublic replacement\n"

private def fixtureCorrections : String :=
  "LOAM-EVENT-CORRECTION-MEMORY\t1\n" ++
  "CORRECTION\tcorrection-1\tevent-1\tevent-2\n"

private def fixture : SidecarBytes :=
  { events := fixtureEventMemory
    validity := fixtureValidity
    descriptions := fixtureDescriptions
    corrections := some fixtureCorrections }

private def textPayload (text : String) : List Nat :=
  text.toList.map Char.toNat

private def payloadText (payload : List Nat) : String :=
  String.ofList (payload.map Char.ofNat)

private def pack (sidecars : SidecarBytes) : List Nat :=
  Loam.Observation152.encode {
    events := textPayload sidecars.events
    validity := textPayload sidecars.validity
    descriptions := textPayload sidecars.descriptions
    corrections := sidecars.corrections.map textPayload
  }

private def unpack? (wire : List Nat) : Option SidecarBytes := do
  let decoded ← Loam.Observation152.decode wire
  pure {
    events := payloadText decoded.events
    validity := payloadText decoded.validity
    descriptions := payloadText decoded.descriptions
    corrections := decoded.corrections.map payloadText
  }

private def canonicalize? (sidecars : SidecarBytes) : Option SidecarBytes := do
  let events ← Loam.Persistence.decodeEventMemory? sidecars.events
  let validity ← Loam.Persistence.decodeActualValidityHistory? sidecars.validity
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? sidecars.descriptions
  let corrections ← match sidecars.corrections with
    | none => pure none
    | some text => do
        let memory ← Loam.Persistence.decodeEventCorrectionMemory? text
        pure (some memory)
  let eventText ← Loam.Persistence.encodeEventMemory? events
  let validityText ← Loam.Persistence.encodeActualValidityHistory? validity
  let descriptionText ← Loam.Persistence.encodeEventDescriptionMemory? descriptions
  let correctionText ← match corrections with
    | none => pure none
    | some memory => do
        let text ← Loam.Persistence.encodeEventCorrectionMemory? memory
        pure (some text)
  pure {
    events := eventText
    validity := validityText
    descriptions := descriptionText
    corrections := correctionText
  }

private def emptyCorrectionMemory? : Option EventCorrectionMemory :=
  EventCorrectionMemory.ofCorrections? []

private def productionProjection? (sidecars : SidecarBytes) : Option ProductionProjection := do
  let events ← Loam.Persistence.decodeEventMemory? sidecars.events
  let validityHistory ← Loam.Persistence.decodeActualValidityHistory? sidecars.validity
  let validity ← admittedActualValidityMemory? validityHistory
  let descriptions ← Loam.Persistence.decodeEventDescriptionMemory? sidecars.descriptions
  let corrections ← match sidecars.corrections with
    | none => emptyCorrectionMemory?
    | some text => Loam.Persistence.decodeEventCorrectionMemory? text
  let first ← EventMemory.findById? events ⟨"event-1"⟩
  let second ← EventMemory.findById? events ⟨"event-2"⟩
  let effectCount := events.events.foldl (fun total event => total + event.effects.length) 0
  pure {
    eventCount := events.events.length
    effectCount := effectCount
    firstWallet := (Event.quantityAt first ⟨"wallet"⟩ ⟨"jpy"⟩).quanta
    secondWallet := (Event.quantityAt second ⟨"wallet"⟩ ⟨"jpy"⟩).quanta
    firstDate := ActualValidityMemory.findByEventId? validity ⟨"event-1"⟩
    secondDate := ActualValidityMemory.findByEventId? validity ⟨"event-2"⟩
    firstDescription := EventDescriptionMemory.findText? descriptions ⟨"event-1"⟩
    secondDescription := EventDescriptionMemory.findText? descriptions ⟨"event-2"⟩
    correctionCount := corrections.corrections.length
    correctionsProject := corrections.corrections.all fun correction =>
      (EventCorrection.project? events correction).isSome
  }

private def malformedEventPayload : SidecarBytes :=
  { fixture with events := "LOAM-EVENT-MEMORY\t2\n" }

def main : IO Unit := do
  let canonical ← requireSome (canonicalize? fixture)
    "public sidecar fixture was not admitted by production codecs"
  expect (canonical == fixture)
    "production decode/encode changed the public sidecar fixture"

  let unpacked ← requireSome (unpack? (pack fixture))
    "typed-section framing failed to unwrap its public fixture"
  expect (unpacked == fixture)
    "typed-section framing changed exact production sidecar bytes"

  let before ← requireSome (productionProjection? fixture)
    "production fixture failed semantic projection"
  let after ← requireSome (productionProjection? unpacked)
    "framed fixture failed production semantic projection"
  expect (after == before)
    "typed-section framing changed the production semantic projection"

  expect (before.eventCount == 2)
    "production projection changed Event count"
  expect (before.effectCount == 4)
    "production projection changed Effect count"
  expect (before.firstWallet == -1000 && before.secondWallet == -1200)
    "production projection changed exact wallet quantities"
  expect
    (before.firstDate == some "2026-09-01" &&
      before.secondDate == some "2026-09-02")
    "production projection changed ActualValidity dates"
  expect
    (before.firstDescription == some "public original" &&
      before.secondDescription == some "public replacement")
    "production projection changed Event descriptions"
  expect (before.correctionCount == 1 && before.correctionsProject)
    "production projection changed EventCorrection admission"

  let malformedUnpacked ← requireSome (unpack? (pack malformedEventPayload))
    "outer framing unexpectedly rejected the intentionally malformed inner fixture"
  expect ((productionProjection? malformedUnpacked).isNone)
    "outer framing bypassed production semantic version rejection"

  IO.println "Observation 154 production fixture parity succeeded."
