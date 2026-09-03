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

lean_exe loamDailyQuantity where
  root := `Loam.Cli.DailyQuantityCli

lean_exe loamOpenScheduled where
  root := `Loam.Cli.OpenScheduledCli

lean_exe loamShadowAudit where
  root := `Loam.Cli.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.Cli.ShadowQuantityCli

lean_exe loamShadowDay where
  root := `Loam.Cli.ShadowDayCli

lean_exe loamShadowScheduledDay where
  root := `Loam.Cli.ShadowScheduledDayCli

lean_exe loamHistoricalPrepare where
  root := `Loam.Cli.HistoricalPrepareCli

lean_exe loamHistoricalPublish where
  root := `Loam.Cli.HistoricalPublishCli
