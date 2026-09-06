import Lake
open Lake DSL

package loam

require «lean-tea» from git
  "https://github.com/Verilean/lean-tea.git" @ "8f51f1d3ba4bdec7bfb3e10c5a007422e52226d7"

@[default_target]
lean_lib Loam

lean_exe loamUiPrototype02 where
  root := `Loam.Prototype.InteractionShellTeaMain

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

lean_exe loamShadowDay where
  root := `Loam.Cli.ShadowDayCli

lean_exe loamShadowScheduledDay where
  root := `Loam.Cli.ShadowScheduledDayCli
