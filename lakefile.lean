import Lake
open Lake DSL

package loam

@[default_target]
lean_lib Loam

lean_exe loam where
  root := `Loam.Cli

lean_exe loamMovement where
  root := `Loam.Cli.MovementCli

lean_exe loamCapacity where
  root := `Loam.Cli.CapacityCli

lean_exe loamActualRouting where
  root := `Loam.Cli.ActualRoutingCli

lean_exe loamScheduledRouting where
  root := `Loam.Cli.ScheduledRoutingCli

lean_exe loamBudgetWindow where
  root := `Loam.Cli.BudgetWindowCli

lean_exe loamDailyQuantity where
  root := `Loam.Cli.DailyQuantityCli

lean_exe loamOpenScheduled where
  root := `Loam.Cli.OpenScheduledCli

lean_exe loamScheduledSuppression where
  root := `Loam.Cli.ScheduledSuppressionCli

lean_exe loamJournalExport where
  root := `Loam.Cli.JournalExportCli

lean_exe loamShadowAudit where
  root := `Loam.Cli.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.Cli.ShadowQuantityCli

lean_exe loamDoctor where
  root := `Loam.Cli.DoctorCli

lean_exe loamTui where
  root := `Loam.Tui.Cli
