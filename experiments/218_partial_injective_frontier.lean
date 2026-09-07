import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.ScheduledReplacement
import Loam.Core.QuantityBasisCorrectionMemory

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

/--
Seen-set cycle detector, matching the shape used by Event Correction and
Scheduled Replacement frontiers.
-/
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

/-- A finite replacement graph is cycle-free under the seen-set detector. -/
def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    pathAcyclic edges edge.superseded [] (edges.length + 1)

/--
Start-return cycle detector, matching the smaller traversal shape used by
ActualValidity and QuantityBasis correction frontiers.

Unlike the seen-set traversal, one path started outside a cycle can finish its
fuel without returning to that particular start. The production-style global
check starts from every retained edge source, so a real cycle still supplies one
of its own members as a start.
-/
private def pathAcyclicFromStart {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (start : Id) : Nat → Id → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextSuccessor? edges current with
      | none => true
      | some next =>
          if next = start then
            false
          else
            pathAcyclicFromStart edges start fuel next

/-- Global start-return cycle check: start once from every represented edge source. -/
def acyclicByStartReturn {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    pathAcyclicFromStart edges edge.superseded edges.length edge.superseded

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
replacement graph already present in four independently meaningful families.
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

/-- QuantityBasis Correction uses `target basis -> replacement basis`. -/
def quantityBasisCorrectionEdges
    (memory : QuantityBasisCorrectionMemory) : List (ReplacementEdge QuantityBasisId) :=
  memory.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

/-! ## Bounded witnesses -/

private def chain : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 2 } ]

/-- A closed one-to-one acyclic chain is structurally admitted. -/
example : structurallyAdmissible [0, 1, 2, 3] chain = true := by
  decide

/-- Both production-style cycle detectors accept the ordinary chain. -/
example : acyclic chain = true := by
  decide

example : acyclicByStartReturn chain = true := by
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

/-- A one-to-one cycle is rejected by both detector shapes. -/
private def cycle : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 0 } ]

example : acyclic cycle = false := by
  decide

example : acyclicByStartReturn cycle = false := by
  decide

example : structurallyAdmissible [0, 1] cycle = false := by
  decide

/--
A tail entering a cycle exposes the local difference between the algorithms:
starting at the tail, start-return alone does not rediscover that tail, while the
seen-set traversal detects the repeated interior node.
-/
private def lasso : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 2 },
    { superseded := 2, successor := 1 } ]

example : pathAcyclicFromStart lasso 0 lasso.length 0 = true := by
  decide

example : pathAcyclic lasso 0 [] (lasso.length + 1) = false := by
  decide

/--
The global start-return check nevertheless rejects the lasso because it also
starts from the cycle member `1`. This explains why the smaller production
algorithm can still serve as a whole-graph cycle check.
-/
example : acyclicByStartReturn lasso = false := by
  decide

example : acyclic lasso = false := by
  decide

/-- An otherwise well-shaped edge with an absent endpoint is not closed. -/
private def openReference : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 9 } ]

example : structurallyAdmissible [0, 1, 2] openReference = false := by
  decide

end Loam.Experiments.Observation218
