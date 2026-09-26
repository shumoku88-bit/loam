import Loam.HouseholdPaths
import Loam.MovementPublisher
import Loam.OriginalAmountMovementPublisher
import Loam.ExchangePublisher
import Loam.CorrectionPublisher
import Loam.ActualValidityPublisher
import Loam.ActualReversalPublisher
import Loam.EventMerchantPublisher
import Loam.ScheduledCreationPublisher
import Loam.ScheduledTerminalPublisher
import Loam.ScheduledReplacementPublisher
import Loam.ScheduledContinuationRouting
import Loam.AttentionPublisher
import Loam.CapacityPublisher
import Loam.ActualRoutingPublisher
import Loam.ScheduledRoutingPublisher
import Loam.LocusAdmissionPublisher
import Loam.AccountingRolePublisher
import Loam.CurrentQuantityAnchorPublisher
import Loam.MeasurePresentationAuthority

namespace Loam.HouseholdCommand

set_option autoImplicit false

/-!
# Surface-neutral household command boundary

Frontends should select one household data root and submit already-collected
presentation-neutral drafts here. This module owns only canonical production path
selection. Domain admission, authoritative re-read, writer ownership, identity,
recovery behavior, and persistence remain owned by the existing publishers.

Low-level diagnostic CLIs may still call publishers directly when explicitly
operating on an arbitrary file. TUI, future high-level CLI, GUI, and AI adapters
should not need to know canonical `.loam` filenames.
-/


/-- Record one Actual Movement through the normalized Actual publisher. -/
def record
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft) :
    IO (Except String Loam.Core.EventId) :=
  Loam.MovementPublisher.publishDraft root.toString draft

/--
Record one ordinary Movement together with one original presented/charged amount
under the same Actual writer ownership and atomic publication.
-/
def recordWithOriginalAmount
    (root : System.FilePath)
    (draft : Loam.OriginalAmountMovementPublisher.Draft) :
    IO (Except String Loam.Core.EventId) :=
  Loam.OriginalAmountMovementPublisher.publish root.toString draft

/--
Record one newly observed cross-Measure exchange together with the
effect-selected ExchangeEvidence that qualifies it.
-/
def recordExchange
    (root : System.FilePath)
    (draft : Loam.ExchangeAdmission.Draft) :
    IO (Except String Loam.Core.EventId) :=
  Loam.ExchangePublisher.publish root.toString draft

/--
Record one Actual Movement through the normalized Actual publisher under a
stable logical operation identity. Retrying the same identity returns the first
Event without publishing another Event.
-/
def recordIdempotent
    (root : System.FilePath)
    (operation : Loam.Core.MovementOperationId)
    (draft : Loam.MovementAdmission.Draft) :
    IO (Except String Loam.MovementPublisher.IdempotentResult) :=
  Loam.MovementPublisher.publishDraftIdempotent root.toString operation draft

/-- Correct one retained Actual Movement. -/
def correctActual
    (root : System.FilePath)
    (draft : Loam.CorrectionPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.CorrectionPublisher.publishCorrection root.toString draft

/-- Correct one Actual occurrence date. -/
def correctActualDate
    (root : System.FilePath)
    (draft : Loam.ActualValidityPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.ActualValidityPublisher.publishDate root.toString draft

/-- Publish one first Event Merchant / Nonmerchant classification. -/
def classifyEventMerchant
    (root : System.FilePath)
    (draft : Loam.EventMerchantPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.EventMerchantPublisher.publishDisposition root.toString draft

/-- Publish one exact Actual reversal. -/
def reverseActual
    (root : System.FilePath)
    (draft : Loam.ActualReversalPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.ActualReversalPublisher.publishReversal
    (Loam.HouseholdPaths.scheduled root).toString root.toString draft

/-- Create one independent Scheduled occurrence. -/
def createScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledCreationPublisher.Draft) :
    IO (Except String Loam.Core.ScheduledId) :=
  Loam.ScheduledCreationPublisher.publishCreation
    (Loam.HouseholdPaths.scheduled root).toString root.toString draft

/-- Complete one Scheduled occurrence into Actual. -/
def completeScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledTerminalPublisher.CompletionDraft) :
    IO (Except String Unit) :=
  Loam.ScheduledTerminalPublisher.publishCompletion
    (Loam.HouseholdPaths.scheduled root).toString root.toString draft

/-- Cancel one current-open Scheduled occurrence. -/
def cancelScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledTerminalPublisher.CancellationDraft) :
    IO (Except String Unit) :=
  Loam.ScheduledTerminalPublisher.publishCancellation
    (Loam.HouseholdPaths.scheduled root).toString root.toString draft

/-- Replace one current-open Scheduled occurrence. -/
def replaceScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledReplacementPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.ScheduledReplacementPublisher.publishReplacement
    (Loam.HouseholdPaths.scheduled root).toString root.toString draft

/-- Inherit predecessor Scheduled routing into one newly created continuation. -/
def inheritScheduledRouting
    (root : System.FilePath)
    (predecessor created : Loam.Core.ScheduledId)
    (effectiveOn : String) :
    IO (Except String Loam.ScheduledContinuationRouting.Report) :=
  Loam.ScheduledContinuationRouting.inherit
    (Loam.HouseholdPaths.scheduledRouting root) (Loam.HouseholdPaths.scheduled root) predecessor created effectiveOn

/-- Add one current-open household Attention item. -/
def addAttention
    (root : System.FilePath)
    (draft : Loam.AttentionPublisher.AddDraft) :
    IO (Except String Loam.Core.AttentionId) :=
  Loam.AttentionPublisher.add (Loam.HouseholdPaths.attention root).toString draft

/-- Resolve or drop one retained open household Attention item. -/
def closeAttention
    (root : System.FilePath)
    (draft : Loam.AttentionPublisher.CloseDraft) :
    IO (Except String Unit) :=
  Loam.AttentionPublisher.close (Loam.HouseholdPaths.attention root).toString draft

/-- Publish one binary Capacity movement. -/
def moveCapacity
    (root : System.FilePath)
    (draft : Loam.CapacityPublisher.Draft) :
    IO (Except String Loam.Core.CapacityMovementId) :=
  Loam.CapacityPublisher.publish (Loam.HouseholdPaths.capacity root).toString draft

/-- Publish one balanced multi-coordinate Capacity movement. -/
def rebalanceCapacity
    (root : System.FilePath)
    (draft : Loam.CapacityPublisher.BalancedDraft) :
    IO (Except String Loam.Core.CapacityMovementId) :=
  Loam.CapacityPublisher.publishBalanced (Loam.HouseholdPaths.capacity root).toString draft

/-- Publish one Actual routing assertion. -/
def routeActual
    (root : System.FilePath)
    (draft : Loam.ActualRoutingPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.ActualRoutingPublisher.publish (Loam.HouseholdPaths.actualRouting root).toString draft

/-- Publish one Scheduled routing assertion. -/
def routeScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledRoutingPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.ScheduledRoutingPublisher.publish
    (Loam.HouseholdPaths.scheduledRouting root).toString (Loam.HouseholdPaths.scheduled root).toString draft

/-- Admit one new Locus for future publication. -/
def admitLocus
    (root : System.FilePath)
    (draft : Loam.LocusAdmissionPublisher.Draft) :
    IO (Except String Unit) :=
  Loam.LocusAdmissionPublisher.publishAdmission root.toString draft

/-- Assign one initial AccountingRole to an unused admitted Locus. -/
def assignInitialAccountingRole
    (root : System.FilePath)
    (draft : Loam.AccountingRolePublisher.Draft) :
    IO (Except String Unit) :=
  Loam.AccountingRolePublisher.publishInitialRole
    (Loam.HouseholdPaths.scheduled root).toString root.toString (Loam.HouseholdPaths.accountingRole root).toString draft

/-- Publish one reconciliation group of current quantities observed together now. -/
def observeCurrentQuantities
    (root : System.FilePath)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) :
    IO (Except String Unit) :=
  Loam.CurrentQuantityAnchorPublisher.publish root.toString assertions


/--
Select or change one Measure presentation scale through the qualified household
administration boundary. Used Measures refuse ordinary scale changes.
-/
def setMeasureScale
    (root : System.FilePath)
    (measure : Loam.Core.MeasureId)
    (scale : Nat) : IO (Except String Unit) :=
  Loam.MeasurePresentationAuthority.setScale root measure scale

end Loam.HouseholdCommand
