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

private theorem nextSuccessor?_some_mem_successors
    {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (source successor : Id)
    (hNext : nextSuccessor? edges source = some successor) :
    successor ∈ edges.map ReplacementEdge.successor := by
  induction edges with
  | nil =>
      simp [nextSuccessor?] at hNext
  | cons edge rest ih =>
      by_cases hSource : edge.superseded = source
      · simp [nextSuccessor?, hSource] at hNext
        subst successor
        simp
      · simp [nextSuccessor?, hSource] at hNext
        have hMem : successor ∈ rest.map ReplacementEdge.successor := ih hNext
        simp [hMem]

/--
If represented replacement identities are unique, the represented successor
lookup is injective: two sources cannot enter the same successor.
-/
theorem nextSuccessor?_injective_of_successor_nodup
    {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (hNodup : (edges.map ReplacementEdge.successor).Nodup)
    {left right successor : Id}
    (hLeft : nextSuccessor? edges left = some successor)
    (hRight : nextSuccessor? edges right = some successor) :
    left = right := by
  induction edges generalizing left right successor with
  | nil =>
      simp [nextSuccessor?] at hLeft
  | cons edge rest ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      rcases hNodup with ⟨hFresh, hRestNodup⟩
      by_cases hLeftHead : edge.superseded = left
      · have hSuccessor : edge.successor = successor := by
          simpa [nextSuccessor?, hLeftHead] using hLeft
        by_cases hRightHead : edge.superseded = right
        · exact hLeftHead.symm.trans hRightHead
        · have hRightRest : nextSuccessor? rest right = some successor := by
            simpa [nextSuccessor?, hRightHead] using hRight
          have hMem : successor ∈ rest.map ReplacementEdge.successor :=
            nextSuccessor?_some_mem_successors rest right successor hRightRest
          rw [← hSuccessor] at hMem
          exact False.elim (hFresh hMem)
      · have hLeftRest : nextSuccessor? rest left = some successor := by
          simpa [nextSuccessor?, hLeftHead] using hLeft
        by_cases hRightHead : edge.superseded = right
        · have hSuccessor : edge.successor = successor := by
            simpa [nextSuccessor?, hRightHead] using hRight
          have hMem : successor ∈ rest.map ReplacementEdge.successor :=
            nextSuccessor?_some_mem_successors rest left successor hLeftRest
          rw [← hSuccessor] at hMem
          exact False.elim (hFresh hMem)
        · have hRightRest : nextSuccessor? rest right = some successor := by
            simpa [nextSuccessor?, hRightHead] using hRight
          exact ih hRestNodup hLeftRest hRightRest

/-- Advance exactly `steps` represented successor edges, failing on a terminal node. -/
private def advance? {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Nat → Id → Option Id
  | 0, id => some id
  | steps + 1, id =>
      match nextSuccessor? edges id with
      | none => none
      | some next => advance? edges steps next

private theorem advance?_add
    {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (first second : Nat)
    (start : Id) :
    advance? edges (first + second) start =
      (advance? edges first start).bind (advance? edges second) := by
  induction first generalizing start with
  | zero =>
      simp [advance?]
  | succ first ih =>
      simp only [Nat.succ_add]
      simp [advance?]
      cases hNext : nextSuccessor? edges start with
      | none =>
          simp [hNext]
      | some next =>
          simp [hNext, ih]

/-- Every defined finite iterate of an injective successor lookup is injective. -/
theorem advance?_injective_of_successor_nodup
    {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (hNodup : (edges.map ReplacementEdge.successor).Nodup)
    (steps : Nat)
    {left right endpoint : Id}
    (hLeft : advance? edges steps left = some endpoint)
    (hRight : advance? edges steps right = some endpoint) :
    left = right := by
  induction steps generalizing left right endpoint with
  | zero =>
      simp [advance?] at hLeft hRight
      exact hLeft.trans hRight.symm
  | succ steps ih =>
      cases hLeftNext : nextSuccessor? edges left with
      | none =>
          simp [advance?, hLeftNext] at hLeft
      | some leftNext =>
          cases hRightNext : nextSuccessor? edges right with
          | none =>
              simp [advance?, hRightNext] at hRight
          | some rightNext =>
              have hLeftTail : advance? edges steps leftNext = some endpoint := by
                simpa [advance?, hLeftNext] using hLeft
              have hRightTail : advance? edges steps rightNext = some endpoint := by
                simpa [advance?, hRightNext] using hRight
              have hNextEq : leftNext = rightNext :=
                ih hLeftTail hRightTail
              have hLeftNext' : nextSuccessor? edges left = some rightNext := by
                simpa [hNextEq] using hLeftNext
              exact nextSuccessor?_injective_of_successor_nodup
                edges hNodup hLeftNext' hRightNext

/--
Cancellation across an injective walk: if the same endpoint occurs after
`prefix` steps and again after `period + prefix` steps, then the original start
itself returns after `period` steps. An external tail into a cycle would violate
successor injectivity.
-/
theorem repeated_advance_forces_start_return
    {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id))
    (hNodup : (edges.map ReplacementEdge.successor).Nodup)
    (period prefix : Nat)
    {start repeated : Id}
    (hPrefix : advance? edges prefix start = some repeated)
    (hRepeated : advance? edges (period + prefix) start = some repeated) :
    advance? edges period start = some start := by
  rw [advance?_add edges period prefix start] at hRepeated
  cases hPeriod : advance? edges period start with
  | none =>
      simp [hPeriod] at hRepeated
  | some afterPeriod =>
      have hTail : advance? edges prefix afterPeriod = some repeated := by
        simpa [hPeriod] using hRepeated
      have hEq : afterPeriod = start :=
        advance?_injective_of_successor_nodup
          edges hNodup prefix hTail hPrefix
      simpa [hEq] using hPeriod

/-- Seen-set cycle detector, matching Event Correction and Scheduled Replacement. -/
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

/-- Start-return detector, matching ActualValidity and QuantityBasis. -/
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

def acyclicByStartReturn {Id : Type} [DecidableEq Id]
    (edges : List (ReplacementEdge Id)) : Bool :=
  edges.all fun edge =>
    pathAcyclicFromStart edges edge.superseded edges.length edge.superseded

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

example : acyclic chain = true := by
  decide

example : acyclicByStartReturn chain = true := by
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

example : acyclic cycle = false := by
  decide

example : acyclicByStartReturn cycle = false := by
  decide

example : structurallyAdmissible [0, 1] cycle = false := by
  decide

/-- Tail entering a cycle: the path-local predicates differ. -/
private def lasso : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 1 },
    { superseded := 1, successor := 2 },
    { superseded := 2, successor := 1 } ]

example : pathAcyclicFromStart lasso 0 lasso.length 0 = true := by
  decide

example : pathAcyclic lasso 0 [] (lasso.length + 1) = false := by
  decide

/-- The lasso lies outside the partial-injection candidate: successor `1` is shared. -/
example : endpointUnique lasso = false := by
  decide

/-- Whole-graph checks still agree on rejecting the lasso. -/
example : acyclicByStartReturn lasso = false := by
  decide

example : acyclic lasso = false := by
  decide

private def openReference : List (ReplacementEdge Nat) :=
  [ { superseded := 0, successor := 9 } ]

example : structurallyAdmissible [0, 1, 2] openReference = false := by
  decide

end Loam.Experiments.Observation218
