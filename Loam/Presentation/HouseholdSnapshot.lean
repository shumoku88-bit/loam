import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.CycleSpendingPaceReview
import Loam.PurposeCatalog
import Loam.ScheduledReview
import Loam.StockFlowReview

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
  actual : Except String (List Loam.ActualReview.Record)
  scheduled : Except String (List Loam.ScheduledReview.Record)
  attention : Except String Loam.AttentionReview.Availability
  budget : Loam.CycleBudgetReview.Snapshot
  capacity : Except String Loam.CapacityReview.Snapshot
  /-- Current Daily Pace derived from the same admitted Actual generation when available. -/
  pace : Except String Loam.CycleSpendingPaceReview.Snapshot :=
    .error "loam: Daily Pace not loaded"
  /-- Current explicit-window Stock–Flow report for presentation, when requested. -/
  stockFlow : Except String Loam.StockFlowReview.Snapshot :=
    .error "loam: Stock-Flow not loaded"
  purposeMetadata : List Loam.PurposeCatalog.Metadata := []

end Loam.Presentation
