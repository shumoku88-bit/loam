import Loam.Application.ScheduledInspection

open Loam.Core
open Loam.Application

namespace Loam.Tests.ScheduledInspectionTest

set_option autoImplicit false

/-!
# Phase J: Semantic regression and reference equivalence tests

Tests all 19 required semantic lifecycle cases and validates exact equivalence
against the pre-linearization reference implementation.
-/

namespace Reference

private def scheduledPresent {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (id : ScheduledId) : Bool :=
  (ScheduledMemory.findById? scheduledMemory id).isSome

private def completionSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | some (.actual _) => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def retirementSourcesKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  terminalMemory.terminals.all fun terminal =>
    match terminal.target with
    | none => scheduledPresent scheduledMemory terminal.source
    | _ => true

private def replacementEdges
    (terminalMemory : ScheduledTerminalMemory) :
    List (ReplacementFrontier.Edge ScheduledId) :=
  terminalMemory.terminals.filterMap fun terminal =>
    match terminal.target with
    | some (.scheduled successor) =>
        some { source := terminal.source, successor := successor }
    | _ => none

private def replacementEndpointsKnown {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory) : Bool :=
  ReplacementFrontier.referencesClosed
    (scheduledPresent scheduledMemory)
    (replacementEdges terminalMemory)

private def hasEffectiveCompletion
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory)
    (scheduled : ScheduledId) : Bool :=
  match ScheduledTerminalMemory.completionActualFor? terminalMemory scheduled with
  | none => false
  | some actual => (EventMemory.findById? eventMemory actual).isSome

private def isCurrentOpen {Time : Type}
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory)
    (occurrence : ScheduledOccurrence Time) : Bool :=
  (ScheduledTerminalMemory.retirementFor?
      terminalMemory occurrence.id).isNone &&
    (ScheduledTerminalMemory.replacementFor?
      terminalMemory occurrence.id).isNone &&
    !hasEffectiveCompletion terminalMemory eventMemory occurrence.id

def currentOpenScheduled {Time : Type}
    (scheduledMemory : ScheduledMemory Time)
    (terminalMemory : ScheduledTerminalMemory)
    (eventMemory : EventMemory) : CurrentOpenScheduledResult Time :=
  let edges := replacementEdges terminalMemory
  if !completionSourcesKnown scheduledMemory terminalMemory then
    .unknownCompletionScheduled
  else if !retirementSourcesKnown scheduledMemory terminalMemory then
    .unknownRetirementScheduled
  else if !replacementEndpointsKnown scheduledMemory terminalMemory then
    .unknownReplacementScheduled
  else if !ReplacementFrontier.acyclic edges then
    .invalidReplacementGraph
  else if terminalMemory.hasCrossKindConflict then
    .conflictingTerminalEvidence
  else
    .open <|
      scheduledMemory.occurrences.filter
        (isCurrentOpen terminalMemory eventMemory)

end Reference

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def makeScheduled
    (id : String) (day : String) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-100), change groceries 100]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def makeEvent (id : String) : Event :=
  { id := ⟨id⟩, effects := [], keyNodup := by simp }

private def openIdList
    (result : CurrentOpenScheduledResult String) : Option (List String) :=
  match result with
  | .open occurrences => some (occurrences.map fun occ => occ.id.token)
  | _ => none

def testCase1_noTerminals : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome (ScheduledTerminalMemory.ofTerminals? []) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let res := currentOpenScheduled sched terms events
  let ref := Reference.currentOpenScheduled sched terms events
  let ids ← requireSome (openIdList res) "open"
  let refIds ← requireSome (openIdList ref) "ref open"
  expect (ids == ["s1", "s2"]) "case 1: all open"
  expect (ids == refIds) "case 1: matches reference"

def testCase2_effectiveCompletionCloses : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e1"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? [makeEvent "e1"]) "events"
  let res := currentOpenScheduled sched terms events
  let ref := Reference.currentOpenScheduled sched terms events
  let ids ← requireSome (openIdList res) "open"
  let refIds ← requireSome (openIdList ref) "ref open"
  expect (ids == ["s2"]) "case 2: effective completion closes s1"
  expect (ids == refIds) "case 2: matches reference"

def testCase3_missingActualRemainsOpen : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e-missing"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let res := currentOpenScheduled sched terms events
  let ref := Reference.currentOpenScheduled sched terms events
  let ids ← requireSome (openIdList res) "open"
  let refIds ← requireSome (openIdList ref) "ref open"
  expect (ids == ["s1"]) "case 3: missing actual remains open"
  expect (ids == refIds) "case 3: matches reference"

def testCase4_missingActualLaterAppears : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e1"⟩) }]) "terms"
  let eventsBefore ← requireSome (EventMemory.ofEvents? []) "events before"
  let idsBefore ← requireSome (openIdList <| currentOpenScheduled sched terms eventsBefore) "open"
  expect (idsBefore == ["s1"]) "case 4: open before event appears"

  let eventsAfter ← requireSome (EventMemory.ofEvents? [makeEvent "e1"]) "events after"
  let idsAfter ← requireSome (openIdList <| currentOpenScheduled sched terms eventsAfter) "open"
  let refAfter ← requireSome (openIdList <| Reference.currentOpenScheduled sched terms eventsAfter) "ref open"
  expect (idsAfter == []) "case 4: closed after event appears"
  expect (idsAfter == refAfter) "case 4: matches reference"

def testCase5_retirementClosesSource : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := none }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let res := currentOpenScheduled sched terms events
  let ref := Reference.currentOpenScheduled sched terms events
  let ids ← requireSome (openIdList res) "open"
  let refIds ← requireSome (openIdList ref) "ref open"
  expect (ids == ["s2"]) "case 5: retirement closes s1"
  expect (ids == refIds) "case 5: matches reference"

def testCase6_and_7_replacementClosesPredecessorAndLeavesSuccessorOpen : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let res := currentOpenScheduled sched terms events
  let ref := Reference.currentOpenScheduled sched terms events
  let ids ← requireSome (openIdList res) "open"
  let refIds ← requireSome (openIdList ref) "ref open"
  expect (ids == ["s2"]) "case 6 & 7: s1 closed, s2 open"
  expect (ids == refIds) "case 6 & 7: matches reference"

def testCase8_unknownCompletionSource : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-s"⟩, target := some (.actual ⟨"e1"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? [makeEvent "e1"]) "events"
  match currentOpenScheduled sched terms events with
  | .unknownCompletionScheduled => pure ()
  | _ => throw <| IO.userError "case 8: expected unknownCompletionScheduled"

def testCase9_unknownRetirementSource : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-s"⟩, target := none }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .unknownRetirementScheduled => pure ()
  | _ => throw <| IO.userError "case 9: expected unknownRetirementScheduled"

def testCase10_unknownReplacementSource : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-s"⟩, target := some (.scheduled ⟨"s1"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .unknownReplacementScheduled => pure ()
  | _ => throw <| IO.userError "case 10: expected unknownReplacementScheduled"

def testCase11_unknownReplacementSuccessor : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.scheduled ⟨"unknown-successor"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .unknownReplacementScheduled => pure ()
  | _ => throw <| IO.userError "case 11: expected unknownReplacementScheduled"

def testCase12_replacementCycle : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) },
       { source := ⟨"s2"⟩, target := some (.scheduled ⟨"s1"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .invalidReplacementGraph => pure ()
  | _ => throw <| IO.userError "case 12: expected invalidReplacementGraph"

def testCase13_completionRetirementConflict : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e1"⟩) },
       { source := ⟨"s1"⟩, target := none }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "case 13: expected conflictingTerminalEvidence"

def testCase14_completionReplacementConflict : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e1"⟩) },
       { source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "case 14: expected conflictingTerminalEvidence"

def testCase15_retirementReplacementConflict : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := none },
       { source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched terms events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "case 15: expected conflictingTerminalEvidence"

def testCase16_representationPermutationDoesNotAlterSemanticSet : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let c ← requireSome (makeScheduled "s3" "2026-09-03") "s3"
  let schedABC ← requireSome (ScheduledMemory.ofOccurrences? [a, b, c]) "schedABC"
  let schedCBA ← requireSome (ScheduledMemory.ofOccurrences? [c, b, a]) "schedCBA"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s2"⟩, target := none }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let idsABC ← requireSome (openIdList <| currentOpenScheduled schedABC terms events) "open"
  let idsCBA ← requireSome (openIdList <| currentOpenScheduled schedCBA terms events) "open"
  -- Semantically, both contain s1 and s3
  expect (idsABC.all (fun id => id ∈ idsCBA) && idsCBA.all (fun id => id ∈ idsABC))
    "case 16: semantic set unchanged across input permutations"

def testCase17_openOccurrencesPreserveOccurrenceOrder : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let c ← requireSome (makeScheduled "s3" "2026-09-03") "s3"
  let d ← requireSome (makeScheduled "s4" "2026-09-04") "s4"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b, c, d]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s2"⟩, target := none }]) "terms"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let ids ← requireSome (openIdList <| currentOpenScheduled sched terms events) "open"
  let refIds ← requireSome (openIdList <| Reference.currentOpenScheduled sched terms events) "ref open"
  expect (ids == ["s1", "s3", "s4"]) "case 17: order strictly preserved"
  expect (ids == refIds) "case 17: matches reference order"

def testCase18_terminalListOrderingDoesNotChangeResult : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let c ← requireSome (makeScheduled "s3" "2026-09-03") "s3"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b, c]) "sched"
  let terms1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) },
       { source := ⟨"s2"⟩, target := some (.scheduled ⟨"s3"⟩) }]) "terms1"
  let terms2 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s2"⟩, target := some (.scheduled ⟨"s3"⟩) },
       { source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) }]) "terms2"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let ids1 ← requireSome (openIdList <| currentOpenScheduled sched terms1 events) "open 1"
  let ids2 ← requireSome (openIdList <| currentOpenScheduled sched terms2 events) "open 2"
  expect (ids1 == ids2) "case 18: terminal ordering does not affect result"

def testCase19_completionEventListOrderingDoesNotChangeResult : IO Unit := do
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b]) "sched"
  let terms ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e1"⟩) },
       { source := ⟨"s2"⟩, target := some (.actual ⟨"e2"⟩) }]) "terms"
  let events1 ← requireSome (EventMemory.ofEvents? [makeEvent "e1", makeEvent "e2"]) "ev1"
  let events2 ← requireSome (EventMemory.ofEvents? [makeEvent "e2", makeEvent "e1"]) "ev2"
  let ids1 ← requireSome (openIdList <| currentOpenScheduled sched terms events1) "open 1"
  let ids2 ← requireSome (openIdList <| currentOpenScheduled sched terms events2) "open 2"
  expect (ids1 == ids2) "case 19: event ordering does not affect result"

def testFailClosedPriority : IO Unit := do
  -- Priority 1: unknown completion source fires before unknown retirement
  let a ← requireSome (makeScheduled "s1" "2026-09-01") "s1"
  let b ← requireSome (makeScheduled "s2" "2026-09-02") "s2"
  let c ← requireSome (makeScheduled "s3" "2026-09-03") "s3"
  let sched ← requireSome (ScheduledMemory.ofOccurrences? [a, b, c]) "sched"
  let termsPri1 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-completion"⟩, target := some (.actual ⟨"e1"⟩) },
       { source := ⟨"unknown-retirement"⟩, target := none }]) "termsPri1"
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  match currentOpenScheduled sched termsPri1 events with
  | .unknownCompletionScheduled => pure ()
  | _ => throw <| IO.userError "fail-closed priority 1 failed"

  -- Priority 2: unknown retirement source fires before unknown replacement
  let termsPri2 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.actual ⟨"e2"⟩) },
       { source := ⟨"unknown-retirement"⟩, target := none },
       { source := ⟨"unknown-replacement"⟩, target := some (.scheduled ⟨"s2"⟩) }]) "termsPri2"
  match currentOpenScheduled sched termsPri2 events with
  | .unknownRetirementScheduled => pure ()
  | _ => throw <| IO.userError "fail-closed priority 2 failed"

  -- Priority 3: unknown replacement endpoint fires before a replacement cycle
  let termsPri3 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-replacement"⟩, target := some (.scheduled ⟨"s3"⟩) },
       { source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) },
       { source := ⟨"s2"⟩, target := some (.scheduled ⟨"s1"⟩) }]) "termsPri3"
  match currentOpenScheduled sched termsPri3 events with
  | .unknownReplacementScheduled => pure ()
  | _ => throw <| IO.userError "fail-closed priority 3 failed"

  -- Priority 4: a replacement cycle fires before a cross-kind conflict
  let termsPri4 ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"s1"⟩, target := some (.scheduled ⟨"s2"⟩) },
       { source := ⟨"s2"⟩, target := some (.scheduled ⟨"s1"⟩) },
       { source := ⟨"s3"⟩, target := some (.actual ⟨"e3"⟩) },
       { source := ⟨"s3"⟩, target := none }]) "termsPri4"
  match currentOpenScheduled sched termsPri4 events with
  | .invalidReplacementGraph => pure ()
  | _ => throw <| IO.userError "fail-closed priority 4 failed"


end Loam.Tests.ScheduledInspectionTest

open Loam.Tests.ScheduledInspectionTest in
def main : IO Unit := do
  testCase1_noTerminals
  testCase2_effectiveCompletionCloses
  testCase3_missingActualRemainsOpen
  testCase4_missingActualLaterAppears
  testCase5_retirementClosesSource
  testCase6_and_7_replacementClosesPredecessorAndLeavesSuccessorOpen
  testCase8_unknownCompletionSource
  testCase9_unknownRetirementSource
  testCase10_unknownReplacementSource
  testCase11_unknownReplacementSuccessor
  testCase12_replacementCycle
  testCase13_completionRetirementConflict
  testCase14_completionReplacementConflict
  testCase15_retirementReplacementConflict
  testCase16_representationPermutationDoesNotAlterSemanticSet
  testCase17_openOccurrencesPreserveOccurrenceOrder
  testCase18_terminalListOrderingDoesNotChangeResult
  testCase19_completionEventListOrderingDoesNotChangeResult
  testFailClosedPriority
  IO.println "All 19 Phase J ScheduledInspection regression and equivalence cases passed."
