import Loam.Application.ReplacementFrontier

namespace Loam.Observation273

open Loam.Application
open Loam.Application.ReplacementFrontier

set_option autoImplicit false

/-!
# Observation 273 — replacement-frontier cycle traversal cost

Production `ReplacementFrontier.acyclic` intentionally uses a bounded
whole-domain start-return detector whose semantic correspondence to ordinary
finite-relation acyclicity was already qualified by Observation 218 and CSA-002.

The adversarial persistence audit raised a different question:

> Can the same cycle decision avoid re-walking an already-qualified suffix?

This observation does not modify production. It compares two list-only shadows
that require no `Hashable` instance and therefore preserve the current
`[DecidableEq Id]` abstraction boundary:

1. the current bounded start-return traversal;
2. a global-done traversal that remembers nodes whose suffix has already reached
   a terminal or an already-qualified suffix.

The cost counter measures only source comparisons performed by linear successor
lookup. It deliberately does not claim wall-clock complexity for the complete
frontier admission path.
-/

private def nextWithCost? {Id : Type} [DecidableEq Id] :
    List (Edge Id) → Id → Option Id × Nat
  | [], _ => (none, 0)
  | edge :: rest, id =>
      if edge.source = id then
        (some edge.successor, 1)
      else
        let tail := nextWithCost? rest id
        (tail.1, tail.2 + 1)

private def returnsToStartWithCost {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (start : Id) : Nat → Id → Bool × Nat
  | 0, _ => (false, 0)
  | fuel + 1, current =>
      let lookup := nextWithCost? edges current
      match lookup.1 with
      | none => (false, lookup.2)
      | some next =>
          if next = start then
            (true, lookup.2)
          else
            let tail := returnsToStartWithCost edges start fuel next
            (tail.1, lookup.2 + tail.2)

private structure DetectorResult where
  acyclic : Bool
  nextComparisons : Nat
deriving Repr, DecidableEq

private def startReturnScan {Id : Type} [DecidableEq Id]
    (allEdges : List (Edge Id)) : List (Edge Id) → DetectorResult
  | [] => { acyclic := true, nextComparisons := 0 }
  | edge :: rest =>
      let walk :=
        returnsToStartWithCost
          allEdges edge.source allEdges.length edge.source
      if walk.1 then
        { acyclic := false, nextComparisons := walk.2 }
      else
        let tail := startReturnScan allEdges rest
        {
          acyclic := tail.acyclic
          nextComparisons := walk.2 + tail.nextComparisons
        }

private def startReturnDetector {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : DetectorResult :=
  startReturnScan edges edges

private structure WalkResult (Id : Type) where
  acyclic : Bool
  done : List Id
  nextComparisons : Nat
deriving Repr

private def globalDoneWalk {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) :
    Nat → Id → List Id → List Id → WalkResult Id
  | 0, _, _, done =>
      { acyclic := false, done := done, nextComparisons := 0 }
  | fuel + 1, current, path, done =>
      if current ∈ done then
        {
          acyclic := true
          done := path ++ done
          nextComparisons := 0
        }
      else if current ∈ path then
        {
          acyclic := false
          done := done
          nextComparisons := 0
        }
      else
        let lookup := nextWithCost? edges current
        match lookup.1 with
        | none =>
            {
              acyclic := true
              done := current :: path ++ done
              nextComparisons := lookup.2
            }
        | some next =>
            let tail :=
              globalDoneWalk edges fuel next (current :: path) done
            {
              acyclic := tail.acyclic
              done := tail.done
              nextComparisons := lookup.2 + tail.nextComparisons
            }

private def globalDoneScan {Id : Type} [DecidableEq Id]
    (allEdges : List (Edge Id)) :
    List (Edge Id) → List Id → DetectorResult
  | [], _ => { acyclic := true, nextComparisons := 0 }
  | edge :: rest, done =>
      if edge.source ∈ done then
        globalDoneScan allEdges rest done
      else
        let walk :=
          globalDoneWalk
            allEdges (allEdges.length + 1) edge.source [] done
        if !walk.acyclic then
          {
            acyclic := false
            nextComparisons := walk.nextComparisons
          }
        else
          let tail := globalDoneScan allEdges rest walk.done
          {
            acyclic := tail.acyclic
            nextComparisons := walk.nextComparisons + tail.nextComparisons
          }

private def globalDoneDetector {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : DetectorResult :=
  globalDoneScan edges edges []

private def chain (n : Nat) : List (Edge Nat) :=
  (List.range n).map fun i =>
    { source := i, successor := i + 1 }

private def simpleCycle : List (Edge Nat) :=
  [
    { source := 0, successor := 1 },
    { source := 1, successor := 2 },
    { source := 2, successor := 0 }
  ]

private def selfLoop : List (Edge Nat) :=
  [{ source := 0, successor := 0 }]

private def lasso : List (Edge Nat) :=
  [
    { source := 0, successor := 1 },
    { source := 1, successor := 2 },
    { source := 2, successor := 1 }
  ]

private def branching : List (Edge Nat) :=
  [
    { source := 0, successor := 1 },
    { source := 0, successor := 2 }
  ]

private def merging : List (Edge Nat) :=
  [
    { source := 0, successor := 2 },
    { source := 1, successor := 2 }
  ]

/--
The shadow of the current detector agrees with the production executable
decision on representative acyclic and cyclic shapes.
-/
theorem start_return_shadow_matches_production :
    (startReturnDetector (chain 8)).acyclic = acyclic (chain 8) ∧
    (startReturnDetector simpleCycle).acyclic = acyclic simpleCycle ∧
    (startReturnDetector selfLoop).acyclic = acyclic selfLoop ∧
    (startReturnDetector lasso).acyclic = acyclic lasso ∧
    (startReturnDetector branching).acyclic = acyclic branching ∧
    (startReturnDetector merging).acyclic = acyclic merging := by
  native_decide

/--
The global-done candidate makes the same whole-graph cycle decision on the
representative shapes, including a tail entering a cycle and endpoint-uniqueness
violations that are rejected separately by `endpointUnique`.
-/
theorem global_done_matches_representative_decisions :
    (globalDoneDetector (chain 8)).acyclic = acyclic (chain 8) ∧
    (globalDoneDetector simpleCycle).acyclic = acyclic simpleCycle ∧
    (globalDoneDetector selfLoop).acyclic = acyclic selfLoop ∧
    (globalDoneDetector lasso).acyclic = acyclic lasso ∧
    (globalDoneDetector branching).acyclic = acyclic branching ∧
    (globalDoneDetector merging).acyclic = acyclic merging := by
  native_decide

/--
On an ascending chain, the current detector repeatedly re-walks already-known
suffixes. Counting only linear `next?` source comparisons, global-done pays for
the full suffix once.

These concrete checkpoints establish the growth pressure without yet promoting
an asymptotic theorem into production.
-/
theorem chain_lookup_cost_checkpoints :
    (startReturnDetector (chain 8)).nextComparisons = 260 ∧
    (globalDoneDetector (chain 8)).nextComparisons = 44 ∧
    (startReturnDetector (chain 16)).nextComparisons = 1736 ∧
    (globalDoneDetector (chain 16)).nextComparisons = 152 ∧
    (startReturnDetector (chain 32)).nextComparisons = 12432 ∧
    (globalDoneDetector (chain 32)).nextComparisons = 560 := by
  native_decide

/--
The candidate does not widen the abstraction boundary: both detectors need only
decidable equality over identity, exactly like production ReplacementFrontier.
No HashMap or Hashable instance is involved.
-/
theorem chain_decisions_remain_acyclic :
    (globalDoneDetector (chain 64)).acyclic = true ∧
    (startReturnDetector (chain 64)).acyclic = true := by
  native_decide

end Loam.Observation273
