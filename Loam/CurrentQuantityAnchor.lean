import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.CurrentQuantityAnchor

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity anchor

Observation 246 earned one narrow application-level evidence shape for quantities
observed together at one reconciliation boundary:

- one shared finite set of Event correction roots already reflected by the
  observation;
- one exact asserted quantity per observed `Locus × Measure` coordinate.

This is intentionally not a Core accounting primitive. It does not claim
zero-origin history, mutate Actual, infer chronology, or restore the retired
QuantityBasis/BasisCut subsystem.
-/

/-- One exact quantity assertion made at the shared reconciliation boundary. -/
structure Assertion where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

/--
One current reconciliation image. The shared root set is represented once even
when several coordinates were observed together.
-/
structure Evidence where
  reflectedRoots : List EventId
  assertions : List Assertion
  rootNodup : reflectedRoots.Nodup
  coordinateNodup : (assertions.map Assertion.coordinate).Nodup
deriving Repr, DecidableEq

namespace Evidence

/-- Admit only finite evidence with unique roots and at most one assertion per coordinate. -/
def ofLists?
    (reflectedRoots : List EventId)
    (assertions : List Assertion) : Option Evidence :=
  if hRoots : reflectedRoots.Nodup then
    if hCoordinates : (assertions.map Assertion.coordinate).Nodup then
      some {
        reflectedRoots := reflectedRoots
        assertions := assertions
        rootNodup := hRoots
        coordinateNodup := hCoordinates
      }
    else
      none
  else
    none

/-- No current reconciliation evidence. -/
def empty : Evidence := {
  reflectedRoots := []
  assertions := []
  rootNodup := by simp
  coordinateNodup := by simp
}

/-- Look up only an explicitly asserted current coordinate. -/
def assertionFor? (evidence : Evidence) (coordinate : EffectCoordinate) : Option Assertion :=
  evidence.assertions.find? fun assertion => decide (assertion.coordinate = coordinate)

/-- Coordinates carrying explicit current assertions. -/
def coordinates (evidence : Evidence) : List EffectCoordinate :=
  evidence.assertions.map Assertion.coordinate

end Evidence

/--
Admit the one correction-aware delta Event world shared by selected assertions
from one current reconciliation image.
-/
private def deltaFrontier
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence) : Except String EventMemory := do
  if !Loam.Application.correctionReferencesClosed events corrections then
    throw "loam: current quantity anchor cannot resolve one or more correction endpoints"
  let some currentRoots := Loam.Application.correctionRootIds? events corrections
    | throw "loam: current quantity anchor requires one admitted Event correction frontier"
  if !(evidence.reflectedRoots.all fun root => currentRoots.contains root) then
    throw "loam: current quantity anchor references an Event that is not a stable correction root"
  let some frontier :=
      Loam.Application.correctionFrontierExcludingRoots?
        events corrections evidence.reflectedRoots
    | throw "loam: current quantity anchor requires one admitted Event correction frontier"
  return frontier

private def quantityFromDelta
    (frontier : EventMemory)
    (assertion : Assertion) : Quantity :=
  let delta :=
    EventMemory.quantityAtRecorded
      frontier assertion.coordinate.locus assertion.coordinate.measure
  Quantity.ofQuanta (assertion.quantity.quanta + delta.quanta)

/--
Inspect one asserted current quantity against the current correction-aware Event
world.

Every reflected root must still be a represented stable correction root. The
asserted scalar is then combined only with current terminal Events whose roots
are outside the shared cut. Event summation remains delegated to the existing
`EventMemory.quantityAtRecorded` projection.

Absence of an assertion is not an error; it means this evidence family does not
support the queried coordinate.
-/
def inspectQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinate : EffectCoordinate) : Except String (Option Quantity) := do
  let some assertion := evidence.assertionFor? coordinate
    | return none
  let frontier ← deltaFrontier events corrections evidence
  return some (quantityFromDelta frontier assertion)

/--
Inspect several coordinates from one reconciliation image while admitting the
shared reflected-root cut only once.

Missing assertions remain `none` in their original positions. If none of the
requested coordinates is asserted, the correction-world obligation is not
forced, matching the point inspection's absence behavior.
-/
def inspectQuantities
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinates : List EffectCoordinate) : Except String (List (Option Quantity)) := do
  let assertions := coordinates.map fun coordinate => evidence.assertionFor? coordinate
  if !(assertions.any fun assertion => assertion.isSome) then
    return assertions.map fun _ => (none : Option Quantity)
  let frontier ← deltaFrontier events corrections evidence
  return assertions.map fun
    | none => none
    | some assertion => some (quantityFromDelta frontier assertion)

end Loam.CurrentQuantityAnchor
