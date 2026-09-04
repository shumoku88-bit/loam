import Loam.Application.ActualValidityFrontier
import Loam.Observations.Observation152
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence

namespace Loam.Observation153

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 153 — production fixture parity through typed sections

Observation 152 qualified the outer typed-section framing in isolation. This
observation connects that framing to the existing production semantic codecs on
public synthetic fixtures without adding a production unified-Actual format.

The outer frame does not parse EventMemory, ActualValidity, EventDescription, or
EventCorrection payloads. It only carries their already-versioned production
representations. After unwrap, the existing production decoders remain the only
semantic admission boundary.
-/

structure SidecarBytes where
  events : String
  validity : String
  descriptions : String
  corrections : Option String
  deriving Repr, DecidableEq

structure ProductionProjection where
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
  deriving Repr, DecidableEq

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

private def wrappedProjection? : Option ProductionProjection := do
  let sidecars ← unpack? (pack fixture)
  productionProjection? sidecars

private def malformedEventPayload : SidecarBytes :=
  { fixture with events := "LOAM-EVENT-MEMORY\t2\n" }

private def framedMalformedEventPayloadIsRejected : Bool :=
  match unpack? (pack malformedEventPayload) with
  | none => false
  | some sidecars => (productionProjection? sidecars).isNone

/-- The public sidecar fixture is already canonical under every production codec. -/
theorem public_fixture_is_production_canonical :
    canonicalize? fixture = some fixture := by
  native_decide

/-- Typed framing is byte-transparent for complete production sidecar payloads. -/
theorem typed_sections_preserve_exact_sidecar_bytes :
    unpack? (pack fixture) = some fixture := by
  native_decide

/-- The same production semantic projection is observed before and after framing. -/
theorem typed_sections_preserve_production_projection :
    wrappedProjection? = productionProjection? fixture := by
  native_decide

/-- The projection witness includes both EventCorrection endpoint admission and dates/text. -/
theorem public_projection_witness :
    productionProjection? fixture = some {
      eventCount := 2
      effectCount := 4
      firstWallet := -1000
      secondWallet := -1200
      firstDate := some "2026-09-01"
      secondDate := some "2026-09-02"
      firstDescription := some "public original"
      secondDescription := some "public replacement"
      correctionCount := 1
      correctionsProject := true
    } := by
  native_decide

/-- A valid outer frame cannot make an unsupported inner production version admissible. -/
theorem framing_does_not_bypass_production_semantic_validation :
    framedMalformedEventPayloadIsRejected = true := by
  native_decide

end Loam.Observation153
