import Loam.ScheduledRoutingPublisher
import Loam.Persistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def movement? (amount1 amount2 : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-(amount1 + amount2)) }
    , { coordinate := ⟨"groceries"⟩, quantity := Quantity.ofQuanta amount1 }
    , { coordinate := ⟨"coffee"⟩, quantity := Quantity.ofQuanta amount2 }
    ]

private def occurrence (id day : String) (amount1 amount2 : Int) : IO (ScheduledOccurrence String) := do
  let some m := movement? amount1 amount2 | throw (IO.userError "movement")
  return { id := ⟨id⟩, scheduledOn := day, movement := m }

private def lifecycleFromOccurrences
    (occurrences : List (ScheduledOccurrence String)) : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? occurrences | throw (IO.userError "scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? [] | throw (IO.userError "terminals")
  return { scheduled, terminals }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let scheduledFile := dataDir / "scheduled.loam"
  let routingFile := dataDir / "scheduled-routing.loam"

  let s1 ← occurrence "scheduled-1" "2026-09-15" 500 200
  let lifecycle0 ← lifecycleFromOccurrences [s1]
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle0)
    "save Scheduled lifecycle fixture"
  IO.FS.writeFile routingFile "LOAM-SCHEDULED-ROUTING\t1\n"

  let subjGroceries : ScheduledRoutingSubject := { scheduled := ⟨"scheduled-1"⟩, locus := ⟨"groceries"⟩ }
  let subjCoffee : ScheduledRoutingSubject := { scheduled := ⟨"scheduled-1"⟩, locus := ⟨"coffee"⟩ }

  let resManaged ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-09-06", target := .managed ⟨"food"⟩ }
  match resManaged with
  | .ok receipt =>
      expect (receipt.subject == subjGroceries) "managed receipt subject mismatch"
      expect (receipt.effectiveOn == "2026-09-06") "managed receipt date mismatch"
      expect (receipt.target == .managed ⟨"food"⟩) "managed receipt target mismatch"
  | .error err => throw (IO.userError s!"managed publish failed: {err}")

  let afterManaged ← IO.FS.readFile routingFile
  expect (afterManaged.contains "ROUTE\tscheduled-1\tgroceries\tFROM\t2026-09-06\tMANAGED\tfood")
    "managed route not found in routing authority"

  let resUnmanaged ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subjCoffee, effectiveOn := "2026-09-06", target := .unmanaged }
  match resUnmanaged with
  | .ok receipt =>
      expect (receipt.subject == subjCoffee) "unmanaged receipt subject mismatch"
      expect (receipt.effectiveOn == "2026-09-06") "unmanaged receipt date mismatch"
      expect (receipt.target == .unmanaged) "unmanaged receipt target mismatch"
  | .error err => throw (IO.userError s!"unmanaged publish failed: {err}")

  let afterUnmanaged ← IO.FS.readFile routingFile
  expect (afterUnmanaged.contains "ROUTE\tscheduled-1\tcoffee\tFROM\t2026-09-06\tUNMANAGED")
    "unmanaged route not found in routing authority"

  let snapshotBeforeInvalid ← IO.FS.readFile routingFile
  let resInvalidDate ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-02-29", target := .managed ⟨"food"⟩ }
  expect (!resInvalidDate.isOk) "invalid date admitted"
  expect ((← IO.FS.readFile routingFile) == snapshotBeforeInvalid) "routing authority modified on invalid date"

  let resInvalidPurpose ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-09-07", target := .managed ⟨""⟩ }
  expect (!resInvalidPurpose.isOk) "empty purpose token admitted"
  expect ((← IO.FS.readFile routingFile) == snapshotBeforeInvalid) "routing authority modified on invalid purpose"

  let resMissingId ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := { scheduled := ⟨"unknown-scheduled"⟩, locus := ⟨"groceries"⟩ },
      effectiveOn := "2026-09-07", target := .managed ⟨"food"⟩ }
  match resMissingId with
  | .error "loam: scheduled identity not found" => pure ()
  | other => throw (IO.userError s!"expected scheduled identity not found, got {repr other}")

  let resAbsentLocus ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := { scheduled := ⟨"scheduled-1"⟩, locus := ⟨"absent-locus"⟩ },
      effectiveOn := "2026-09-07", target := .managed ⟨"food"⟩ }
  match resAbsentLocus with
  | .error "loam: Scheduled occurrence does not contain that Locus" => pure ()
  | other => throw (IO.userError s!"expected occurrence does not contain Locus, got {repr other}")

  let resMissingRouting ← Loam.ScheduledRoutingPublisher.publish
    (dataDir / "nonexistent-routing.loam").toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-09-07", target := .managed ⟨"food"⟩ }
  match resMissingRouting with
  | .error "loam: Scheduled routing authority is missing" => pure ()
  | other => throw (IO.userError s!"expected routing missing, got {repr other}")

  let malformedRouting := dataDir / "malformed-routing.loam"
  IO.FS.writeFile malformedRouting "NOT-ROUTING\tGARBAGE\n"
  let resMalformedRouting ← Loam.ScheduledRoutingPublisher.publish
    malformedRouting.toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-09-07", target := .managed ⟨"food"⟩ }
  match resMalformedRouting with
  | .error "loam: malformed or unsupported Scheduled routing authority" => pure ()
  | other => throw (IO.userError s!"expected malformed routing, got {repr other}")

  let malformedScheduled := dataDir / "malformed-scheduled.loam"
  IO.FS.writeFile malformedScheduled "GARBAGE\n"
  let resMalformedScheduled ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString malformedScheduled.toString
    { subject := subjGroceries, effectiveOn := "2026-09-07", target := .managed ⟨"food"⟩ }
  match resMalformedScheduled with
  | .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported" => pure ()
  | other => throw (IO.userError s!"expected malformed lifecycle, got {repr other}")

  let resDuplicate ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subjGroceries, effectiveOn := "2026-09-06", target := .managed ⟨"household"⟩ }
  match resDuplicate with
  | .error "loam: Scheduled routing already has evidence at this subject/effective coordinate" => pure ()
  | other => throw (IO.userError s!"expected duplicate refusal, got {repr other}")

  let .ok _ ← Loam.ScheduledRoutingPublisher.publish
      routingFile.toString scheduledFile.toString
      { subject := subjGroceries, effectiveOn := "2026-09-10", target := .managed ⟨"special"⟩ }
    | throw (IO.userError "publish later route")

  let some loadedHistory ← Loam.Persistence.loadScheduledRoutingHistory? routingFile
    | throw (IO.userError "failed to reload routing history")
  expect (loadedHistory.statusAt subjGroceries "2026-09-10" == .managed ⟨"special"⟩)
    "history did not select new route at effectiveOn"
  expect (loadedHistory.statusAt subjGroceries "2026-09-11" == .managed ⟨"special"⟩)
    "history did not select new route after effectiveOn"
  expect (loadedHistory.statusAt subjGroceries "2026-09-08" == .managed ⟨"food"⟩)
    "earlier query did not retain original route"
  expect (loadedHistory.statusAt subjGroceries "2026-09-05" == .unrouted)
    "pre-effective query did not retain unrouted"

  let cliManaged ← IO.Process.output {
    cmd := ".lake/build/bin/loamScheduledRouting"
    args := #[routingFile.toString, scheduledFile.toString, "2026-09-12", "scheduled-1", "groceries", "managed", "cli-food"]
  }
  expect (cliManaged.exitCode == 0) s!"CLI managed route failed with code {cliManaged.exitCode}: {cliManaged.stderr}"
  expect (cliManaged.stdout.contains "Recorded Scheduled route: scheduled-1 / groceries @ 2026-09-12 = managed -> cli-food.")
    "CLI managed stdout mismatch"

  let cliUnmanaged ← IO.Process.output {
    cmd := ".lake/build/bin/loamScheduledRouting"
    args := #[routingFile.toString, scheduledFile.toString, "2026-09-12", "scheduled-1", "coffee", "unmanaged"]
  }
  expect (cliUnmanaged.exitCode == 0) s!"CLI unmanaged route failed with code {cliUnmanaged.exitCode}: {cliUnmanaged.stderr}"
  expect (cliUnmanaged.stdout.contains "Recorded Scheduled route: scheduled-1 / coffee @ 2026-09-12 = unmanaged.")
    "CLI unmanaged stdout mismatch"

  let s2 ← occurrence "scheduled-2" "2026-09-20" 800 100
  let lifecycleUpdated ← lifecycleFromOccurrences [s1, s2]
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycleUpdated)
    "save updated Scheduled lifecycle"

  let subj2 : ScheduledRoutingSubject := { scheduled := ⟨"scheduled-2"⟩, locus := ⟨"groceries"⟩ }
  let resReread ← Loam.ScheduledRoutingPublisher.publish
    routingFile.toString scheduledFile.toString
    { subject := subj2, effectiveOn := "2026-09-15", target := .managed ⟨"groceries-purpose"⟩ }
  expect (resReread.isOk) "publisher failed to re-read updated Scheduled lifecycle"

  IO.println "Scheduled routing publisher tests passed."
