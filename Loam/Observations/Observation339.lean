import Loam.CapacityEvidence
import Loam.Persistence.NormalizedCapacityPersistence

namespace Loam.Observation339

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Observation 339 — Capacity re-admission fixed point and wire-order boundary

MATH-11 asks which LOAM normalized boundaries actually carry canonical-image
laws.

Capacity differs from Actual in an important way.

At the typed aggregate boundary, CapacityEvidence already carries the exact
cross-family completeness proof used by CapacityEvidence.ofParts?. Therefore
re-admitting the same two retained parts should be a genuine fixed point for
every admitted value.

At the wire boundary, however, the normalized Capacity codec deliberately
preserves Movement order and Change order. So normalized does not mean that
all semantically similar permutations collapse to one byte representation.

This observation records both sides of that boundary.
-/

/--
Every already-admitted Capacity aggregate is a fixed point of the same
cross-family admission operation.

This law follows from the proof carried by CapacityEvidence.complete; no
runtime re-check or additional semantic assumption is needed.
-/
theorem readmission_fixed_point
    {Time : Type}
    (evidence : CapacityEvidence Time) :
    CapacityEvidence.ofParts? evidence.movements evidence.effective =
      some evidence := by
  cases evidence with
  | mk movements effective complete =>
      simp [CapacityEvidence.ofParts?, complete]

private def wireAB : String :=
  "LOAM-NORMALIZED-CAPACITY\t1\n" ++
  "MOVEMENT\tcapacity-a\t2026-09-01\tjpy\n" ++
  "CHANGE\tUNALLOCATED\t-100\n" ++
  "CHANGE\tPURPOSE\tfood\t100\n" ++
  "ENDMOVEMENT\n" ++
  "MOVEMENT\tcapacity-b\t2026-09-02\tjpy\n" ++
  "CHANGE\tPURPOSE\tfood\t-40\n" ++
  "CHANGE\tPURPOSE\tstock\t40\n" ++
  "ENDMOVEMENT\n"

private def wireBA : String :=
  "LOAM-NORMALIZED-CAPACITY\t1\n" ++
  "MOVEMENT\tcapacity-b\t2026-09-02\tjpy\n" ++
  "CHANGE\tPURPOSE\tfood\t-40\n" ++
  "CHANGE\tPURPOSE\tstock\t40\n" ++
  "ENDMOVEMENT\n" ++
  "MOVEMENT\tcapacity-a\t2026-09-01\tjpy\n" ++
  "CHANGE\tUNALLOCATED\t-100\n" ++
  "CHANGE\tPURPOSE\tfood\t100\n" ++
  "ENDMOVEMENT\n"

def normalizeWire? (wire : String) : Option String := do
  let image ← decodeNormalizedCapacity? wire
  encodeNormalizedCapacity? image

theorem reordered_wires_are_distinct :
    wireAB ≠ wireBA := by
  native_decide

theorem wireAB_is_admitted :
    (decodeNormalizedCapacity? wireAB).isSome = true := by
  native_decide

theorem wireBA_is_admitted :
    (decodeNormalizedCapacity? wireBA).isSome = true := by
  native_decide

/--
Each accepted normalized Capacity wire is a fixed point of decode-then-encode
for this witness.
-/
theorem wireAB_is_fixed_point :
    normalizeWire? wireAB = some wireAB := by
  native_decide

theorem wireBA_is_fixed_point :
    normalizeWire? wireBA = some wireBA := by
  native_decide

/--
Unlike the Actual row-family witness, Capacity Movement order is not erased by
normalization. Two admitted orderings remain two distinct fixed points.
-/
theorem movement_order_is_not_globally_canonicalized :
    normalizeWire? wireAB ≠ normalizeWire? wireBA := by
  native_decide

/-!
## Finding

Capacity exposes a stronger typed fixed point and a weaker wire canonicalization
claim than Actual:

typed CapacityEvidence:
  admitted parts -> re-admit same parts -> same value

normalized Capacity wire:
  accepted wire -> decode -> encode -> same ordered wire
  but different Movement order -> different fixed point

So MATH-11 should distinguish at least two kinds of normalization:

1. semantic admission fixed point, where proof-carrying data is stable under
   the same admission function;
2. wire canonicalization, where distinct admitted representations converge
   to one encoded image.

Capacity clearly has the first. This witness shows that it does not globally
provide the second across Movement permutations.

That boundary argues against a repository-wide generic normalization abstraction.
-/

end Loam.Observation339
