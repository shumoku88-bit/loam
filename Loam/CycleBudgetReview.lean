import Loam.ActualAuthority
import Loam.CycleFundingConfig
import Loam.CycleFundingInspection
import Loam.HouseholdPaths
import Loam.BoundaryPresetConfig

namespace Loam.CycleBudgetReview

open Loam.Core
set_option autoImplicit false

/-- Immutable read answers with independent visible failure boundaries. -/
structure Snapshot where
  observedAt : String
  window : Except String Loam.BoundaryPresetConfig.CurrentWindow
  coverage : Except String Loam.CurrentCoverageReview.Snapshot
  physical : Except String Loam.BalanceReview.Snapshot
  selection : Except String (List EffectCoordinate)
  funding : Except String Loam.CycleFundingInspection.Summary
  deriving Repr

/-- Optional read failures, including filesystem failures, never terminate the workspace. -/
private def attempt {α : Type} (action : IO (Except String α)) : IO (Except String α) := do
  try action catch error => return .error error.toString

/-- The two Cycle Budget read branches that observe normalized Actual authority. -/
private structure ActualObservation where
  coverage : Except String Loam.CurrentCoverageReview.Snapshot
  evidence : Except String Loam.BalanceReview.Evidence

private def loadActualObservation
    (dataDir actualRoot : System.FilePath)
    (observedAt : String)
    (window : Except String Loam.BoundaryPresetConfig.CurrentWindow) :
    IO ActualObservation := do
  let coverage ← attempt do
    match window with
    | .error message => return .error message
    | .ok window =>
      Loam.CurrentCoverageReview.loadSnapshotAt
        dataDir actualRoot window.start observedAt window.endExclusive
  let evidence ← attempt (Loam.BalanceReview.loadEvidence dataDir actualRoot)
  return { coverage, evidence }

/--
Compose current queries without Home selected-day input. Physical display and
funding use the same loaded balance evidence but independent selections.
CurrentCoverage and Balance evidence reads share one Actual ownership interval,
so one Cycle Budget answer cannot mix two generations of `actual.loam` if a
writer publishes concurrently. Other authorities remain independently visible;
this still does not promise a cross-file atomic snapshot or historical balance
replay. No writer or recovery is invoked.
-/
def loadSnapshotAt (dataDir actualRoot : System.FilePath) (observedAt : String) :
    IO Snapshot := do
  let window ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let observation ←
    try
      Loam.ActualAuthority.withActualFileOwnership actualPath
        (loadActualObservation dataDir actualRoot observedAt window)
    catch error =>
      let message := "loam: Cycle Budget Actual observation unavailable: " ++ error.toString
      pure {
        coverage := .error message
        evidence := .error message
      }
  let coverage := observation.coverage
  let evidence := observation.evidence
  let physical ← attempt do
    match evidence with
    | .error message => return .error message
    | .ok evidence =>
      match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView dataDir) with
      | none => return .error "balance-view.tsv malformed"
      | some coordinates =>
        return Loam.BalanceReview.project
          evidence.events evidence.corrections evidence.coverage coordinates
  let selection ← Loam.CycleFundingConfig.load (Loam.HouseholdPaths.cycleFunding dataDir)
  let funding := do
    let current ← coverage
    let coordinates ← selection
    let balances ← evidence
    Loam.CycleFundingInspection.project balances.events balances.corrections balances.coverage
      coordinates ⟨"jpy"⟩ current
  return { observedAt, window, coverage, physical, selection, funding }

end Loam.CycleBudgetReview
