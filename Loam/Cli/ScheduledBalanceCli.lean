import Loam.ActualDate
import Loam.Application.ScheduledBalanceInspection
import Loam.BalanceViewConfig
import Loam.Persistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.ScheduledPersistence
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

private def printEffect (effect : ScheduledBalanceEffect) : IO Unit := do
  IO.println
    ("  " ++ effect.coordinate.locus.token ++ ": " ++
      toString effect.quantity.quanta ++ " " ++ effect.coordinate.measure.token)

/--
Project current-open Scheduled effects through the current replaceable balance
view before one end-exclusive calendar boundary.

This command does not read QuantityBasis or current balances and therefore does
not invent a forecast balance. It answers only the already-qualified signed
Scheduled-effect question from Observations 108 and 119.
-/
def report (rootPath endExclusive : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate endExclusive then
    IO.eprintln "loam: Scheduled balance horizon must be a real YYYY-MM-DD calendar date"
    return 2
  else
    let root := System.FilePath.mk rootPath
    let scheduledPath := root / "scheduled.loam"
    let memoryPath := root / "memory.loam"
    let balanceViewPath := root / "balance-view.tsv"
    let completionPath :=
      Loam.Persistence.scheduledCompletionPathForScheduledMemory scheduledPath
    let retirementPath :=
      Loam.Persistence.scheduledRetirementPathForScheduledMemory scheduledPath

    match ← loadScheduledMemoryOrEmpty? scheduledPath with
    | none =>
        IO.eprintln "loam: malformed or unsupported Scheduled memory"
        return 2
    | some scheduled =>
        match ← Loam.Persistence.loadScheduledCompletionMemoryOrEmpty? completionPath with
        | none =>
            IO.eprintln "loam: malformed or unsupported Scheduled completion memory"
            return 2
        | some completions =>
            match ← Loam.Persistence.loadScheduledRetirementMemoryOrEmpty? retirementPath with
            | none =>
                IO.eprintln "loam: malformed or unsupported Scheduled retirement memory"
                return 2
            | some retirements =>
                match ← loadEventMemoryOrEmpty? memoryPath with
                | none =>
                    IO.eprintln "loam: malformed or unsupported Event memory"
                    return 2
                | some events =>
                    match ← Loam.BalanceViewConfig.load? balanceViewPath with
                    | none =>
                        IO.eprintln "loam: malformed or unsupported balance-view config"
                        return 2
                    | some coordinates =>
                        match currentScheduledBalanceEffectsBefore?
                            scheduled completions retirements events coordinates endExclusive with
                        | none =>
                            IO.eprintln
                              "loam: Scheduled balance effects unavailable: lifecycle evidence is inconsistent"
                            return 1
                        | some effects =>
                            IO.println
                              ("Current-open Scheduled balance effects before " ++
                                endExclusive ++ " (end-exclusive):")
                            if effects.isEmpty then
                              IO.println "No balances are selected in the current balance view."
                            else
                              for effect in effects do
                                printEffect effect
                            return 0

end Loam.ScheduledBalanceCli
