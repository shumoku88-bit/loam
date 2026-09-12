import Loam.MovementPublisher
import Loam.CorrectionPublisher
import Loam.ActualValidityPublisher
import Loam.ActualReversalPublisher
import Loam.ScheduledCreationPublisher
import Loam.ScheduledTerminalPublisher
import Loam.ScheduledReplacementPublisher
import Loam.ScheduledContinuationRouting
import Loam.CapacityPublisher
import Loam.ActualRoutingPublisher
import Loam.ScheduledRoutingPublisher
import Loam.LocusAdmissionPublisher
import Loam.AccountingRolePublisher

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

private def scheduledFile (root : System.FilePath) : System.FilePath :=
  root / "scheduled.loam"

private def capacityFile (root : System.FilePath) : System.FilePath :=
  root / "capacity.loam"

private def actualRoutingFile (root : System.FilePath) : System.FilePath :=
  root / "actual-routing.loam"

private def scheduledRoutingFile (root : System.FilePath) : System.FilePath :=
  root / "scheduled-routing.loam"

private def accountingRoleFile (root : System.FilePath) : System.FilePath :=
  root / "accounting-role.loam"

/-- Record one Actual Movement through the normalized Actual publisher. -/
def record
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft) :
    IO (Except String Loam.MovementPublisher.Receipt) :=
  Loam.MovementPublisher.publishDraft root.toString draft

/-- Correct one retained Actual Movement. -/
def correctActual
    (root : System.FilePath)
    (draft : Loam.CorrectionPublisher.Draft) :
    IO (Except String Loam.CorrectionPublisher.Receipt) :=
  Loam.CorrectionPublisher.publishCorrection root.toString draft

/-- Correct one Actual occurrence date. -/
def correctActualDate
    (root : System.FilePath)
    (draft : Loam.ActualValidityPublisher.Draft) :
    IO (Except String Loam.ActualValidityPublisher.Receipt) :=
  Loam.ActualValidityPublisher.publishDate root.toString draft

/-- Publish one exact Actual reversal. -/
def reverseActual
    (root : System.FilePath)
    (draft : Loam.ActualReversalPublisher.Draft) :
    IO (Except String Loam.ActualReversalPublisher.Receipt) :=
  Loam.ActualReversalPublisher.publishReversal
    (scheduledFile root).toString root.toString draft

/-- Create one independent Scheduled occurrence. -/
def createScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledCreationPublisher.Draft) :
    IO (Except String Loam.ScheduledCreationPublisher.Receipt) :=
  Loam.ScheduledCreationPublisher.publishCreation
    (scheduledFile root).toString root.toString draft

/-- Complete one Scheduled occurrence into Actual. -/
def completeScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledTerminalPublisher.CompletionDraft) :
    IO (Except String Loam.ScheduledTerminalPublisher.CompletionReceipt) :=
  Loam.ScheduledTerminalPublisher.publishCompletion
    (scheduledFile root).toString root.toString draft

/-- Cancel one current-open Scheduled occurrence. -/
def cancelScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledTerminalPublisher.CancellationDraft) :
    IO (Except String Loam.ScheduledTerminalPublisher.CancellationReceipt) :=
  Loam.ScheduledTerminalPublisher.publishCancellation
    (scheduledFile root).toString root.toString draft

/-- Replace one current-open Scheduled occurrence. -/
def replaceScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledReplacementPublisher.Draft) :
    IO (Except String Loam.ScheduledReplacementPublisher.Receipt) :=
  Loam.ScheduledReplacementPublisher.publishReplacement
    (scheduledFile root).toString root.toString draft

/-- Inherit predecessor Scheduled routing into one newly created continuation. -/
def inheritScheduledRouting
    (root : System.FilePath)
    (predecessor created : Loam.Core.ScheduledId)
    (effectiveOn : String) :
    IO (Except String Loam.ScheduledContinuationRouting.Report) :=
  Loam.ScheduledContinuationRouting.inherit
    (scheduledRoutingFile root) (scheduledFile root) predecessor created effectiveOn

/-- Publish one binary Capacity movement. -/
def moveCapacity
    (root : System.FilePath)
    (draft : Loam.CapacityPublisher.Draft) :
    IO (Except String Loam.CapacityPublisher.Receipt) :=
  Loam.CapacityPublisher.publish (capacityFile root).toString draft

/-- Publish one balanced multi-coordinate Capacity movement. -/
def rebalanceCapacity
    (root : System.FilePath)
    (draft : Loam.CapacityPublisher.BalancedDraft) :
    IO (Except String Loam.CapacityPublisher.BalancedReceipt) :=
  Loam.CapacityPublisher.publishBalanced (capacityFile root).toString draft

/-- Publish one Actual routing assertion. -/
def routeActual
    (root : System.FilePath)
    (draft : Loam.ActualRoutingPublisher.Draft) :
    IO (Except String Loam.ActualRoutingPublisher.Receipt) :=
  Loam.ActualRoutingPublisher.publish (actualRoutingFile root).toString draft

/-- Publish one Scheduled routing assertion. -/
def routeScheduled
    (root : System.FilePath)
    (draft : Loam.ScheduledRoutingPublisher.Draft) :
    IO (Except String Loam.ScheduledRoutingPublisher.Receipt) :=
  Loam.ScheduledRoutingPublisher.publish
    (scheduledRoutingFile root).toString (scheduledFile root).toString draft

/-- Admit one new Locus for future publication. -/
def admitLocus
    (root : System.FilePath)
    (draft : Loam.LocusAdmissionPublisher.Draft) :
    IO (Except String Loam.LocusAdmissionPublisher.Receipt) :=
  Loam.LocusAdmissionPublisher.publishAdmission root.toString draft

/-- Assign one initial AccountingRole to an unused admitted Locus. -/
def assignInitialAccountingRole
    (root : System.FilePath)
    (draft : Loam.AccountingRolePublisher.Draft) :
    IO (Except String Loam.AccountingRolePublisher.Receipt) :=
  Loam.AccountingRolePublisher.publishInitialRole
    (scheduledFile root).toString root.toString (accountingRoleFile root).toString draft

end Loam.HouseholdCommand
