import Loam.ActualDate
import Loam.Application.ExchangeEvidenceFrontier
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.ExchangeEvidence
import Loam.Core.LocusAdmission
import Loam.FreshNumberedToken
import Loam.Persistence.TokenSyntax

namespace Loam.ExchangeAdmission

open Loam.Core

set_option autoImplicit false

/-!
# Practical exchange admission

This is the presentation-neutral semantic entrance for creating one new
cross-Measure exchange occurrence.

It deliberately does not introduce a transaction-kind hierarchy. The retained
facts remain:

- one neutral Event with exact Effects;
- one occurrence date;
- optional human description;
- one effect-selected ExchangeEvidence row.

The exchange Evidence only selects source and destination sides. It carries no
rate, valuation, fee, tax, basis, home-currency, or travel-direction semantics.
-/

/-- One already-collected exchange before durable Event identity allocation. -/
structure Draft where
  validOn : String
  description : Option String
  effects : List Effect
  source : EffectKey
  destination : EffectKey
deriving Repr, DecidableEq

/--
The independently meaningful evidence/policy families needed to admit a new
exchange. Current Locus admission remains new-write policy, not Event history.
-/
structure World where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory
  exchanges : ExchangeEvidenceMemory
  corrections : EventCorrectionMemory
  locusAdmission : LocusAdmissionVocabulary :=
    LocusAdmissionVocabulary.empty

/-- One admitted exchange plus the updated semantic world. -/
structure Admitted where
  world : World
  eventId : EventId

private def freshExchangeEventId (world : World) : EventId :=
  let used := world.events.events.map (fun event => event.id.token)
  ⟨Loam.firstUnusedNumberedToken "exchange-" used 1⟩

private def retainedEffectKeyPersistable (effect : Effect) : Bool :=
  match effect.key with
  | none => true
  | some key => Loam.Persistence.validToken key.token

private def descriptionAdmissible : Option String → Bool
  | none => true
  | some text =>
      !text.isEmpty && !text.contains '\n' && !text.contains '\r'

/--
Validate only the raw draft facts that do not depend on the current household
world. Exchange shape itself is checked later through the already-qualified
ExchangeEvidence application boundary.
-/
def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: exchange date must be a real calendar date in YYYY-MM-DD form"
  if !descriptionAdmissible draft.description then
    throw "loam: exchange description must be nonempty single-line text when present"
  if !Loam.Persistence.validToken draft.source.token ||
      !Loam.Persistence.validToken draft.destination.token then
    throw "loam: exchange source and destination Effect keys must be valid tokens"
  if !draft.effects.all (fun effect =>
      retainedEffectKeyPersistable effect &&
      Loam.Persistence.validToken effect.locus.token &&
      Loam.Persistence.validToken effect.measure.token &&
      effect.quantity.quanta != 0) then
    throw "loam: exchange requires valid Effect/Locus/Measure tokens and nonzero quantities"

/--
Admit one new exchange against one current world.

The new Event receives a fresh practical identity, then the exact same
production ExchangeEvidence rule used by normalized Actual re-admission is
applied before the result can leave this boundary.
-/
def admit? (world : World) (draft : Draft) : Except String Admitted := do
  validateDraft draft
  if !world.locusAdmission.admitsEffects draft.effects then
    throw "loam: exchange uses a Locus not approved for new publication"

  let eventId := freshExchangeEventId world
  let event ← match Event.ofEffects? eventId draft.effects with
    | some event => pure event
    | none => throw "loam: exchange has duplicate or invalid retained Effect identity"

  let updatedEvents ← match EventMemory.add? world.events event with
    | some events => pure events
    | none => throw "loam: could not allocate a fresh exchange Event"

  let validityFact : ActualValidityFact String := .base eventId draft.validOn
  let updatedValidity ← match world.validity.addFact? validityFact with
    | some validity => pure validity
    | none => throw "loam: could not retain exchange occurrence-date evidence"

  let updatedDescriptions ← match draft.description with
    | none => pure world.descriptions
    | some text =>
        match world.descriptions.add? { event := eventId, text := text } with
        | some descriptions => pure descriptions
        | none => throw "loam: could not retain exchange description evidence"

  let exchange : ExchangeEvidence := {
    event := eventId
    source := draft.source
    destination := draft.destination
  }

  if !Loam.Application.exchangeEvidenceAdmitted?
      updatedEvents world.corrections exchange then
    throw "loam: exchange Effects do not justify the selected cross-Measure source and destination"

  let updatedExchanges ← match world.exchanges.add? exchange with
    | some exchanges => pure exchanges
    | none => throw "loam: could not retain exchange evidence"

  pure {
    world := {
      events := updatedEvents
      validity := updatedValidity
      descriptions := updatedDescriptions
      exchanges := updatedExchanges
      corrections := world.corrections
      locusAdmission := world.locusAdmission
    }
    eventId := eventId
  }

end Loam.ExchangeAdmission
