import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.CurrentQuantityPresence

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity presence

This is the narrow production evidence earned by a current household observation
where one `Locus × Measure` coordinate is known to be nonzero while its exact
Quantity is not known.

It is deliberately weaker than `CurrentQuantityAnchor`: no scalar is retained
and no arithmetic may consume this evidence. The shared reflected-root cut makes
the observation temporal without introducing dates or ordering from Event ids.

If later correction-aware Event activity touches an asserted coordinate, the
presence observation no longer answers the current question. Unrelated later
Events do not invalidate it.
-/

structure Evidence where
  reflectedRoots : List EventId
  coordinates : List EffectCoordinate
  rootNodup : reflectedRoots.Nodup
  coordinateNodup : coordinates.Nodup
deriving Repr, DecidableEq

namespace Evidence

def ofLists?
    (reflectedRoots : List EventId)
    (coordinates : List EffectCoordinate) : Option Evidence :=
  if hRoots : reflectedRoots.Nodup then
    if hCoordinates : coordinates.Nodup then
      some {
        reflectedRoots := reflectedRoots
        coordinates := coordinates
        rootNodup := hRoots
        coordinateNodup := hCoordinates
      }
    else
      none
  else
    none

def empty : Evidence := {
  reflectedRoots := []
  coordinates := []
  rootNodup := by simp
  coordinateNodup := by simp
}

def covers (evidence : Evidence) (coordinate : EffectCoordinate) : Bool :=
  evidence.coordinates.contains coordinate

end Evidence

private def deltaFrontier
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence) : Except String EventMemory := do
  if !Loam.Application.correctionReferencesClosed events corrections then
    throw "loam: current quantity presence cannot resolve one or more correction endpoints"
  let some currentRoots := Loam.Application.correctionRootIds? events corrections
    | throw "loam: current quantity presence requires one admitted Event correction frontier"
  if !(evidence.reflectedRoots.all fun root => currentRoots.contains root) then
    throw "loam: current quantity presence references an Event that is not a stable correction root"
  let some frontier :=
      Loam.Application.correctionFrontierExcludingRoots?
        events corrections evidence.reflectedRoots
    | throw "loam: current quantity presence requires one admitted Event correction frontier"
  return frontier

private def coordinateChanged
    (frontier : EventMemory)
    (coordinate : EffectCoordinate) : Bool :=
  frontier.events.any fun event =>
    event.effects.any fun effect => decide (effect.coordinate = coordinate)

/--
Answer whether one coordinate is still justified as present-but-exact-amount-
unknown at the current Event frontier.

Absence of a presence assertion returns `false`. A later Event affecting that
coordinate also returns `false`: the old observation remains historical
evidence but no longer proves current presence. Malformed correction/root
evidence fails closed.
-/
def inspectCurrentPresence
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinate : EffectCoordinate) : Except String Bool := do
  if !evidence.covers coordinate then
    return false
  let frontier ← deltaFrontier events corrections evidence
  return !(coordinateChanged frontier coordinate)

/-- Inspect several coordinates while admitting the shared cut at most once. -/
def inspectCurrentPresences
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinates : List EffectCoordinate) : Except String (List Bool) := do
  let covered := coordinates.map evidence.covers
  if !(covered.any id) then
    return covered
  let frontier ← deltaFrontier events corrections evidence
  return coordinates.map fun coordinate =>
    evidence.covers coordinate && !(coordinateChanged frontier coordinate)

end Loam.CurrentQuantityPresence
