import Loam.ActualEvidence
import Loam.Core.ActualValidity
import Loam.Core.EventMemory
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Observation284

open Loam.Core

set_option autoImplicit false

/-!
# Observation 284 — one transfer, two side-local dates

Falsification target F025 asks whether one transfer can retain one movement
identity while the two externally observed sides carry different dates.

Selected specimen:

    2026-09-20  bank    -10000 jpy
    2026-09-22  wallet  +10000 jpy

The quantity movement is one exact balanced transfer. The pressure is temporal:
the source institution observed its side before the destination institution
observed the other side.

Current LOAM Actual validity is Event-keyed:

    EventId -> validOn

so one Event has one admitted current occurrence date.

This observation asks whether that granularity is sufficient, and whether the
obvious workaround of splitting the transfer into two dated Events preserves the
already-qualified production laws.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def wallet : LocusId := ⟨"wallet"⟩

private def transferId : EventId := ⟨"transfer-1"⟩
private def bankSide : EffectKey := ⟨"bank-side"⟩
private def walletSide : EffectKey := ⟨"wallet-side"⟩

/--
One physical transfer Event.

Stable Effect keys are retained only so this observation can ask whether
side-local temporal evidence needs an anchor below Event identity. The keys
carry no source/destination or settlement meaning by themselves.
-/
private def transferEvent : Event := {
  id := transferId
  effects := [
    Effect.ofQuantity bankSide bank yen (Quantity.ofQuanta (-10000)),
    Effect.ofQuantity walletSide wallet yen (Quantity.ofQuanta 10000)
  ]
  keyNodup := by
    simp [retainedEffectKeys, bankSide, walletSide]
}

private def transferMemory : EventMemory := {
  events := [transferEvent]
  idNodup := by simp
}

/-- The selected transfer is physically balanced in one Measure. -/
theorem one_event_retains_balanced_transfer :
    transferEvent.quantityAt bank yen = Quantity.ofQuanta (-10000) ∧
    transferEvent.quantityAt wallet yen = Quantity.ofQuanta 10000 := by
  native_decide

/-!
## Current Event-level date boundary

ActualValidityMemory deliberately admits at most one validity coordinate for one
EventId. Therefore the two side dates cannot both be represented merely by
adding two ordinary ActualValidity entries for the same transfer Event.
-/

private def twoEventLevelDatesAttempt :
    Option (ActualValidityMemory String) :=
  ActualValidityMemory.ofEntries? [
    { event := transferId, validOn := "2026-09-20" },
    { event := transferId, validOn := "2026-09-22" }
  ]

theorem one_event_cannot_hold_two_actual_validity_dates :
    twoEventLevelDatesAttempt.isNone = true := by
  native_decide

private def oneEventLevelDate : ActualValidityMemory String := {
  entries := [{ event := transferId, validOn := "2026-09-20" }]
  eventNodup := by simp
}

theorem current_validity_projects_exactly_one_date_for_transfer :
    oneEventLevelDate.findByEventId? transferId = some "2026-09-20" := by
  native_decide

/-!
## Tempting split workaround

A representation can attach one date to each side if it first invents two
Events:

    source Event       bank   -10000 jpy   @ 2026-09-20
    destination Event  wallet +10000 jpy   @ 2026-09-22

At raw Core quantity level this preserves the selected aggregate balances.
But each Event is individually unbalanced, and the one physical transfer
identity has disappeared.
-/

private def sourceEventId : EventId := ⟨"transfer-source-side"⟩
private def destinationEventId : EventId := ⟨"transfer-destination-side"⟩

private def sourceEvent : Event := {
  id := sourceEventId
  effects := [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-10000))
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def destinationEvent : Event := {
  id := destinationEventId
  effects := [
    Effect.ofAnonymousQuantity wallet yen (Quantity.ofQuanta 10000)
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def splitMemory : EventMemory := {
  events := [sourceEvent, destinationEvent]
  idNodup := by
    simp [sourceEvent, destinationEvent, sourceEventId, destinationEventId]
}

/--
The split representation can mimic the same aggregate physical quantity
projection.
-/
theorem split_preserves_selected_aggregate_quantities :
    EventMemory.quantityAtRecorded transferMemory bank yen =
      EventMemory.quantityAtRecorded splitMemory bank yen ∧
    EventMemory.quantityAtRecorded transferMemory wallet yen =
      EventMemory.quantityAtRecorded splitMemory wallet yen := by
  native_decide

/-- But the original transfer occurrence identity is no longer present. -/
theorem split_loses_shared_transfer_identity :
    (transferMemory.findById? transferId).isSome = true ∧
    (splitMemory.findById? transferId).isNone = true ∧
    transferMemory.events.length = 1 ∧
    splitMemory.events.length = 2 := by
  native_decide

private def splitEvidence : Loam.ActualEvidence := {
  Loam.ActualEvidence.empty with
  events := splitMemory
  validity := {
    facts := [
      .base sourceEventId "2026-09-20",
      .base destinationEventId "2026-09-22"
    ]
    factRefNodup := by
      simp [ActualValidityFact.ref, sourceEventId, destinationEventId]
    corrections := []
    correctionIdNodup := by simp
  }
}

/--
The split is not merely a provenance compromise. Current normalized production
persistence rejects it because ordinary Events must close independently within
each represented Measure.
-/
theorem production_persistence_refuses_two_unbalanced_side_events :
    (Loam.Persistence.admitActualEvidence? splitEvidence).isNone = true := by
  native_decide

/-!
## Observation-local side-date evidence

The remaining small candidate is additive temporal evidence that names one
retained Effect inside one Event.

This is deliberately not a production schema proposal. It is only a witness
that the missing information can be added without:

- changing Event identity;
- weakening per-Measure balance;
- introducing Transfer as a Core transaction kind;
- assigning temporal order to the Effect list.
-/

/-- One observation-local date claim for one retained Effect. -/
structure EffectValidity where
  event : EventId
  effect : EffectKey
  validOn : String
deriving Repr, DecidableEq

/-- The claim is meaningful only when the named Event and Effect both exist. -/
def effectValidityAdmitted?
    (events : EventMemory)
    (evidence : EffectValidity) : Bool :=
  match events.findById? evidence.event with
  | none => false
  | some event =>
      event.effects.any fun effect =>
        decide (effect.key = some evidence.effect)

/-- Lookup one selected side-local date from explicit admitted evidence. -/
def effectValidOn?
    (events : EventMemory)
    (evidence : List EffectValidity)
    (event : EventId)
    (effect : EffectKey) : Option String :=
  match evidence with
  | [] => none
  | item :: rest =>
      if decide (item.event = event ∧ item.effect = effect) &&
          effectValidityAdmitted? events item then
        some item.validOn
      else
        effectValidOn? events rest event effect

private def bankDate : EffectValidity := {
  event := transferId
  effect := bankSide
  validOn := "2026-09-20"
}

private def leftWalletDate : EffectValidity := {
  event := transferId
  effect := walletSide
  validOn := "2026-09-21"
}

private def rightWalletDate : EffectValidity := {
  event := transferId
  effect := walletSide
  validOn := "2026-09-22"
}

private def leftSideDates : List EffectValidity := [
  bankDate,
  leftWalletDate
]

private def rightSideDates : List EffectValidity := [
  bankDate,
  rightWalletDate
]

/-- Both selected side claims refer to real retained Effects. -/
theorem side_local_date_evidence_is_structurally_admissible :
    effectValidityAdmitted? transferMemory bankDate = true ∧
    effectValidityAdmitted? transferMemory leftWalletDate = true ∧
    effectValidityAdmitted? transferMemory rightWalletDate = true := by
  native_decide

/--
Two worlds can share the complete physical Event and the same ordinary
Event-level ActualValidity while differing in the destination-side observation
date.

Therefore the current Event-level validity answer does not determine the
side-local temporal answer.
-/
theorem same_event_and_event_date_can_have_different_side_date :
    oneEventLevelDate.findByEventId? transferId = some "2026-09-20" ∧
    effectValidOn? transferMemory leftSideDates transferId bankSide =
      some "2026-09-20" ∧
    effectValidOn? transferMemory rightSideDates transferId bankSide =
      some "2026-09-20" ∧
    effectValidOn? transferMemory leftSideDates transferId walletSide =
      some "2026-09-21" ∧
    effectValidOn? transferMemory rightSideDates transferId walletSide =
      some "2026-09-22" := by
  native_decide

/-!
## Finding

F025 produces a genuine granularity counterexample.

Current Event-level validity is intentionally too small for the selected
question:

    one balanced Event
    + one Event-level validOn
    !=
    one transfer whose observed sides have different dates

The obvious Event split is also not semantically free:

- it preserves selected aggregate quantities;
- it destroys the one observed transfer Event identity;
- current normalized Actual persistence refuses the two unbalanced side Events.

The bounded witness therefore favors an additive temporal evidence family below
Event identity when side-local dates become practically required. Stable
EffectKey is sufficient as the selected anchor in this experiment.

This does not yet earn:

- production EffectValidity persistence;
- a universal claim that every Effect needs a date;
- a Transfer Core primitive;
- automatic pairing of independently imported bank rows;
- pending/cleared/reconciled status;
- settlement finality;
- occurrence-vs-posting-vs-import-time terminology;
- correction/revision semantics for side-local dates.

Those remain separate pressure tests.
-/

end Loam.Observation284
