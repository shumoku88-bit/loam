import Loam.ActualDate
import Loam.Application.ScheduledBalanceHypothetical
import Loam.Application.ScheduledBalanceInspection
import Loam.BalanceViewConfig
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledReplacementPersistence
import Loam.Persistence.ScheduledRetirementPersistence

namespace Loam.ScheduledBalanceCli

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def loadScheduledMemoryOrEmpty?
    (path : System.FilePath) : IO (Option (ScheduledMemory String)) := do
  if ← path.pathExists then
    Loam.Persistence.loadScheduledMemory? path
  else
    return ScheduledMemory.ofOccurrences? []

private def loadEventMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return EventMemory.ofEvents? []

private structure QueryContext where
  scheduled : ScheduledMemory String
  completions : ScheduledCompletionMemory
  retirements : ScheduledRetirementMemory
  replacements : ScheduledReplacementMemory
  events : EventMemory
  coordinates : List EffectCoordinate

private def loadContext (rootPath : String) : IO (Except String QueryContext) := do
  let root := System.FilePath.mk rootPath
  let scheduledPath := root / "scheduled.loam"
  let memoryPath := root / "memory.loam"
  let balanceViewPath := root / "balance-view.tsv"
  let completionPath :=
    Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledPath
  let retirementPath :=
    Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledPath
  let replacementPath :=
    Loam.Persistence.scheduledReplacementPathForScheduledMemory scheduledPath

  match ← loadScheduledMemoryOrEmpty? scheduledPath with
  | none =>
      return .error "loam: malformed or unsupported Scheduled memory"
  | some scheduled =>
      match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionPath with
      | none =>
          return .error "loam: malformed or unsupported Scheduled completion memory"
      | some completions =>
          match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementPath with
          | none =>
              return .error "loam: malformed or unsupported Scheduled retirement memory"
          | some retirements =>
              match ← Loam.Persistence.loadScheduledReplacementMemoryOrEmpty? replacementPath with
              | none =>
                  return .error "loam: malformed or unsupported Scheduled replacement memory"
              | some replacements =>
                  match ← loadEventMemoryOrEmpty? memoryPath with
                  | none =>
                      return .error "loam: malformed or unsupported Event memory"
                  | some events =>
                      match ← Loam.BalanceViewConfig.load? balanceViewPath with
                      | none =>
                          return .error "loam: malformed or unsupported balance-view config"
                      | some coordinates =>
                          return .ok {
                            scheduled := scheduled
                            completions := completions
                            retirements := retirements
                            replacements := replacements
                            events := events
                            coordinates := coordinates
                          }

private def printEffect (effect : ScheduledBalanceEffect) : IO Unit := do
  IO.println
    ("  " ++ effect.coordinate.locus.token ++ ": " ++
      toString effect.quantity.quanta ++ " " ++ effect.coordinate.measure.token)

private def printEffects (effects : List ScheduledBalanceEffect) : IO Unit := do
  if effects.isEmpty then
    IO.println "  (no balances selected)"
  else
    for effect in effects do
      printEffect effect

/--
Project replacement-aware current-open Scheduled effects through the current
replaceable balance view before one end-exclusive calendar boundary.

This command does not read QuantityBasis or current balances and therefore does
not invent a forecast balance. It answers only the already-qualified signed
Scheduled-effect question from Observations 108 and 119 after applying explicit
Observation-105 replacement provenance.
-/
def report (rootPath endExclusive : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate endExclusive then
    IO.eprintln "loam: Scheduled balance horizon must be a real YYYY-MM-DD calendar date"
    return 2
  else
    match ← loadContext rootPath with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok context =>
        match currentScheduledBalanceEffectsBeforeWithReplacement?
            context.scheduled context.completions context.retirements context.replacements
            context.events context.coordinates endExclusive with
        | none =>
            IO.eprintln
              "loam: Scheduled balance effects unavailable: lifecycle or replacement evidence is inconsistent"
            return 1
        | some effects =>
            IO.println
              ("Current-open Scheduled balance effects before " ++
                endExclusive ++ " (end-exclusive):")
            printEffects effects
            return 0

/--
Compare the replacement-aware Scheduled balance projection with one read-only
hypothetical that suppresses exactly one currently open Scheduled identity.

The command never writes retirement/completion/replacement evidence or a second
Scheduled memory. A superseded identity is not currently open and is therefore
rejected as a hypothetical suppression target.
-/
def reportSuppression
    (rootPath endExclusive scheduledId : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate endExclusive then
    IO.eprintln "loam: Scheduled suppression horizon must be a real YYYY-MM-DD calendar date"
    return 2
  else if scheduledId.isEmpty then
    IO.eprintln "loam: Scheduled suppression target must be a non-empty Scheduled id"
    return 2
  else
    match ← loadContext rootPath with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok context =>
        let hypothesis : SuppressScheduledHypothesis :=
          { scheduled := ⟨scheduledId⟩ }
        match compareSuppressScheduledBalanceEffectsBeforeWithReplacement
            context.scheduled context.completions context.retirements context.replacements
            context.events context.coordinates endExclusive hypothesis with
        | .targetNotOpen =>
            IO.eprintln
              ("loam: hypothetical Scheduled suppression target is not currently open: " ++
                scheduledId)
            return 1
        | .unknownCompletionScheduled =>
            IO.eprintln
              "loam: Scheduled suppression unavailable: completion evidence refers to an unknown Scheduled identity"
            return 1
        | .unknownRetirementScheduled =>
            IO.eprintln
              "loam: Scheduled suppression unavailable: retirement evidence refers to an unknown Scheduled identity"
            return 1
        | .unknownReplacementScheduled =>
            IO.eprintln
              "loam: Scheduled suppression unavailable: replacement evidence refers to an unknown Scheduled identity"
            return 1
        | .invalidReplacementGraph =>
            IO.eprintln
              "loam: Scheduled suppression unavailable: replacement graph is invalid"
            return 1
        | .conflictingTerminalEvidence =>
            IO.eprintln
              "loam: Scheduled suppression unavailable: terminal lifecycle evidence conflicts"
            return 1
        | .comparison comparison =>
            IO.println
              ("Hypothetical Scheduled suppression before " ++
                endExclusive ++ " (end-exclusive):")
            IO.println ("Hypothesis: suppress Scheduled " ++ scheduledId)
            IO.println "Baseline:"
            printEffects comparison.baseline
            IO.println "Projected:"
            printEffects comparison.projected
            return 0

end Loam.ScheduledBalanceCli
