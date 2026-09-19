import Loam.Core.EventMemory
import Loam.Observations.Observation279

namespace Loam.Observation280

open Loam.Core
open Loam.Observation279

set_option autoImplicit false

/-!
# Observation 280 — idempotent retry as one pure semantic transition

Observation 279 established that one independent semantic OperationId is
sufficient to reject a second admission even when a caller proposes a fresh
EventId.

This observation asks the next bounded question:

> Can retry semantics be expressed so that one successful operation publishes
> both Event and operation evidence together, while a repeated OperationId
> leaves state unchanged and returns the EventId from the first success?

The model is deliberately pure. It observes the semantic transition shape only.
Production persistence remains unchanged; existing ActualAuthority atomic
publication is a separate physical mechanism.
-/

/-- A tiny world containing only the two memories needed by this question. -/
structure World where
  events : EventMemory
  operations : AppliedOperationMemory

/-- Observable result of one semantic operation request. -/
inductive ApplyOutcome where
  | applied (event : EventId)
  | alreadyApplied (event : EventId)
  | rejected
deriving Repr, DecidableEq

/-- Find the EventId previously produced by one semantic operation. -/
def findAppliedEvent? : List AppliedOperation -> OperationId -> Option EventId
  | [], _ => none
  | entry :: rest, operation =>
      if entry.operation = operation then
        some entry.event
      else
        findAppliedEvent? rest operation

/-- Empty semantic world. -/
def emptyWorld : World := {
  events := { events := [], idNodup := by simp }
  operations := AppliedOperationMemory.empty
}

/-- The complete one-operation world used by the qualification theorems below. -/
def singletonWorld (operation : OperationId) (event : Event) : World := {
  events := { events := [event], idNodup := by simp }
  operations := {
    entries := [{ operation := operation, event := event.id }]
    operationNodup := by simp
  }
}

/--
Apply one semantic operation proposal.

A repeated OperationId returns the EventId from the retained operation evidence
without attempting to add the proposed Event. A fresh operation exposes a new
World only after both EventMemory and AppliedOperationMemory additions succeed.
Any failed admission returns the original World.
-/
def applyOperation
    (world : World)
    (operation : OperationId)
    (event : Event) : World × ApplyOutcome :=
  match findAppliedEvent? world.operations.entries operation with
  | some existing =>
      (world, .alreadyApplied existing)
  | none =>
      match EventMemory.add? world.events event with
      | none =>
          (world, .rejected)
      | some events =>
          match AppliedOperationMemory.add? world.operations
              { operation := operation, event := event.id } with
          | none =>
              (world, .rejected)
          | some operations =>
              ({ events := events, operations := operations }, .applied event.id)

/-- First application against the empty world succeeds with both facts present. -/
@[simp] theorem first_application_succeeds
    (operation : OperationId)
    (event : Event) :
    applyOperation emptyWorld operation event =
      (singletonWorld operation event, .applied event.id) := by
  simp [applyOperation, emptyWorld, singletonWorld, findAppliedEvent?,
    AppliedOperationMemory.add?, AppliedOperationMemory.ofEntries?]

/--
Retrying the same semantic operation does not evaluate the proposed Event as a
new operation. The whole World remains exactly unchanged and the original
EventId is returned.
-/
@[simp] theorem repeated_operation_is_idempotent
    (operation : OperationId)
    (first retryProposal : Event) :
    applyOperation (singletonWorld operation first) operation retryProposal =
      (singletonWorld operation first, .alreadyApplied first.id) := by
  simp [applyOperation, singletonWorld, findAppliedEvent?]

/-- A repeated operation therefore cannot increase retained Event count. -/
theorem repeated_operation_does_not_add_event
    (operation : OperationId)
    (first retryProposal : Event) :
    (applyOperation (singletonWorld operation first) operation retryProposal).1.events.events =
      [first] := by
  simp

/-- Retry returns the EventId established by the first successful application. -/
theorem repeated_operation_returns_original_event
    (operation : OperationId)
    (first retryProposal : Event) :
    (applyOperation (singletonWorld operation first) operation retryProposal).2 =
      .alreadyApplied first.id := by
  simp

/--
A first successful application never exposes an Event-only half state: the
result contains both the Event and its OperationId-to-EventId evidence.
-/
theorem first_success_contains_both_facts
    (operation : OperationId)
    (event : Event) :
    (applyOperation emptyWorld operation event).1.events.events = [event] ∧
      (applyOperation emptyWorld operation event).1.operations.entries =
        [{ operation := operation, event := event.id }] := by
  simp

/--
If Event admission fails, operation evidence is not appended either. Here a
fresh semantic operation proposes an EventId already present in EventMemory.
-/
theorem rejected_event_leaves_world_unchanged
    (firstOperation secondOperation : OperationId)
    (event : Event)
    (hDifferent : firstOperation ≠ secondOperation) :
    applyOperation (singletonWorld firstOperation event) secondOperation event =
      (singletonWorld firstOperation event, .rejected) := by
  simp [applyOperation, singletonWorld, findAppliedEvent?, hDifferent,
    EventMemory.add?_singleton_duplicate]

/-!
## Finding

The small semantic shape is now sufficient for idempotent retry:

    first request
      OperationId + Event
          -> complete World with both facts

    repeated request
      same OperationId + any proposed Event
          -> unchanged World
          -> alreadyApplied original EventId

The transition exposes no Event-only or operation-evidence-only successful
state. Existing ActualAuthority may later provide the physical single-generation
publication mechanism if this observation-local relation earns promotion.

This still does not decide:

- how a production OperationId is issued or imported;
- whether the right production name is PaymentId, CommandId, or another identity;
- authorization, settlement, or external payment-rail semantics;
- cryptographic tamper evidence.

No production type, writer, or persistence format is changed here.
-/

end Loam.Observation280
