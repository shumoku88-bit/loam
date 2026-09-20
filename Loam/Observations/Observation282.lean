import Loam.ActualEvidence
import Loam.MovementAdmission
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Observation282

open Loam.Core

set_option autoImplicit false

/-!
# Observation 282 — cross-Measure exchange boundary

Observation 032 established that Measure identity is observable independently of
Locus and Quantity. Observation 033 established that a Measure-to-Measure
valuation relation is not determined by Event history. Production Movement now
accepts arbitrary one-Measure balanced writes, while deliberately refusing a
mixed-Measure draft.

This observation asks the next practical question:

> Can an observed exchange such as 15,000 JPY -> 100 USD be retained without
> inventing a clearing Locus and without promoting an exchange rate into the
> neutral Event Core?

The candidate tested here is deliberately small:

    neutral Event with exact cross-Measure Effects
    + explicit ExchangeEvidence naming that Event

The evidence means only that the named Event is admitted as one observed
cross-Measure exchange. It does not mean market price, valuation authority,
acquisition basis, tax basis, or a timeless FX rate.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩
private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def airportExchangeId : EventId := ⟨"airport-exchange"⟩

/--
The direct physical observation we want to preserve.

No balancing or valuation meaning is hidden in extra Loci: the household cash
position lost 15,000 JPY and gained 100 USD.
-/
private def airportExchangeEvent : Event := {
  id := airportExchangeId
  effects := [
    Effect.ofAnonymousQuantity cashJpy yen (Quantity.ofQuanta (-15000)),
    Effect.ofAnonymousQuantity cashUsd dollar (Quantity.ofQuanta 100)
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

/-- The neutral Core can retain the two unlike exact quantities directly. -/
theorem core_retains_cross_measure_exchange_facts :
    airportExchangeEvent.quantityAt cashJpy yen = Quantity.ofQuanta (-15000) ∧
    airportExchangeEvent.quantityAt cashUsd dollar = Quantity.ofQuanta 100 := by
  native_decide

/--
The ordinary practical Movement entrance must continue to refuse this shape.
Unlike Measures do not cancel each other.
-/
private def ordinaryDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-20"
  description := some "airport exchange"
  effects := airportExchangeEvent.effects
  relations := []
  discharges := []
  total := 100
}

private def ordinaryEntranceRefuses : Bool :=
  match Loam.MovementAdmission.validateDraft ordinaryDraft with
  | .error _ => true
  | .ok _ => false

theorem ordinary_movement_refuses_cross_measure_exchange :
    ordinaryEntranceRefuses = true := by
  native_decide

/--
Current normalized Actual persistence also has no retained evidence authorizing
this event as an exception to ordinary per-Measure closure.
-/
private def airportEvidence : Loam.ActualEvidence := {
  Loam.ActualEvidence.empty with
  events := {
    events := [airportExchangeEvent]
    idNodup := by simp [airportExchangeEvent, airportExchangeId]
  }
  validity := {
    facts := [.base airportExchangeId "2026-09-20"]
    factRefNodup := by simp [ActualValidityFact.ref, airportExchangeId]
    corrections := []
    correctionIdNodup := by simp
  }
}

private def normalizedPersistenceRefuses : Bool :=
  (Loam.Persistence.admitActualEvidence? airportEvidence).isNone

theorem current_persistence_refuses_unqualified_exchange :
    normalizedPersistenceRefuses = true := by
  native_decide

/--
Candidate additive evidence.

Only Event identity is retained here because the exact outgoing / incoming
quantities and Measure identities already live in the Event itself.
-/
structure ExchangeEvidence where
  event : EventId
deriving Repr, DecidableEq

/--
Minimal no-fee exchange shape for this bounded observation.

This is intentionally narrower than a future production admission rule. It
exists only to test whether explicit Exchange evidence can qualify the selected
airport specimen without any Rate or valuation input.
-/
def simpleExchangeShape? (event : Event) : Bool :=
  match event.effects with
  | [left, right] =>
      decide (left.measure ≠ right.measure) &&
        ((decide (left.quantity.quanta < 0) &&
            decide (0 < right.quantity.quanta)) ||
         (decide (right.quantity.quanta < 0) &&
            decide (0 < left.quantity.quanta)))
  | _ => false

/--
An Exchange claim is meaningful only when it names a retained Event and that
Event has the selected cross-Measure exchange shape.
-/
def exchangeEvidenceAdmitted?
    (events : EventMemory)
    (evidence : ExchangeEvidence) : Bool :=
  match events.findById? evidence.event with
  | none => false
  | some event => simpleExchangeShape? event

private def airportEventMemory : EventMemory := {
  events := [airportExchangeEvent]
  idNodup := by simp [airportExchangeEvent, airportExchangeId]
}

private def airportExchangeEvidence : ExchangeEvidence := {
  event := airportExchangeId
}

theorem explicit_exchange_evidence_qualifies_airport_specimen :
    exchangeEvidenceAdmitted? airportEventMemory airportExchangeEvidence = true := by
  native_decide

/--
Physical shape and exchange interpretation remain separate.

The same retained Event facts exist whether or not an Exchange claim is
supplied. Therefore cross-Measure effects alone do not force an economic
exchange interpretation.
-/
def exchangeKnown
    (events : EventMemory)
    (evidence : List ExchangeEvidence)
    (event : EventId) : Bool :=
  evidence.any fun item =>
    decide (item.event = event) && exchangeEvidenceAdmitted? events item

theorem same_event_different_exchange_evidence_changes_exchange_answer :
    exchangeKnown airportEventMemory [] airportExchangeId = false ∧
    exchangeKnown airportEventMemory [airportExchangeEvidence] airportExchangeId = true := by
  native_decide

/--
A valuation overlay is deliberately orthogonal to the selected exchange answer.

The integer is only an observation-local stand-in for some comparison value. No
production Rate representation is proposed.
-/
structure ObservationWorld where
  events : EventMemory
  exchanges : List ExchangeEvidence
  valuation : Option Int

def exchangeAnswer
    (world : ObservationWorld)
    (event : EventId) : Bool :=
  exchangeKnown world.events world.exchanges event

private def worldWithoutValuation : ObservationWorld := {
  events := airportEventMemory
  exchanges := [airportExchangeEvidence]
  valuation := none
}

private def worldWithValuation : ObservationWorld := {
  events := airportEventMemory
  exchanges := [airportExchangeEvidence]
  valuation := some 150
}

theorem exchange_identity_does_not_require_valuation :
    exchangeAnswer worldWithoutValuation airportExchangeId =
      exchangeAnswer worldWithValuation airportExchangeId ∧
    exchangeAnswer worldWithoutValuation airportExchangeId = true := by
  native_decide

/-!
## Finding

The bounded executable result supports this separation:

    Event
      cash-jpy  -15000 jpy
      cash-usd     +100 usd
        +
    explicit ExchangeEvidence(EventId)
        -> observed cross-Measure exchange

while:

    ordinary Movement
        -> still refuses the mixed-Measure shape

and:

    ExchangeEvidence
        != valuation / Rate evidence

The same physical Event can exist with or without the explicit Exchange claim,
so the economic interpretation is not derivable merely from the sign pattern.
Conversely, once explicit Exchange evidence is supplied, the selected exchange
identity does not require any valuation input.

This favors a future production shape in which Exchange is an additive evidence
family referencing Event identity, and normalized Actual admission gains an
explicit exchange-qualified path rather than manufacturing balancing Loci.

It does **not** yet earn:

- a production ExchangeEvidence type;
- a wire-format row;
- a generalized fee-bearing exchange rule;
- correction / reversal rules for Exchange evidence;
- Beancount price or cost emission;
- market-rate persistence;
- acquisition basis or tax semantics.

Those should be promoted only if the practical publication path remains small
after the selected exchange specimen is pressure-tested.
-/

end Loam.Observation282
