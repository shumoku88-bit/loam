import Loam.Core.BalancedMovement
import Loam.Core.Effect

namespace Loam.PracticalMovement

open Loam.Core

set_option autoImplicit false

/-!
# Practical Movement qualification

This module owns one small application-level mechanic shared by write operations
that need to recognize an already-collected Effect list as one practical
single-Measure Movement.

The expected `MeasureId` is an explicit argument. Current household writers may
pass `jpy`, but this helper does not make JPY a Core law and does not perform FX,
valuation, persistence, authority, or frontend work.
-/

/--
Recognize one nonempty Effect list as a balanced Movement in exactly the requested
Measure. Every represented quantity must be nonzero; Effect identity and token
syntax remain the caller's concern.
-/
def ofEffects?
    (measure : MeasureId)
    (effects : List Effect) : Option (BalancedMovement LocusId) :=
  if effects.isEmpty then
    none
  else if !effects.all (fun effect =>
      decide (effect.measure = measure) && effect.quantity.quanta != 0) then
    none
  else
    BalancedMovement.ofChanges? measure <|
      effects.map fun effect =>
        ({ coordinate := effect.locus, quantity := effect.quantity } :
          MovementChange LocusId)

/--
Recognize a practical balanced Movement when the caller does not already know
its Measure.

The first Effect supplies only the candidate Measure identity. `ofEffects?`
then proves that every retained Effect uses exactly that Measure, that every
quantity is nonzero, and that the signed total closes to zero.
-/
def ofSingleMeasureEffects?
    (effects : List Effect) : Option (BalancedMovement LocusId) := do
  let first ← effects.head?
  ofEffects? first.measure effects

end Loam.PracticalMovement
