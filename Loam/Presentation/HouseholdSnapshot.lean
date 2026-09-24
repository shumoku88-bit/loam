import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.CycleSpendingPaceReview
import Loam.PurposeCatalog
import Loam.Presentation.ReadState
import Loam.RoleBalanceReview
import Loam.RoleFlowReview
import Loam.ScheduledReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview

namespace Loam.Presentation

set_option autoImplicit false

/-!
# Surface-neutral household presentation snapshot

This structure is the shared read-side evidence handed to presentation surfaces.
It deliberately contains Review answers rather than GUI widgets, terminal state,
HTML, persistence handles, or publication commands.

A TUI, Web document, future desktop GUI, or other renderer may present this
snapshot differently without becoming household authority.
-/

/--
Read-side household evidence for presentation surfaces.

The snapshot is process-local observation data. It owns no household semantics,
persistence, publication, recurrence, classification, or write authority.
-/
structure HouseholdSnapshot where
  observedAt : String
  actual : Loam.Presentation.ReadState (List Loam.ActualReview.Record)
  scheduled : Loam.Presentation.ReadState (List Loam.ScheduledReview.Record)
  attention : Loam.Presentation.ReadState Loam.AttentionReview.Snapshot
  budget : Loam.CycleBudgetReview.Snapshot
  capacity : Loam.Presentation.ReadState Loam.CapacityReview.Snapshot
  /-- Current Daily Pace derived from the same admitted Actual generation when available. -/
  pace : Loam.Presentation.ReadState Loam.CycleSpendingPaceReview.Snapshot :=
    .notRequested
  /-- Current explicit-window Stock–Flow report for presentation, when requested. -/
  stockFlow : Loam.Presentation.ReadState Loam.StockFlowReview.Snapshot :=
    .notRequested
  /-- Current explicit-window role flow used by Income & Expense presentation. -/
  roleFlow : Loam.Presentation.ReadState Loam.RoleFlowReview.Snapshot :=
    .notRequested
  /-- Current evidence-aware Role Balance answer for presentation. -/
  roleBalances : Loam.Presentation.ReadState Loam.RoleBalanceReview.Snapshot :=
    .notRequested
  /-- Current explicit-window Transactions Flow answer for presentation. -/
  transactionsFlow : Loam.Presentation.ReadState Loam.TransactionsFlowReview.Snapshot :=
    .notRequested
  purposeMetadata : List Loam.PurposeCatalog.Metadata := []

end Loam.Presentation
