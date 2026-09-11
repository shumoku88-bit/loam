import Loam.ActualDate
import Loam.Core.ScheduledRouting
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.ScheduledContinuationRouting
import Loam.ScheduledCreationPublisher
import Loam.ScheduledRoutingPublisher

open Loam.Core
open Loam.Persistence
open Loam.ScheduledContinuationRouting

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some v => pure v
  | none => throw (IO.userError message)

private def movement?
    (changes : List (MovementChange LocusId)) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩ changes

private def occurrence
    (id day : String)
    (changes : List (MovementChange LocusId)) : IO (ScheduledOccurrence String) := do
  let some m := movement? changes | throw (IO.userError s!"invalid movement for {id}")
  return { id := ⟨id⟩, scheduledOn := day, movement := m }

private def lifecycleFromOccurrences
    (occurrences : List (ScheduledOccurrence String)) : IO ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? occurrences
    | throw (IO.userError "scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "terminals")
  return { scheduled, terminals }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let scheduledFile := dataDir / "scheduled.loam"
  let routingFile := dataDir / "scheduled-routing.loam"

  -- Setup occurrences
  -- 1. Pred & New for managed routing
  let pred1 ← occurrence "sched-pred1" "2026-09-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := ⟨"wifi"⟩, quantity := Quantity.ofQuanta 1000 }
    ]
  let new1 ← occurrence "sched-new1" "2026-10-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := ⟨"wifi"⟩, quantity := Quantity.ofQuanta 1000 }
    ]

  -- 2. Pred & New for unmanaged routing
  let pred2 ← occurrence "sched-pred2" "2026-09-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-500) }
    , { coordinate := ⟨"coffee"⟩, quantity := Quantity.ofQuanta 500 }
    ]
  let new2 ← occurrence "sched-new2" "2026-10-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-500) }
    , { coordinate := ⟨"coffee"⟩, quantity := Quantity.ofQuanta 500 }
    ]

  -- 3. Pred & New for unrouted (no prior routing assertions)
  let pred3 ← occurrence "sched-pred3" "2026-09-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-200) }
    , { coordinate := ⟨"snack"⟩, quantity := Quantity.ofQuanta 200 }
    ]
  let new3 ← occurrence "sched-new3" "2026-10-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-200) }
    , { coordinate := ⟨"snack"⟩, quantity := Quantity.ofQuanta 200 }
    ]

  -- 4. Pred & New for partial failure / multiple routes
  let pred4 ← occurrence "sched-pred4" "2026-09-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-1500) }
    , { coordinate := ⟨"multi-a"⟩, quantity := Quantity.ofQuanta 1000 }
    , { coordinate := ⟨"multi-b"⟩, quantity := Quantity.ofQuanta 500 }
    ]
  let new4 ← occurrence "sched-new4" "2026-10-01"
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-1500) }
    , { coordinate := ⟨"multi-a"⟩, quantity := Quantity.ofQuanta 1000 }
    , { coordinate := ⟨"multi-b"⟩, quantity := Quantity.ofQuanta 500 }
    ]

  let lifecycle ← lifecycleFromOccurrences [pred1, new1, pred2, new2, pred3, new3, pred4, new4]
  expect (← saveScheduledLifecycleImage? scheduledFile lifecycle)
    "save scheduled lifecycle"

  -- Initial routing history containing predecessor assertions
  IO.FS.writeFile routingFile
    ("LOAM-SCHEDULED-ROUTING\t1\n" ++
     "ROUTE\tsched-pred1\twifi\tFROM\t2026-09-01\tMANAGED\ttelecom\n" ++
     "ROUTE\tsched-pred2\tcoffee\tFROM\t2026-09-01\tUNMANAGED\n" ++
     "ROUTE\tsched-pred4\tmulti-a\tFROM\t2026-09-01\tMANAGED\ttelecom\n" ++
     "ROUTE\tsched-pred4\tmulti-b\tFROM\t2026-09-01\tMANAGED\tutilities\n")

  -- -------------------------------------------------------------
  -- Qualification 1: Predecessor managed -> inherits managed
  -- -------------------------------------------------------------
  let res1 ← inherit routingFile scheduledFile ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  let .ok rep1 := res1 | throw (IO.userError s!"Q1 failed: {repr res1}")
  expect (rep1.outcomes == [.inherited ⟨"wifi"⟩ (.managed ⟨"telecom"⟩)])
    "Q1: outcome must be inherited managed telecom"
  expect (rep1.formatOutcomes == ["inherited route: wifi -> managed telecom"])
    "Q1: formatOutcomes must match expected message"

  -- Verify persistence on disk
  let some h1 ← loadScheduledRoutingHistory? routingFile
    | throw (IO.userError "Q1: load routing history")
  let status1 := h1.statusAt { scheduled := ⟨"sched-new1"⟩, locus := ⟨"wifi"⟩ } "2026-09-10"
  expect (status1 == .managed ⟨"telecom"⟩) "Q1: persisted routing status must be managed telecom"

  -- -------------------------------------------------------------
  -- Qualification 2: Predecessor unmanaged -> inherits unmanaged
  -- -------------------------------------------------------------
  let res2 ← inherit routingFile scheduledFile ⟨"sched-pred2"⟩ ⟨"sched-new2"⟩ "2026-09-10"
  let .ok rep2 := res2 | throw (IO.userError s!"Q2 failed: {repr res2}")
  expect (rep2.outcomes == [.inherited ⟨"coffee"⟩ .unmanaged])
    "Q2: outcome must be inherited unmanaged"
  expect (rep2.formatOutcomes == ["inherited route: coffee -> unmanaged"])
    "Q2: formatOutcomes must match expected message"

  -- Verify persistence on disk
  let some h2 ← loadScheduledRoutingHistory? routingFile
    | throw (IO.userError "Q2: load routing history")
  let status2 := h2.statusAt { scheduled := ⟨"sched-new2"⟩, locus := ⟨"coffee"⟩ } "2026-09-10"
  expect (status2 == .unmanaged) "Q2: persisted routing status must be unmanaged"

  -- -------------------------------------------------------------
  -- Qualification 3: Predecessor unrouted -> no new assertion
  -- -------------------------------------------------------------
  let hBefore ← requireSome (← loadScheduledRoutingHistory? routingFile) "load history before Q3"
  let entriesCountBefore := hBefore.entries.length
  let res3 ← inherit routingFile scheduledFile ⟨"sched-pred3"⟩ ⟨"sched-new3"⟩ "2026-09-10"
  let .ok rep3 := res3 | throw (IO.userError s!"Q3 failed: {repr res3}")
  expect rep3.outcomes.isEmpty "Q3: outcome must be empty for unrouted predecessor"
  let hAfter ← requireSome (← loadScheduledRoutingHistory? routingFile) "load history after Q3"
  let entriesCountAfter := hAfter.entries.length
  expect (entriesCountBefore == entriesCountAfter) "Q3: no routing assertions must be written"

  -- -------------------------------------------------------------
  -- Qualification 4: Missing / malformed routing authority fails closed
  -- -------------------------------------------------------------
  let missingRoutingPath := dataDir / "missing-routing.loam"
  let res4a ← inherit missingRoutingPath scheduledFile ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  match res4a with
  | .error msg => expect (msg == "loam: Scheduled routing authority is missing") "Q4a: missing routing message"
  | .ok _ => throw (IO.userError "Q4a: missing routing authority must not succeed")

  let malformedRoutingPath := dataDir / "malformed-routing.loam"
  IO.FS.writeFile malformedRoutingPath "BAD-HEADER\t999\nGARBAGE\n"
  let res4b ← inherit malformedRoutingPath scheduledFile ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  match res4b with
  | .error msg => expect (msg == "loam: malformed or unsupported Scheduled routing authority") "Q4b: malformed routing message"
  | .ok _ => throw (IO.userError "Q4b: malformed routing authority must not succeed")

  -- -------------------------------------------------------------
  -- Qualification 5: Missing / malformed Scheduled authority fails closed
  -- -------------------------------------------------------------
  let missingScheduledPath := dataDir / "missing-scheduled.loam"
  let res5a ← inherit routingFile missingScheduledPath ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  match res5a with
  | .error msg => expect (msg == "loam: Scheduled lifecycle authority is missing") "Q5a: missing scheduled message"
  | .ok _ => throw (IO.userError "Q5a: missing scheduled authority must not succeed")

  let malformedScheduledPath := dataDir / "malformed-scheduled.loam"
  IO.FS.writeFile malformedScheduledPath "BAD-LIFECYCLE-HEADER\t999\n"
  let res5b ← inherit routingFile malformedScheduledPath ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  match res5b with
  | .error msg => expect (msg == "loam: Scheduled lifecycle authority is missing, malformed, or unsupported") "Q5b: malformed scheduled message"
  | .ok _ => throw (IO.userError "Q5b: malformed scheduled authority must not succeed")

  let res5c ← inherit routingFile scheduledFile ⟨"sched-pred1"⟩ ⟨"unknown-scheduled"⟩ "2026-09-10"
  match res5c with
  | .error msg => expect (msg == "loam: created Scheduled occurrence 'unknown-scheduled' not found") "Q5c: created not found message"
  | .ok _ => throw (IO.userError "Q5c: unknown created scheduled must not succeed")

  let res5e ← inherit routingFile scheduledFile ⟨"unknown-predecessor"⟩ ⟨"sched-new1"⟩ "2026-09-10"
  match res5e with
  | .error msg => expect (msg == "loam: predecessor Scheduled occurrence 'unknown-predecessor' not found") "Q5e: predecessor not found message"
  | .ok _ => throw (IO.userError "Q5e: unknown predecessor must not succeed")

  let res5d ← inherit routingFile scheduledFile ⟨"sched-pred1"⟩ ⟨"sched-new1"⟩ "2026-02-29"
  match res5d with
  | .error msg => expect (msg.contains "real calendar date") "Q5d: invalid date rejected"
  | .ok _ => throw (IO.userError "Q5d: invalid date must not succeed")

  -- Distinction: unknown predecessor (outer error) vs existing unrouted predecessor (ok empty)
  let resUnknownPred ← inherit routingFile scheduledFile ⟨"ghost-pred"⟩ ⟨"sched-new3"⟩ "2026-09-10"
  let resExistingUnrouted ← inherit routingFile scheduledFile ⟨"sched-pred3"⟩ ⟨"sched-new3"⟩ "2026-09-10"
  expect (!resUnknownPred.isOk) "unknown predecessor must fail with outer error"
  expect (resExistingUnrouted.isOk) "existing unrouted predecessor must return ok"
  expect (resUnknownPred.isOk != resExistingUnrouted.isOk)
    "unknown predecessor and existing unrouted predecessor must be distinguished"

  -- -------------------------------------------------------------
  -- Qualification 6: Per-route publication refusal observable in Report
  -- -------------------------------------------------------------
  -- Pre-publish multi-a to cause a duplicate refusal on multi-a while multi-b succeeds
  let dupDraft : Loam.ScheduledRoutingPublisher.Draft := {
    subject := { scheduled := ⟨"sched-new4"⟩, locus := ⟨"multi-a"⟩ }
    effectiveOn := "2026-09-10"
    target := .managed ⟨"telecom"⟩
  }
  let .ok _ ← Loam.ScheduledRoutingPublisher.publish routingFile.toString scheduledFile.toString dupDraft
    | throw (IO.userError "pre-publishing dupDraft failed")

  let res6 ← inherit routingFile scheduledFile ⟨"sched-pred4"⟩ ⟨"sched-new4"⟩ "2026-09-10"
  let .ok rep6 := res6 | throw (IO.userError s!"Q6 failed: {repr res6}")
  expect (rep6.outcomes.length == 2) "Q6: expected 2 outcomes (1 refused, 1 inherited)"
  match rep6.outcomes with
  | [.refused locus1 msg1, .inherited locus2 target2] =>
      expect (locus1 == ⟨"multi-a"⟩) "Q6: multi-a was refused"
      expect (msg1.contains "already has evidence") "Q6: duplicate error message recorded"
      expect (locus2 == ⟨"multi-b"⟩) "Q6: multi-b was inherited"
      expect (target2 == .managed ⟨"utilities"⟩) "Q6: multi-b target matched"
  | other => throw (IO.userError s!"Q6: unexpected outcomes: {repr other}")

  -- -------------------------------------------------------------
  -- Qualification 7: Shared module does not import Loam.Tui
  -- -------------------------------------------------------------
  let moduleSource ← IO.FS.readFile "Loam/ScheduledContinuationRouting.lean"
  expect (!moduleSource.contains "Loam.Tui")
    "Q7: Loam.ScheduledContinuationRouting must not import Loam.Tui"

  -- -------------------------------------------------------------
  -- Qualification 8: Durable writes only through ScheduledRoutingPublisher
  -- -------------------------------------------------------------
  expect (!moduleSource.contains "saveScheduledRoutingHistory?")
    "Q8: Loam.ScheduledContinuationRouting must not directly call saveScheduledRoutingHistory?"
  expect (moduleSource.contains "Loam.ScheduledRoutingPublisher.publish")
    "Q8: Loam.ScheduledContinuationRouting must publish through ScheduledRoutingPublisher"

  -- -------------------------------------------------------------
  -- Helper: inheritFromReceipt
  -- -------------------------------------------------------------
  let receipt : Loam.ScheduledCreationPublisher.Receipt := {
    scheduled := ⟨"sched-new1"⟩
    scheduledOn := "2026-10-01"
    total := 1000
  }
  -- Calling with already published route should refuse, proving delegation works
  let resReceipt ← inheritFromReceipt routingFile scheduledFile ⟨"sched-pred1"⟩ receipt "2026-09-10"
  let .ok repReceipt := resReceipt | throw (IO.userError "inheritFromReceipt call")
  expect (repReceipt.outcomes.length == 1) "receipt call produced outcome"

  IO.println "Loam.ScheduledContinuationRouting qualification passed: managed, unmanaged, unrouted, missing/malformed fail-closed, per-route refusal report, and TUI-free shared boundary verified."
