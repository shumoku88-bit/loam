import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.CurrentQuantityAnchor

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity anchor

Observation 246 first earned one shared reflected-root cut for quantities observed
together at one reconciliation boundary. Its 2026-09-27 incremental follow-up
qualified the smallest extension needed when a household observes another
coordinate later:

- one or more anonymous reconciliation groups;
- one shared finite set of reflected Event correction roots per group;
- one exact asserted quantity per observed `Locus × Measure` coordinate;
- at most one live group for any coordinate.

Groups are representation factoring, not stable household identity. Re-observing
one coordinate may move that coordinate into a newer group without revising an
anchor history graph.

This remains application-level current-support evidence. It does not claim
zero-origin or bounded historical completeness, mutate Actual, infer chronology,
or restore the retired QuantityBasis/BasisCut subsystem.
-/

/-- One exact quantity assertion made at one reconciliation boundary. -/
structure Assertion where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

/--
One anonymous reconciliation group.

Every assertion in the group was observed against the same reflected-root cut.
The group itself has no stable semantic identity.
-/
structure Group where
  reflectedRoots : List EventId
  assertions : List Assertion
  rootNodup : reflectedRoots.Nodup
  coordinateNodup : (assertions.map Assertion.coordinate).Nodup
deriving Repr, DecidableEq

namespace Group

/-- Admit one finite reconciliation group with unique roots and coordinates. -/
def ofLists?
    (reflectedRoots : List EventId)
    (assertions : List Assertion) : Option Group :=
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

/-- Look up one assertion inside one reconciliation group. -/
def assertionFor? (group : Group) (coordinate : EffectCoordinate) : Option Assertion :=
  group.assertions.find? fun assertion => decide (assertion.coordinate = coordinate)

/-- Coordinates carried by one reconciliation group. -/
def coordinates (group : Group) : List EffectCoordinate :=
  group.assertions.map Assertion.coordinate

end Group

/--
One replaceable current-support image.

The image may contain several anonymous reconciliation groups. Global coordinate
uniqueness prevents two independently observed cuts from competing for the same
current answer.
-/
structure Evidence where
  groups : List Group
  coordinateNodup :
    ((groups.flatMap fun group => group.assertions).map Assertion.coordinate).Nodup
deriving Repr, DecidableEq

namespace Evidence

private def allAssertions (groups : List Group) : List Assertion :=
  groups.flatMap fun group => group.assertions

/-- Admit several groups only when their asserted coordinates are globally unique. -/
def ofGroups? (groups : List Group) : Option Evidence :=
  let coordinates := (allAssertions groups).map Assertion.coordinate
  if hCoordinates : coordinates.Nodup then
    some {
      groups := groups
      coordinateNodup := hCoordinates
    }
  else
    none

/--
Backward-compatible constructor for one reconciliation group.

Existing callers that deliberately model one observation boundary can keep using
this narrow entrance.
-/
def ofLists?
    (reflectedRoots : List EventId)
    (assertions : List Assertion) : Option Evidence := do
  let group ← Group.ofLists? reflectedRoots assertions
  ofGroups? [group]

/-- No current reconciliation evidence. -/
def empty : Evidence := {
  groups := []
  coordinateNodup := by simp
}

/-- Return the sole group only when the image has exactly one reconciliation group. -/
def singleGroup? (evidence : Evidence) : Option Group :=
  match evidence.groups with
  | [group] => some group
  | _ => none

/-- Flatten all current assertions without exposing group representation to callers. -/
def assertions (evidence : Evidence) : List Assertion :=
  allAssertions evidence.groups

/-- Coordinates carrying exact current assertions. -/
def coordinates (evidence : Evidence) : List EffectCoordinate :=
  evidence.assertions.map Assertion.coordinate

/-- Find the unique reconciliation group supporting one coordinate. -/
def groupFor? (evidence : Evidence) (coordinate : EffectCoordinate) : Option Group :=
  evidence.groups.find? fun group => (group.assertionFor? coordinate).isSome

/-- Look up only an explicitly asserted current coordinate. -/
def assertionFor? (evidence : Evidence) (coordinate : EffectCoordinate) : Option Assertion := do
  let group ← evidence.groupFor? coordinate
  group.assertionFor? coordinate

/-- Preserve all groups except selected coordinates, dropping groups that become empty. -/
def withoutCoordinates
    (evidence : Evidence)
    (coordinates : List EffectCoordinate) : Option Evidence := do
  let groups := evidence.groups.filterMap fun group =>
    let assertions :=
      group.assertions.filter fun assertion => !(coordinates.contains assertion.coordinate)
    if assertions.isEmpty then
      none
    else
      Group.ofLists? group.reflectedRoots assertions
  ofGroups? groups

/--
Replace any prior support for the supplied group's coordinates, then append that
group as the newest current observation.

This changes no group whose coordinates were not re-observed.
-/
def replacingWithGroup? (evidence : Evidence) (group : Group) : Option Evidence := do
  let retained ← evidence.withoutCoordinates group.coordinates
  ofGroups? (retained.groups ++ [group])

end Evidence

/-- Admit one correction-aware delta Event world for one reflected-root cut. -/
private def deltaFrontier
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (reflectedRoots : List EventId) : Except String EventMemory := do
  if !Loam.Application.correctionReferencesClosed events corrections then
    throw "loam: current quantity anchor cannot resolve one or more correction endpoints"
  let some currentRoots := Loam.Application.correctionRootIds? events corrections
    | throw "loam: current quantity anchor requires one admitted Event correction frontier"
  if !(reflectedRoots.all fun root => currentRoots.contains root) then
    throw "loam: current quantity anchor references an Event that is not a stable correction root"
  let some frontier :=
      Loam.Application.correctionFrontierExcludingRoots?
        events corrections reflectedRoots
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
Inspect one asserted current quantity against its reconciliation group's
correction-aware Event world.

Absence of an assertion is not an error; it means this evidence family does not
support the queried coordinate.
-/
def inspectQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinate : EffectCoordinate) : Except String (Option Quantity) := do
  let some group := evidence.groupFor? coordinate
    | return none
  let some assertion := group.assertionFor? coordinate
    | return none
  let frontier ← deltaFrontier events corrections group.reflectedRoots
  return some (quantityFromDelta frontier assertion)

/--
Inspect several coordinates while evaluating each selected reconciliation group
at most once.

Missing assertions remain `none` in caller order. Groups unrelated to the
requested coordinates are not forced.
-/
def inspectQuantities
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : Evidence)
    (coordinates : List EffectCoordinate) : Except String (List (Option Quantity)) := do
  let resolved ← evidence.groups.foldlM
    (fun rows group => do
      let selected :=
        coordinates.filter fun coordinate => (group.assertionFor? coordinate).isSome
      if selected.isEmpty then
        return rows
      let frontier ← deltaFrontier events corrections group.reflectedRoots
      let currentRows := selected.filterMap fun coordinate => do
        let assertion ← group.assertionFor? coordinate
        some (coordinate, quantityFromDelta frontier assertion)
      return rows ++ currentRows)
    ([] : List (EffectCoordinate × Quantity))
  return coordinates.map fun coordinate =>
    (resolved.find? fun row => decide (row.1 = coordinate)).map Prod.snd

end Loam.CurrentQuantityAnchor
