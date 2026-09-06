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

lean_exe loamShadowDay where
  root := `Loam.Cli.ShadowDayCli

lean_exe loamShadowScheduledDay where
  root := `Loam.Cli.ShadowScheduledDayCli

lean_exe loamUiPrototype04 where
  root := `Loam.Prototype.VerifiedTui04.Cli

lean_exe loamUiPrototype05 where
  root := `Loam.Prototype.VerifiedTui05.Cli

lean_exe loamUiPrototype06 where
  root := `Loam.Prototype.VerifiedTui06.Cli

lean_exe loamUiPrototype07 where
  root := `Loam.Prototype.VerifiedTui07.Cli

lean_exe loamUiPrototype09 where
  root := `Loam.Prototype.VerifiedTui09.Cli

lean_exe loamUiPrototype10 where
  root := `Loam.Prototype.VerifiedTui10.Cli

lean_exe loamUiPrototype11 where
  root := `Loam.Prototype.VerifiedTui11.Cli
