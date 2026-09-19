import Loam.MovementAdmission

namespace Loam.Observation281

open Loam.Core

set_option autoImplicit false

/-!
# Observation 281 — repeated proposal pressure in current Movement admission

Observations 279 and 280 established an experiment-local semantic OperationId
and showed that it is sufficient for at-most-once admission and idempotent retry.

This observation returns to current production semantics and asks the missing
promotion question:

> If exactly the same Movement draft is admitted twice against the world
> produced by the first admission, does existing MovementAdmission recognize
> the second request as the same operation?

The answer is expected to be no. Current Movement admission intentionally
allocates fresh Event identity from current retained evidence and has no semantic
source/operation identity in Draft.

This is not an argument that equal drafts are always duplicate real-world
operations. Two genuinely distinct payments may have identical dates, effects,
descriptions, and amounts. The observation only establishes that current draft
content cannot itself provide idempotent retry identity.
-/

private def cash : LocusId := ⟨"cash"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def initialWorld : Loam.MovementAdmission.World := {
  events := { events := [], idNodup := by simp }
  validity := {
    facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }
  descriptions := .empty
  relations := []
  discharges := []
  locusAdmission := { approved := [cash], nodup := by simp }
}

/--
One deliberately plain practical Movement draft.

The two anonymous Effects share one Locus only to keep the witness vocabulary
minimal. Their signed quantities still close exactly to zero and the positive
side is 100 quanta.
-/
private def sampleDraft : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-19"
  description := none
  effects := [
    Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-100)),
    Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta 100)
  ]
  relations := []
  discharges := []
  total := 100
}

/--
Executable witness for the current retry pressure.

The same draft is admitted once into the empty world, then admitted again
against the resulting world. Current fresh identity allocation treats the
second admission as another Event.
-/
private def repeatedDraftWitness : Bool :=
  match Loam.MovementAdmission.admit? initialWorld sampleDraft with
  | .error _ => false
  | .ok first =>
      match Loam.MovementAdmission.admit? first.world sampleDraft with
      | .error _ => false
      | .ok second =>
          first.eventId.token == "record-1" &&
          second.eventId.token == "record-2" &&
          decide (first.eventId ≠ second.eventId) &&
          second.world.events.events.length == 2

/--
Current Movement semantics admits the same complete draft twice as two distinct
Events when no independent semantic operation identity is supplied.
-/
theorem same_draft_twice_allocates_two_events :
    repeatedDraftWitness = true := by
  native_decide

/-!
## Finding

The current production-shaped semantic entrance has this behavior:

    same MovementAdmission.Draft
        -> admit into current world
        -> fresh record-1

    same MovementAdmission.Draft again
        -> admit into updated world
        -> fresh record-2

This is correct for ordinary manual recording because equal payload does not
mean equal real-world operation.

But it creates concrete pressure at proposal/retry boundaries whose caller
knows that a repeated request is the same operation. Content-based duplicate
detection would be unsound because two legitimate operations may be identical.

Therefore the candidate earned by Observations 279–280 remains orthogonal:

    semantic OperationId -> EventId

rather than:

    hash/equality of Movement draft -> duplicate identity

This observation does not add OperationId to production, alter Movement Draft,
or change publication behavior. It only establishes that current semantics
cannot derive idempotent retry from draft content alone.
-/

end Loam.Observation281
