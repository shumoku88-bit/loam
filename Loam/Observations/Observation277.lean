import Loam.Core.EventMemory

namespace Loam.Observation277

open Loam.Core

set_option autoImplicit false

/-!
# Observation 277 — Event identity uniqueness is not payment idempotency

Observation 276 established the first conservation law over sequences of
proof-carrying `BalancedMovement` values.

This observation asks a separate, narrower question already suggested by the
existing `EventMemory.idNodup` field:

> Does LOAM already prevent two retained Events from sharing one EventId,
> regardless of whether their payloads are equal or different?

The second half of the observation is equally important:

> Does unique EventId storage by itself prevent the same semantic transaction
> from being recorded twice under different EventIds?

The first answer should be yes. The second should be no. Keeping those facts
separate avoids overstating structural identity uniqueness as payment
idempotency.
-/

/--
Two Events carrying the same EventId cannot be admitted together into one
EventMemory, even when the Event payloads themselves differ.

The proof consumes EventMemory's retained `idNodup` invariant rather than
reconstructing the hash-backed duplicate implementation.
-/
theorem same_event_id_pair_rejected
    (left right : Event)
    (hId : left.id = right.id) :
    EventMemory.ofEvents? [left, right] = none := by
  cases hMemory : EventMemory.ofEvents? [left, right] with
  | none =>
      rfl
  | some memory =>
      have hEvents :=
        EventMemory.ofEvents?_some_events [left, right] memory hMemory
      have hNodup := memory.idNodup
      rw [hEvents] at hNodup
      simp [hId] at hNodup

private def yen : MeasureId := ⟨"jpy"⟩
private def cash : LocusId := ⟨"cash"⟩

/--
Two Events with different EventIds but the same represented quantity payload.

These stand in for the boundary we have *not* yet solved: the same external
payment or command may be assigned two different EventIds unless some separate
semantic identity is retained.
-/
private def firstOccurrence : Event := {
  id := ⟨"o277-a"⟩
  effects := [Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-100))]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def repeatedOccurrence : Event := {
  id := ⟨"o277-b"⟩
  effects := [Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-100))]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def distinctIdentitySamePayloadWitness : Bool :=
  (EventMemory.ofEvents? [firstOccurrence, repeatedOccurrence]).isSome

/--
Distinct EventIds remain admissible even when the represented payloads are
identical.

Therefore `EventMemory.idNodup` is a structural identity law, not semantic
payment idempotency.
-/
theorem distinct_ids_can_retain_same_payload :
    distinctIdentitySamePayloadWitness = true := by
  native_decide

/-!
## Finding

The existing Core already owns a useful verified boundary:

```text
same EventId
    -> cannot coexist in EventMemory
```

But it deliberately does not imply:

```text
same payment / same command / same external transaction
    -> at most one retained effect
```

That stronger statement would require an independently meaningful semantic key,
such as a future PaymentId, CommandId, or external transaction identity. This
observation does not introduce one.

No production writer, persistence format, Event ontology, or payment behavior is
changed here.
-/

end Loam.Observation277
