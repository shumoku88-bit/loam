import Loam.Application.ReplacementFrontier
import Loam.Core.Scheduled

open Loam.Application.ReplacementFrontier
open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private theorem scheduledIdToken_injective : Function.Injective (fun id : ScheduledId => id.token) := by
  intro ⟨a⟩ ⟨b⟩ h; cases h; rfl

private def edge (s : String) (d : String) : Edge ScheduledId :=
  { source := ⟨s⟩, successor := ⟨d⟩ }

private def checkCase
    (name : String)
    (edges : List (Edge ScheduledId))
    (expectedAcyclic : Bool) : IO Unit := do
  let direct := acyclic edges
  let indexed := acyclicIndexedBy (fun id => id.token) scheduledIdToken_injective edges
  expect (direct == expectedAcyclic)
    s!"Case '{name}': direct acyclic returned {direct}, expected {expectedAcyclic}"
  expect (indexed == direct)
    s!"Case '{name}': indexed ({indexed}) != direct ({direct})"

def main : IO Unit := do
  -- 1. Empty list
  checkCase "empty" [] true

  -- 2. Single edge
  checkCase "single edge" [edge "a" "b"] true

  -- 3. Multi-hop linear chain
  checkCase "linear chain 3" [edge "a" "b", edge "b" "c", edge "c" "d"] true

  -- 4. Reversed edge order of chain
  checkCase "reversed chain 3" [edge "c" "d", edge "b" "c", edge "a" "b"] true

  -- 5. Self loop
  checkCase "self loop" [edge "a" "a"] false

  -- 6. 2-cycle
  checkCase "2-cycle" [edge "a" "b", edge "b" "a"] false

  -- 7. 3-cycle
  checkCase "3-cycle" [edge "a" "b", edge "b" "c", edge "c" "a"] false

  -- 8. Lasso (chain into cycle)
  checkCase "lasso" [edge "a" "b", edge "b" "c", edge "c" "b"] false

  -- 9. Disconnected paths
  checkCase "disconnected paths" [edge "a" "b", edge "c" "d", edge "e" "f"] true

  -- 10. Disconnected path with a cycle
  checkCase "disconnected with cycle" [edge "a" "b", edge "c" "d", edge "d" "c"] false

  -- 11. Malformed: duplicate source (branching forward)
  checkCase "duplicate source" [edge "a" "b", edge "a" "c"] true

  -- 12. Malformed: duplicate successor (merging backward)
  checkCase "duplicate successor" [edge "a" "c", edge "b" "c"] true

  -- 13. Malformed: exact duplicate edge
  checkCase "duplicate edge" [edge "a" "b", edge "a" "b"] true

  -- 14. Malformed: duplicate source with a cycle
  checkCase "duplicate source with cycle" [edge "a" "b", edge "b" "a", edge "a" "c"] false

  -- 15. Malformed: duplicate successor with a cycle
  checkCase "duplicate successor with cycle" [edge "a" "b", edge "b" "a", edge "c" "b"] false

  -- 16. Long cycle
  let longCycle := [
    edge "1" "2", edge "2" "3", edge "3" "4", edge "4" "5",
    edge "5" "6", edge "6" "7", edge "7" "8", edge "8" "1"
  ]
  checkCase "long cycle" longCycle false

  -- 17. Long acyclic chain
  let longChain := [
    edge "1" "2", edge "2" "3", edge "3" "4", edge "4" "5",
    edge "5" "6", edge "6" "7", edge "7" "8", edge "8" "9"
  ]
  checkCase "long chain" longChain true

  IO.println "All 17 ReplacementFrontier indexed cycle admission test cases passed."
