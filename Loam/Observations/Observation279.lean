import Loam.Core.Event

namespace Loam.Observation279

open Loam.Core

set_option autoImplicit false

/-!
# Observation 279 — semantic operation identity as the minimal at-most-once key

Observation 277 showed that unique EventId storage is not enough to prevent the
same semantic payment or command from being represented twice under different
EventIds.

Observation 278 then showed that conservation across correction and exact
reversal needs no new retained accounting evidence.

This observation asks the next minimal question:

> Is one independent semantic operation identity, related to an EventId,
> sufficient to express at-most-once admission without adding any field to
> Event itself?

This is intentionally an observation-local model. It does not promote
OperationId to production, choose whether a future real system should call it
PaymentId, CommandId, ExternalTransactionId, or something else, and does not
specify retry response semantics.
-/

/--
Opaque identity for one semantic operation.

Unlike EventId, this stands for "the same requested real-world operation"
rather than "the same retained LOAM Event".
-/
structure OperationId where
  token : String
deriving Repr, DecidableEq

/-- One retained statement that a semantic operation produced one Event. -/
structure AppliedOperation where
  operation : OperationId
  event : EventId
deriving Repr, DecidableEq

/--
Minimal memory needed for at-most-once semantic-operation admission.

Only OperationId is required to be unique. The observation deliberately does
not impose a second uniqueness law on EventId, because that is not needed to
answer the narrower duplicate-operation question.
-/
structure AppliedOperationMemory where
  entries : List AppliedOperation
  operationNodup : (entries.map AppliedOperation.operation).Nodup
deriving Repr

namespace AppliedOperationMemory

/-- Admit a raw relation set only when each semantic operation occurs once. -/
def ofEntries?
    (entries : List AppliedOperation) : Option AppliedOperationMemory :=
  if h : (entries.map AppliedOperation.operation).Nodup then
    some { entries := entries, operationNodup := h }
  else
    none

/-- Empty operation evidence is valid. -/
def empty : AppliedOperationMemory :=
  { entries := [], operationNodup := by simp }

/-- Append one operation-to-Event relation only if operation identity stays unique. -/
def add?
    (memory : AppliedOperationMemory)
    (entry : AppliedOperation) : Option AppliedOperationMemory :=
  ofEntries? (memory.entries ++ [entry])

/--
Two records carrying the same semantic operation identity cannot coexist,
regardless of which EventIds they name.
-/
theorem same_operation_pair_rejected
    (first second : AppliedOperation)
    (hSame : first.operation = second.operation) :
    ofEntries? [first, second] = none := by
  simp [ofEntries?, hSame]

/--
After one semantic operation has been retained, attempting to append that same
operation again is rejected even if the caller proposes a different EventId.
-/
theorem repeated_operation_add_rejected
    (first second : AppliedOperation)
    (hSame : first.operation = second.operation) :
    add?
      { entries := [first], operationNodup := by simp }
      second = none := by
  simp [add?, ofEntries?, hSame]

/--
Distinct semantic operations remain independently admissible.

This records the intended boundary: the key separates logical operations, not
their amounts, dates, merchants, or Event payloads.
-/
theorem distinct_operations_pair_admitted
    (first second : AppliedOperation)
    (hDifferent : first.operation ≠ second.operation) :
    (ofEntries? [first, second]).isSome = true := by
  simp [ofEntries?, hDifferent]

end AppliedOperationMemory

/-!
## Finding

The minimal additional fact needed for at-most-once semantic-operation
admission can be orthogonal to Event:

    OperationId ----produced----> EventId
        |
        +-- unique in AppliedOperationMemory

That is enough to prove that the same OperationId makes a second admission
fail, even when the second attempt proposes a fresh EventId.

This is stronger than EventId uniqueness, but still deliberately weaker than a
complete payment-idempotency claim. A production retry protocol would still
need to decide what a repeated request returns, how the operation identity is
issued or imported, and how operation evidence is committed atomically with the
Event it names.

No production type, writer, persistence format, or Core Event field is changed
by this observation.
-/

end Loam.Observation279
