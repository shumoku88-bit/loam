import Loam.Tui.Cli
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ZeroOriginCoveragePersistence

namespace Loam.Tests.TuiHomeActualGeneration

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def publishActualGeneration
    (root : System.FilePath)
    (eventToken : String)
    (walletQuanta : Int) : IO Unit := do
  let event ←
    requireSome
      (Event.ofEffects? ⟨eventToken⟩
        [ Effect.ofQuantity
            ⟨eventToken ++ "-wallet"⟩
            ⟨"wallet"⟩
            ⟨"jpy"⟩
            (Quantity.ofQuanta walletQuanta)
        , Effect.ofQuantity
            ⟨eventToken ++ "-income"⟩
            ⟨"income"⟩
            ⟨"jpy"⟩
            (Quantity.ofQuanta (-walletQuanta))
        ])
      "Home generation fixture Event"
  let events ←
    requireSome (EventMemory.ofEvents? [event])
      "Home generation fixture Event memory"
  let validity ←
    requireSome
      (ActualValidityHistory.ofParts?
        [.base event.id "2026-09-24"] [])
      "Home generation fixture Actual validity"
  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
  }
  let _ ←
    requireOk (← Loam.ActualAuthority.publishActual? root evidence)
      "publish Home Actual generation"
  pure ()

private def initializeIndependentEvidence (root : System.FilePath) : IO Unit := do
  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile
    (root / "config" / "boundary-presets.tsv")
    "cycle\t2026-09-01\t2026-10-01\n"
  IO.FS.writeFile
    (root / "config" / "daily-pace.tsv")
    "wallet\tjpy\n"

  let coverage ←
    requireSome
      (ZeroOriginCoverage.ofCoordinates?
        [⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩])
      "Home generation zero-origin coverage"
  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") coverage)
    "save Home generation zero-origin coverage"

  let scheduled ←
    requireSome
      (ScheduledMemory.ofOccurrences? ([] : List (ScheduledOccurrence String)))
      "Home generation empty Scheduled memory"
  let terminals ←
    requireSome (ScheduledTerminalMemory.ofTerminals? [])
      "Home generation empty Scheduled terminal memory"
  expect
    (← Loam.Persistence.saveScheduledLifecycleImage?
      (root / "scheduled.loam") { scheduled, terminals })
    "save Home generation Scheduled lifecycle"

def main : IO Unit := do
  let root ← IO.FS.createTempDir
  initializeIndependentEvidence root

  publishActualGeneration root "generation-a" 1000
  let generationA ←
    requireOk (← Loam.ActualAuthority.loadImage? root)
      "load generation A"

  -- Simulate a writer publishing after Home selected its admitted Actual image.
  publishActualGeneration root "generation-b" 2000
  let currentGeneration ←
    requireOk (← Loam.ActualAuthority.loadImage? root)
      "load generation B"
  expect
    ((currentGeneration.currentEvents.findById? ⟨"generation-b"⟩).isSome)
    "fixture did not advance canonical Actual to generation B"

  let snapshot ←
    requireOk
      (← Loam.Tui.Cli.loadSnapshotFromActualImage
        root "2026-09-24" generationA)
      "compose Home from generation A"

  match snapshot.actual.allRecords with
  | [record] =>
      expect (record.event.id.token == "generation-a")
        "Home Actual rows reopened canonical Actual after selecting generation A"
  | _ =>
      throw (IO.userError "Home Actual rows did not preserve the selected generation")

  match snapshot.scheduled with
  | .error message =>
      throw (IO.userError ("Home Scheduled evidence unavailable: " ++ message))
  | .ok scheduled =>
      expect
        ((scheduled.events.findById? ⟨"generation-a"⟩).isSome &&
          (scheduled.events.findById? ⟨"generation-b"⟩).isNone)
        "Home Scheduled validation mixed a later Actual generation"

  match snapshot.pace with
  | .error message =>
      throw (IO.userError ("Home Daily Pace unavailable: " ++ message))
  | .ok pace =>
      expect (pace.eligiblePool.quanta == 1000)
        "Home Daily Pace reopened canonical Actual after selecting generation A"

  match snapshot.paceHistory with
  | .error message =>
      throw (IO.userError ("Home recent pace unavailable: " ++ message))
  | .ok points =>
      match points.reverse with
      | [] => throw (IO.userError "Home recent pace returned no current point")
      | latest :: _ =>
          expect (latest.eligiblePool.quanta == 1000)
            "Home recent pace reopened canonical Actual after selecting generation A"

  IO.println
    "Home Actual generation: one admitted Actual image remained shared after canonical Actual advanced."

end Loam.Tests.TuiHomeActualGeneration

def main : IO Unit :=
  Loam.Tests.TuiHomeActualGeneration.main
