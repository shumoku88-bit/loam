import Loam.ActualDate
import Loam.Application.ScheduledBalanceHypothetical
import Loam.Application.ScheduledBalanceInspection
import Loam.BalanceViewConfig
import Loam.MovementManifestAuthority
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.ScheduledBalanceCli

open Loam.Core
open Loam.Application

set_option autoImplicit false

private structure QueryContext where
  scheduled : ScheduledMemory String
  terminals : ScheduledTerminalMemory
  events : EventMemory
  coordinates : List EffectCoordinate

private def loadContext (rootPath : String) : IO (Except String QueryContext) := do
  let root := System.FilePath.mk rootPath
  let scheduledPath := root / "scheduled.loam"
  let manifestRoot := root / "movement-authority"
  let balanceViewPath := root / "config" / "balance-view.tsv"

  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledPath
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  let movement ←
    match ← Loam.MovementManifestAuthority.loadSelectedEvidence? manifestRoot with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match ← Loam.BalanceViewConfig.load? balanceViewPath with
  | none =>
      return .error "loam: malformed or unsupported balance-view config"
  | some coordinates =>
      return .ok {
        scheduled := lifecycle.scheduled
        terminals := lifecycle.terminals
        events := movement.events
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

private def printCoverageCaveat : IO Unit :=
  IO.println
    "Coverage: explicit current-open Scheduled evidence only; unmaterialized future obligations remain Unknown."

/--
Project current-open Scheduled effects through the current replaceable balance
view before one end-exclusive calendar boundary.

The query consumes exactly one complete Scheduled lifecycle authority and the
selected Movement Event evidence frontier. Completion, retirement, and
replacement are ordinary target forms of the same Scheduled terminal relation.
It does not invent a forecast balance.
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
        match currentScheduledBalanceEffectsBefore?
            context.scheduled context.terminals context.events
            context.coordinates endExclusive with
        | none =>
            IO.eprintln
              "loam: Scheduled balance effects unavailable: terminal lifecycle evidence is inconsistent"
            return 1
        | some effects =>
            IO.println
              ("Current-open Scheduled balance effects before " ++
                endExclusive ++ " (end-exclusive):")
            printEffects effects
            printCoverageCaveat
            return 0

/--
Compare the current Scheduled balance projection with one read-only hypothetical
that suppresses exactly one currently open Scheduled identity.
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
        match compareSuppressScheduledBalanceEffectsBefore
            context.scheduled context.terminals context.events
            context.coordinates endExclusive hypothesis with
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
            printCoverageCaveat
            return 0

end Loam.ScheduledBalanceCli
