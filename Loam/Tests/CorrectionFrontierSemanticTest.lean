import Loam.Core.EventMemory
import Loam.Core.EventCorrectionMemory
import Loam.Application.CorrectionFrontier

namespace Loam.Tests.CorrectionFrontierSemanticTest

open Loam.Core
open Loam.Application

private def mkEvent (id : String) : Event :=
  { id := ⟨id⟩, effects := [], keyNodup := by simp }

private def mkEvents (ids : List String) : EventMemory :=
  match EventMemory.ofEvents? (ids.map mkEvent) with
  | some m => m
  | none => { events := [], idNodup := by simp }

private def mkCorrections (edges : List (String × String)) : EventCorrectionMemory :=
  let list := edges.map fun (t, r) => ({ target := ⟨t⟩, replacement := ⟨r⟩ } : EventCorrection)
  match EventCorrectionMemory.ofCorrections? list with
  | some m => m
  | none => { corrections := [], idNodup := by simp }

private def assertEq [DecidableEq α] [Repr α] (label : String) (actual expected : α) : IO Unit := do
  unless actual == expected do
    throw <| IO.userError s!"Assertion failed for [{label}]: expected {repr expected}, got {repr actual}"

/-- Test the 5 semantic correspondences on one concrete (EventMemory, EventCorrectionMemory) test case. -/
private def runCase
    (caseName : String)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (probedIds : List String) : IO Unit := do
  let index := buildCorrectionFrontierIndex events corrections

  -- 1. indexed target membership == 現行 targetsEvent
  for id in probedIds do
    let eid : EventId := ⟨id⟩
    let indexed := index.targetsEvent eid
    let legacy := targetsEvent corrections.corrections eid
    assertEq s!"{caseName}: targetsEvent({id})" indexed legacy

  -- 2. indexed replacement lookup == 現行 replacementOf?
  for id in probedIds do
    let eid : EventId := ⟨id⟩
    let indexed := index.replacementOf? eid
    let legacy := replacementOf? corrections.corrections eid
    assertEq s!"{caseName}: replacementOf?({id})" indexed legacy

  -- 3. indexed event lookup == 現行 EventMemory.findById?
  for id in probedIds do
    let eid : EventId := ⟨id⟩
    let indexed := (index.findEventById? eid).map Event.id
    let legacy := (EventMemory.findById? events eid).map Event.id
    assertEq s!"{caseName}: findEventById?({id})" indexed legacy

  -- 4. indexed reference closure == 現行 correctionReferencesClosed
  let indexedClosed := index.referencesClosed
  let legacyClosed := correctionReferencesClosed events corrections
  assertEq s!"{caseName}: referencesClosed" indexedClosed legacyClosed

  -- 5. indexed cycle / endpoint / admissibility == 現行 correctionFrontierAdmissible
  let indexedUnique := index.endpointUnique
  let legacyUnique := ReplacementFrontier.endpointUnique (correctionEdges corrections)
  assertEq s!"{caseName}: endpointUnique" indexedUnique legacyUnique

  let indexedAdmissible := index.admissible
  let legacyAdmissible := correctionFrontierAdmissible events corrections
  assertEq s!"{caseName}: admissible" indexedAdmissible legacyAdmissible

  -- 6. Frontier events correspondence
  let indexedFrontier := index.frontierEvents events
  let legacyFrontier := frontierEvents events corrections
  assertEq s!"{caseName}: frontierEvents" (indexedFrontier.map Event.id) (legacyFrontier.map Event.id)

  -- 7. Full correctionFrontierMemoryIndexed? == correctionFrontierMemory?
  let indexedMem := (correctionFrontierMemoryIndexed? events corrections index).map (fun m => m.events.map Event.id)
  let legacyMem := (correctionFrontierMemory? events corrections).map (fun m => m.events.map Event.id)
  assertEq s!"{caseName}: correctionFrontierMemory?" indexedMem legacyMem

  -- 8. Root terminal events correspondence
  let indexedRoots := (correctionRootTerminalEventsIndexed? events corrections index).map (fun l => l.map fun (rid, ev) => (rid, ev.id))
  let legacyRoots := (correctionRootTerminalEvents? events corrections).map (fun l => l.map fun (rid, ev) => (rid, ev.id))
  assertEq s!"{caseName}: correctionRootTerminalEvents?" indexedRoots legacyRoots

def runAll : IO Unit := do
  IO.println "Running Phase 3H-1 CorrectionFrontier semantic correspondence tests..."

  let baseEvents := mkEvents ["e0", "e1", "e2", "e3", "e4", "e5"]
  let probeIds := ["e0", "e1", "e2", "e3", "e4", "e5", "e99", "random"]

  -- Case 1: Empty corrections
  let c1 := mkCorrections []
  runCase "Case 1 (Empty)" baseEvents c1 probeIds

  -- Case 2: Singleton valid correction
  let c2 := mkCorrections [("e0", "e1")]
  runCase "Case 2 (Singleton)" baseEvents c2 probeIds

  -- Case 3: 4-hop linear chain (e0 -> e1 -> e2 -> e3 -> e4)
  let c3 := mkCorrections [("e0", "e1"), ("e1", "e2"), ("e2", "e3"), ("e3", "e4")]
  runCase "Case 3 (Linear chain)" baseEvents c3 probeIds

  -- Case 4: Disjoint pairs (e0 -> e1, e2 -> e3, e4 -> e5)
  let c4 := mkCorrections [("e0", "e1"), ("e2", "e3"), ("e4", "e5")]
  runCase "Case 4 (Disjoint pairs)" baseEvents c4 probeIds

  -- Case 5: Branching / duplicate target (e0 -> e1, e0 -> e2) [Malformed]
  let c5 := mkCorrections [("e0", "e1"), ("e0", "e2")]
  runCase "Case 5 (Branching duplicate target)" baseEvents c5 probeIds

  -- Case 6: Merging / duplicate replacement (e0 -> e2, e1 -> e2) [Malformed]
  let c6 := mkCorrections [("e0", "e2"), ("e1", "e2")]
  runCase "Case 6 (Merging duplicate replacement)" baseEvents c6 probeIds

  -- Case 7: Missing target endpoint (e99 -> e1) [Malformed]
  let c7 := mkCorrections [("e99", "e1")]
  runCase "Case 7 (Missing target)" baseEvents c7 probeIds

  -- Case 8: Missing replacement endpoint (e0 -> e99) [Malformed]
  let c8 := mkCorrections [("e0", "e99")]
  runCase "Case 8 (Missing replacement)" baseEvents c8 probeIds

  -- Case 9: Self-loop cycle (e0 -> e0) [Malformed]
  let c9 := mkCorrections [("e0", "e0")]
  runCase "Case 9 (Self loop)" baseEvents c9 probeIds

  -- Case 10: 2-cycle (e0 -> e1, e1 -> e0) [Malformed]
  let c10 := mkCorrections [("e0", "e1"), ("e1", "e0")]
  runCase "Case 10 (2-cycle)" baseEvents c10 probeIds

  -- Case 11: 3-cycle (e0 -> e1, e1 -> e2, e2 -> e0) [Malformed]
  let c11 := mkCorrections [("e0", "e1"), ("e1", "e2"), ("e2", "e0")]
  runCase "Case 11 (3-cycle)" baseEvents c11 probeIds

  -- Case 12: Cycle disjoint with valid chain (e0 -> e1, e2 -> e3, e4 -> e4) [Malformed]
  let c12 := mkCorrections [("e0", "e1"), ("e2", "e3"), ("e4", "e4")]
  runCase "Case 12 (Disjoint cycle with chain)" baseEvents c12 probeIds

  IO.println "All 12 semantic correspondence test cases passed successfully!"

end Loam.Tests.CorrectionFrontierSemanticTest

def main : IO Unit :=
  Loam.Tests.CorrectionFrontierSemanticTest.runAll
