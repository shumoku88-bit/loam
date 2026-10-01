import Lake
open Lake DSL

package loam

@[default_target]
lean_lib Loam

lean_exe loam where
  root := `Loam.Cli

lean_exe loamMovement where
  root := `Loam.Cli.MovementExecutable

lean_exe loamMovementProposal where
  root := `Loam.Cli.MovementProposalExecutable

lean_exe loamMovementProposalRecord where
  root := `Loam.Cli.MovementProposalRecordExecutable

lean_exe loamCapacity where
  root := `Loam.Cli.CapacityExecutable

lean_exe loamActualRouting where
  root := `Loam.Cli.ActualRoutingExecutable

lean_exe loamScheduledRouting where
  root := `Loam.Cli.ScheduledRoutingExecutable

lean_exe loamBudgetWindow where
  root := `Loam.Cli.BudgetWindowExecutable

lean_exe loamDailyQuantity where
  root := `Loam.Cli.DailyQuantityExecutable

lean_exe loamOpenScheduled where
  root := `Loam.Cli.OpenScheduledExecutable

lean_exe loamScheduledSuppression where
  root := `Loam.Cli.ScheduledSuppressionCli

lean_exe loamJournalExport where
  root := `Loam.Cli.JournalExportExecutable

lean_exe loamPtaExport where
  root := `Loam.Cli.PlainTextAccountingExportExecutable

lean_exe loamBeancountExport where
  root := `Loam.Cli.BeancountExportExecutable

lean_exe loamShadowAudit where
  root := `Loam.Cli.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.Cli.ShadowQuantityCli

lean_exe loamDoctor where
  root := `Loam.Cli.DoctorExecutable

lean_exe loamHouseholdObservation where
  root := `Loam.Cli.HouseholdObservationCli

lean_exe loamTui where
  root := `Loam.Tui.Executable

lean_exe loamAttention where
  root := `Loam.Tui.AttentionMain

lean_exe loamMemory where
  root := `Loam.Cli.PersonalMemoryCli
