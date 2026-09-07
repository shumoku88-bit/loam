import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.ScheduledReplacement

namespace Loam.Experiments.Observation218

open Loam.Core

set_option autoImplicit false

/-!
# Observation 218 — finite partial-injective frontier factorization

Several current LOAM boundaries independently retain a one-to-one replacement
relation and then recover a current frontier by rejecting malformed graph shapes.
This experiment factors only that structural graph algebra. Domain-specific laws
remain outside it.
-/

/--
One candidate replacement edge over an arbitrary identity type.

`superseded` is the identity removed from the current frontier when the edge is
admitted. `successor` remains retained and may itself be superseded by another
edge.
-/
structure ReplacementEdge (Id : Type) where
  superseded : Id
  successor : Id
deriving Repr, DecidableEq

/-- Endpoint uniqueness makes the edge set a finite partial injection. -/
def endpointUnique {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  decide
    ((edges.map ReplacementEdge.superseded).Nodup ∧
      (edges.map ReplacementEdge.successor).Nodup)

/-- Every edge endpoint must belong to the caller-supplied retained carrier. -/
def referencesClosed {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    decide (edge.superseded ∈ carrier ∧ edge.successor ∈ carrier)

private def nextSuccessor? {Id : Type} [DecidableEq Id] :
    List (ReplacementEdge Id) → Id → Option Id
  | [], _ => none
  | edge :: rest, id =>
      if edge.superseded = id then
        some edge.successor
      else
        nextSuccessor? rest id

private def pathAcyclic {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (current : Id)
    (seen : List Id) : Nat → Bool
  | 0 => false
  | fuel + 1 =>
      if current ∈ seen then
        false
      else
        match nextSuccessor? edges current with
        | none => true
        | some next => pathAcyclic edges next (current :: seen) fuel

/-- A finite partial injection is accepted only when following successors cannot cycle. -/
def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    pathAcyclic edges edge.superseded [] (edges.length + 1)

/--
Structural admission shared by the candidate frontier families.

This intentionally says nothing about Event existence beyond the explicit
carrier, same-Event replacement, Scheduled terminal compatibility, relation
quantity, chronology, or any other domain law.
-/
def structurallyAdmissible {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (ReplacementEdge Id)) : Bool :=
  endpointUnique edges && referencesClosed carrier edges && acyclic edges

private def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.superseded = id)

/--
The current structural frontier is the retained carrier minus the domain of the
partial replacement map.
-/
def frontier {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (ReplacementEdge Id)) : List Id :=
  carrier.filter fun id => !(isSuperseded edges id)

/-! ## Production-shape adapters

These functions do not replace any production boundary. They expose the common
replacement graph already present in three independently meaningful families.
-/

/-- Event Correction uses `target -> replacement`. -/
def eventCorrectionEdges
    (memory : EventCorrectionMemory) : List (ReplacementEdge EventId) :=
  memory.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

/-- Actual-validity Correction uses `target fact -> replacement fact`. -/
def actualValidityCorrectionEdges {Time : Type}
    (history : ActualValidityHistory Time) : List (ReplacementEdge ActualValidityFactId) :=
  history.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

/-- Scheduled Replacement uses `source -> replacement`. -/
def scheduledReplacementEdges
    (memory : ScheduledReplacementMemory) : List (ReplacementEdge ScheduledId) :=
  memory.replacements.map fun replacement =>
    { superseded := replacement.source
      successor := replacement.replacement }

/-! ## Bounded witnesses -/

private def chain : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 2 } ]

/-- A closed one-to-one acyclic chain is structurally admitted. -/
example : structurallyAdmissible [0, 1, 2, 3] chain = true := by
  decide

/-- The frontier keeps the terminal successor and untouched carrier identity. -/
example : frontier [0, 1, 2, 3] chain = [2, 3] := by
  decide

/-- Competing successors violate partial-function structure. -/
private def branching : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 0, successor := 2 } ]

example : structurallyAdmissible [0, 1, 2] branching = false := by
  decide

/-- Shared successors violate injectivity and therefore cannot hide a merge. -/
private def merging : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 2 },
    { superseded := 1, successor := 2 } ]

example : structurallyAdmissible [0, 1, 2] merging = false := by
  decide

/-- A one-to-one cycle is still rejected. -/
private def cycle : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 0 } ]

example : structurallyAdmissible [0, 1] cycle = false := by
  decide

/-- An otherwise well-shaped edge with an absent endpoint is not closed. -/
private def openReference : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 9 } ]

example : structurallyAdmissible [0, 1, 2] openReference = false := by
  decide

end Loam.Experiments.Observation218
