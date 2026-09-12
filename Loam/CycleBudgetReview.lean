import Loam.CycleFundingConfig
import Loam.CycleFundingInspection
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

/--
Compose current queries without Home selected-day input. Physical display and
funding use the same loaded balance evidence but independent selections. Coverage
keeps its existing production reader; this does not promise a cross-file atomic
snapshot or historical balance replay. No writer or recovery is invoked.
-/
def loadSnapshotAt (dataDir actualRoot : System.FilePath) (observedAt : String) :
    IO Snapshot := do
  let window ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt
  let coverage ← attempt do
    match window with
    | .error message => return .error message
    | .ok window =>
      Loam.CurrentCoverageReview.loadSnapshotAt
        dataDir actualRoot window.start observedAt window.endExclusive
  let evidence ← attempt (Loam.BalanceReview.loadEvidence dataDir actualRoot)
  let physical ← attempt do
    match evidence with
    | .error message => return .error message
    | .ok evidence =>
      match ← Loam.BalanceViewConfig.load? (dataDir / "config" / "balance-view.tsv") with
      | none => return .error "balance-view.tsv malformed"
      | some coordinates =>
        return Loam.BalanceReview.project
          evidence.events evidence.corrections evidence.coverage coordinates
  let selection ← Loam.CycleFundingConfig.load (dataDir / "config" / "cycle-funding.tsv")
  let funding := do
    let current ← coverage
    let coordinates ← selection
    let balances ← evidence
    Loam.CycleFundingInspection.project balances.events balances.corrections balances.coverage
      coordinates ⟨"jpy"⟩ current
  return { observedAt, window, coverage, physical, selection, funding }

end Loam.CycleBudgetReview
