import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.Persistence.NormalizedActualPersistence
import Loam.WriterOwnership

namespace Loam.Tests.ActualAuthorityCrashTest

open Loam.Core

set_option autoImplicit false

private def makeEffect (locus : String) (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def makeEvent? (id : String) (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def requireSome {α : Type} (msg : String) (opt : Option α) : IO α :=
  match opt with
  | some val => pure val
  | none => throw <| IO.userError msg

private def buildEvidence1 : IO ActualEvidence := do
  let ev1 ← requireSome "ev1" (makeEvent? "rec-1" [makeEffect "food" 1000, makeEffect "wallet" (-1000)])
  let events ← requireSome "events1" (EventMemory.ofEvents? [ev1])
  let validity ← requireSome "validity1" (ActualValidityHistory.ofParts? [.base ⟨"rec-1"⟩ "2026-09-01"] [])
  let descriptions ← requireSome "desc1" (EventDescriptionMemory.ofEntries? [{ event := ⟨"rec-1"⟩, text := "Grocery" }])
  let merchants ← requireSome "merchants1" (EventMerchantEvidenceMemory.ofEntriesAgainst? events [
    { event := ⟨"rec-1"⟩, disposition := .merchant ⟨"grocery-shop"⟩ }
  ])
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
    descriptions := descriptions
    merchants := merchants
  }

private def buildEvidence2 : IO ActualEvidence := do
  let ev1 ← requireSome "ev1" (makeEvent? "rec-1" [makeEffect "food" 1000, makeEffect "wallet" (-1000)])
  let ev2 ← requireSome "ev2" (makeEvent? "rec-2" [makeEffect "books" 2000, makeEffect "wallet" (-2000)])
  let events ← requireSome "events2" (EventMemory.ofEvents? [ev1, ev2])
  let validity ← requireSome "validity2" (ActualValidityHistory.ofParts? [
    .base ⟨"rec-1"⟩ "2026-09-01",
    .base ⟨"rec-2"⟩ "2026-09-02"
  ] [])
  let descriptions ← requireSome "desc2" (EventDescriptionMemory.ofEntries? [
    { event := ⟨"rec-1"⟩, text := "Grocery" },
    { event := ⟨"rec-2"⟩, text := "Book" }
  ])
  let merchants ← requireSome "merchants2" (EventMerchantEvidenceMemory.ofEntriesAgainst? events [
    { event := ⟨"rec-1"⟩, disposition := .merchant ⟨"grocery-shop"⟩ },
    { event := ⟨"rec-2"⟩, disposition := .nonmerchant }
  ])
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
    descriptions := descriptions
    merchants := merchants
  }

private def buildEvidence3 : IO ActualEvidence := do
  let ev1 ← requireSome "ev1" (makeEvent? "rec-1" [makeEffect "food" 1000, makeEffect "wallet" (-1000)])
  let ev2 ← requireSome "ev2" (makeEvent? "rec-2" [makeEffect "books" 2000, makeEffect "wallet" (-2000)])
  let ev3 ← requireSome "ev3" (makeEvent? "rec-3" [makeEffect "transport" 500, makeEffect "wallet" (-500)])
  let events ← requireSome "events3" (EventMemory.ofEvents? [ev1, ev2, ev3])
  let validity ← requireSome "validity3" (ActualValidityHistory.ofParts? [
    .base ⟨"rec-1"⟩ "2026-09-01",
    .base ⟨"rec-2"⟩ "2026-09-02",
    .base ⟨"rec-3"⟩ "2026-09-03"
  ] [])
  let descriptions ← requireSome "desc3" (EventDescriptionMemory.ofEntries? [
    { event := ⟨"rec-1"⟩, text := "Grocery" },
    { event := ⟨"rec-2"⟩, text := "Book" },
    { event := ⟨"rec-3"⟩, text := "Transport" }
  ])
  let merchants ← requireSome "merchants3" (EventMerchantEvidenceMemory.ofEntriesAgainst? events [
    { event := ⟨"rec-1"⟩, disposition := .merchant ⟨"grocery-shop"⟩ },
    { event := ⟨"rec-2"⟩, disposition := .nonmerchant },
    { event := ⟨"rec-3"⟩, disposition := .merchant ⟨"transit-provider"⟩ }
  ])
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
    descriptions := descriptions
    merchants := merchants
  }

private def cleanupDir (dir : System.FilePath) : IO Unit := do
  if ← dir.pathExists then
    IO.FS.removeDirAll dir

def runTests : IO Unit := do
  let testRoot := System.FilePath.mk "scratch/test-actual-crash"
  cleanupDir testRoot
  IO.FS.createDirAll testRoot
  let actualPath := Loam.ActualAuthority.actualPath testRoot
  let stagePath := System.FilePath.mk (actualPath.toString ++ ".loam-stage")

  let evidence1 ← buildEvidence1
  let evidence2 ← buildEvidence2
  let evidence3 ← buildEvidence3

  -- 1. Initial publication of Evidence 1
  match ← Loam.ActualAuthority.publishActual? testRoot evidence1 with
  | .error e => throw <| IO.userError s!"Initial publish failed: {e}"
  | .ok () => pure ()

  let loaded1 ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load 1 failed: {e}"
    | .ok ev => pure ev
  if loaded1.events.events.length != 1 then
    throw <| IO.userError s!"Expected 1 event, got {loaded1.events.events.length}"
  if loaded1.merchants.entries.length != 1 then
    throw <| IO.userError "Initial publication lost Merchant evidence"

  -- Case A: Stage interruption leaves old actual.loam intact
  -- Simulate a crash/kill while writing stage (partial/corrupted bytes written to stage file)
  IO.FS.writeFile stagePath "LOAM-NORMALIZED-ACTUAL\t1\nTX\trec-2\t2026-09-02\tDESC\tIncomplete"
  -- Reader attempts to load actual: must see old actual.loam with 1 event intact!
  let loadedAfterCrashA ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load after crash A failed: {e}"
    | .ok ev => pure ev
  if loadedAfterCrashA.events.events.length != 1 then
    throw <| IO.userError "Case A failed: stage interruption corrupted existing actual.loam"
  if loadedAfterCrashA.merchants.entries.length != 1 then
    throw <| IO.userError "Case A failed: stage interruption changed Merchant evidence"
  IO.println "Case A passed: stage interruption leaves old actual.loam intact."

  -- Case B: Completed stage pre-rename leaves old actual.loam intact
  -- Simulate a completed valid stage file written, but process died before rename
  let validStageText ← requireSome "encode evidence2" (Loam.Persistence.encodeNormalizedActual? evidence2)
  IO.FS.writeFile stagePath validStageText
  -- Reader attempts to load actual: must STILL see old actual.loam with 1 event intact!
  let loadedAfterCrashB ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load after crash B failed: {e}"
    | .ok ev => pure ev
  if loadedAfterCrashB.events.events.length != 1 then
    throw <| IO.userError "Case B failed: pre-rename stage affected existing actual.loam"
  if loadedAfterCrashB.merchants.entries.length != 1 then
    throw <| IO.userError "Case B failed: pre-rename stage affected Merchant evidence"
  IO.println "Case B passed: completed stage pre-rename leaves old actual.loam intact."

  -- Case C: Atomic rename atomically switches readers to New
  IO.FS.rename stagePath actualPath
  let loadedAfterSwitchC ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load after switch C failed: {e}"
    | .ok ev => pure ev
  if loadedAfterSwitchC.events.events.length != 2 then
    throw <| IO.userError "Case C failed: rename did not atomically switch to new actual.loam"
  if loadedAfterSwitchC.merchants.entries.length != 2 then
    throw <| IO.userError "Case C failed: atomic switch lost Merchant evidence"
  IO.println "Case C passed: atomic rename atomically switches readers to New."

  -- Case D: Malformed stage fails closed, old unchanged
  -- Attempt to publish malformed evidence (e.g. invalid date or referential closure failure)
  let badCorrections ← requireSome "bad corr" (EventCorrectionMemory.ofCorrections? [
    { target := ⟨"nonexistent"⟩, replacement := ⟨"rec-1"⟩ }
  ])
  let invalidEvidence : ActualEvidence := {
    loadedAfterSwitchC with
    corrections := badCorrections
  }
  match ← Loam.ActualAuthority.publishActual? testRoot invalidEvidence with
  | .ok () => throw <| IO.userError "Case D failed: publish of invalid evidence succeeded!"
  | .error _ => pure ()
  -- Authority must still have exactly 2 events intact
  let loadedAfterD ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load after D failed: {e}"
    | .ok ev => pure ev
  if loadedAfterD.events.events.length != 2 then
    throw <| IO.userError "Case D failed: failed publish modified existing actual.loam"
  if loadedAfterD.merchants.entries.length != 2 then
    throw <| IO.userError "Case D failed: failed publish modified Merchant evidence"
  IO.println "Case D passed: malformed publish fails closed, old unchanged."

  -- Case E: Process retry after rename uses New
  -- Reacquire ownership, re-read New (2 events), then commit Evidence 3 (3 events).
  let retryResult ← Loam.ActualAuthority.withActualOwnership testRoot do
    let current ←
      match ← Loam.ActualAuthority.loadActual? testRoot with
      | .ok evidence => pure evidence
      | .error message => return .error message
    if current.events.events.length != 2 then
      return .error "Expected 2 events"
    Loam.ActualAuthority.publishActual? testRoot evidence3
  match retryResult with
  | .error e => throw <| IO.userError s!"Case E retry failed: {e}"
  | .ok () => pure ()

  let loadedAfterE ← match ← Loam.ActualAuthority.loadActual? testRoot with
    | .error e => throw <| IO.userError s!"Load after E failed: {e}"
    | .ok ev => pure ev
  if loadedAfterE.events.events.length != 3 then
    throw <| IO.userError "Case E failed: retry did not reach 3 events"
  if loadedAfterE.merchants.entries.length != 3 then
    throw <| IO.userError "Case E failed: retry did not retain Merchant evidence"
  IO.println "Case E passed: process retry after rename uses New."

  cleanupDir testRoot
  IO.println "All ActualAuthority crash qualification tests PASSED!"

end Loam.Tests.ActualAuthorityCrashTest

def main : IO Unit :=
  Loam.Tests.ActualAuthorityCrashTest.runTests
