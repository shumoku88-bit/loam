import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.ScheduledReplacement
import Loam.Core.QuantityBasisCorrectionMemory

namespace Loam.Experiments.Observation218Minimal

open Loam.Core

set_option autoImplicit false

structure Edge (Id : Type) where
  source : Id
  successor : Id

def endpointUnique {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  decide (
    (edges.map Edge.source).Nodup ∧
    (edges.map Edge.successor).Nodup)

def referencesClosed {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (Edge Id)) : Bool :=
  edges.all fun edge =>
    decide (edge.source ∈ carrier ∧ edge.successor ∈ carrier)

private def next? {Id : Type} [DecidableEq Id] :
    List (Edge Id) → Id → Option Id
  | [], _ => none
  | edge :: rest, id =>
      if edge.source = id then some edge.successor else next? rest id

private def returnsToStartWithin {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (start : Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match next? edges current with
      | none => false
      | some next =>
          if next = start then true
          else returnsToStartWithin edges start fuel next

def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  !(edges.any fun edge =>
    returnsToStartWithin edges edge.source edges.length edge.source)

def structurallyAdmissible {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (Edge Id)) : Bool :=
  endpointUnique edges && referencesClosed carrier edges && acyclic edges

private def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.source = id)

def frontier {Id : Type} [DecidableEq Id]
    (carrier : List Id) (edges : List (Edge Id)) : List Id :=
  carrier.filter fun id => !(isSuperseded edges id)

def eventCorrectionEdges
    (memory : EventCorrectionMemory) : List (Edge EventId) :=
  memory.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

def actualValidityCorrectionEdges {Time : Type}
    (history : ActualValidityHistory Time) : List (Edge ActualValidityFactId) :=
  history.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

def scheduledReplacementEdges
    (memory : ScheduledReplacementMemory) : List (Edge ScheduledId) :=
  memory.replacements.map fun replacement =>
    { source := replacement.source, successor := replacement.replacement }

def quantityBasisCorrectionEdges
    (memory : QuantityBasisCorrectionMemory) : List (Edge QuantityBasisId) :=
  memory.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

end Loam.Experiments.Observation218Minimal