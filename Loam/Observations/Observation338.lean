import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Observation338

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Observation 338 — normalized Actual wire canonical-image convergence

MATH-11 asks whether LOAM's "normalized" persistence formats actually expose
useful canonical-image laws rather than merely using the word normalized.

Normalized Actual decoding accepts some harmless representation-order freedom
inside one transaction. In particular, singleton metadata rows and distinct
row families may be interleaved around Effects without changing the retained
typed evidence. The encoder, however, emits those families in one fixed order.

This observation studies the concrete operator

    normalize(wire) = encode(decode(wire))

using the production decoder, semantic admission, and encoder themselves.

The goal is deliberately narrow:

- show two distinct admitted wire representations converge to one encoded image;
- show the encoded image is a fixed point of the same operation;
- do not infer that arbitrary Event/Effect order is semantically irrelevant;
- do not replace runtime parsing, filesystem, recovery, or version tests.
-/

private def canonicalWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++
  "TX\to338-event\t2026-09-01\tNODESC\n" ++
  "MERCHANT\to338-shop\n" ++
  "OPERATION\to338-operation\n" ++
  "EFFECT\twallet\tjpy\t-100\n" ++
  "EFFECT\tbank\tjpy\t100\n" ++
  "DATE-REV\to338-rev\t2026-09-02\tREPLACES\tROOT\n" ++
  "ENDTX\n"

/--
Same typed facts as `canonicalWire`, but row families are deliberately
interleaved in a different order. Effect order itself remains unchanged.
-/
private def alternateWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++
  "TX\to338-event\t2026-09-01\tNODESC\n" ++
  "DATE-REV\to338-rev\t2026-09-02\tREPLACES\tROOT\n" ++
  "EFFECT\twallet\tjpy\t-100\n" ++
  "OPERATION\to338-operation\n" ++
  "MERCHANT\to338-shop\n" ++
  "EFFECT\tbank\tjpy\t100\n" ++
  "ENDTX\n"

/--
Production-shaped normalization: decode through full semantic admission, then
encode the admitted retained evidence again.
-/
def normalizeWire? (wire : String) : Option String := do
  let image ← decodeNormalizedActualImage? wire
  encodeNormalizedActual? image.evidence

/-- The witness really starts from two distinct byte representations. -/
theorem alternate_wire_is_distinct :
    alternateWire ≠ canonicalWire := by
  native_decide

/-- Both representations pass the complete production normalized-Actual admission. -/
theorem canonical_wire_is_admitted :
    (decodeNormalizedActualImage? canonicalWire).isSome = true := by
  native_decide

theorem alternate_wire_is_admitted :
    (decodeNormalizedActualImage? alternateWire).isSome = true := by
  native_decide

/--
The alternate representation converges to the encoder's one chosen row-family
order. This is a concrete canonical-image witness, not a claim that all retained
list order may be forgotten.
-/
theorem alternate_converges_to_canonical :
    normalizeWire? alternateWire = some canonicalWire := by
  native_decide

/-- The encoder-produced wire is already a fixed point. -/
theorem canonical_is_fixed_point :
    normalizeWire? canonicalWire = some canonicalWire := by
  native_decide

/--
Applying production normalization twice to this admitted noncanonical wire does
nothing after the first pass.
-/
theorem witness_normalization_is_idempotent :
    (normalizeWire? alternateWire >>= normalizeWire?) =
      normalizeWire? alternateWire := by
  native_decide

/-!
## Finding

For this admitted representation-order witness:

    distinct admitted wires
        -> same typed Actual evidence shape
        -> one encoder-selected wire image
        -> fixed point on the next normalize pass

So Normalized Actual already behaves as a canonicalization boundary for at
least some wire-order freedom.

The boundary matters. The observation deliberately does **not** reorder:

- Events;
- Effects relative to other Effects;
- date revisions relative to other revisions;
- Relations relative to other Relations;
- Discharges relative to other Discharges.

Those orders may remain observable or may require separate permutation laws.
MATH-11 should therefore proceed family by family rather than adding a global
"sort everything" normalization abstraction.
-/

end Loam.Observation338
