import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.ScheduledReplacement
import Loam.Core.QuantityBasisCorrectionMemory

namespace Loam.Experiments.Observation218

open Loam.Core

set_option autoImplicit false

structure ReplacementEdge (Id : Type) where
  superseded : Id
  successor : Id
deriving Repr, DecidableEq

def endpointUnique {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  decide
    ((edges.map ReplacementEdge.superseded).Nodup ∧
      (edges.map ReplacementEdge.successor).Nodup)

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

def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    pathAcyclic edges edge.superseded [] (edges.length + 1)

def structurallyAdmissible {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (ReplacementEdge Id)) : Bool :=
  endpointUnique edges && referencesClosed carrier edges && acyclic edges

private def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.superseded = id)

def frontier {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (ReplacementEdge Id)) : List Id :=
  carrier.filter fun id => !(isSuperseded edges id)

def eventCorrectionEdges
    (memory : EventCorrectionMemory) : List (ReplacementEdge EventId) :=
  memory.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

def actualValidityCorrectionEdges {Time : Type}
    (history : ActualValidityHistory Time) : List (ReplacementEdge ActualValidityFactId) :=
  history.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

def scheduledReplacementEdges
    (memory : ScheduledReplacementMemory) : List (ReplacementEdge ScheduledId) :=
  memory.replacements.map fun replacement =>
    { superseded := replacement.source
      successor := replacement.replacement }

def quantityBasisCorrectionEdges
    (memory : QuantityBasisCorrectionMemory) : List (ReplacementEdge QuantityBasisId) :=
  memory.corrections.map fun correction =>
    { superseded := correction.target
      successor := correction.replacement }

private def chain : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 2 } ]

example : structurallyAdmissible [0, 1, 2, 3] chain = true := by
  decide

example : frontier [0, 1, 2, 3] chain = [2, 3] := by
  decide

private def branching : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 0, successor := 2 } ]

example : structurallyAdmissible [0, 1, 2] branching = false := by
  decide

private def merging : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 2 },
    { superseded := 1, successor := 2 } ]

example : structurallyAdmissible [0, 1, 2] merging = false := by
  decide

private def cycle : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 0 } ]

example : structurallyAdmissible [0, 1] cycle = false := by
  decide

private def openReference : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 9 } ]

example : structurallyAdmissible [0, 1, 2] openReference = false := by
  decide

end Loam.Experiments.Observation218
