import Lake
open Lake DSL

package loam

@[default_target]
lean_lib Loam

lean_exe loam where
  root := `Loam.Cli

lean_exe loamMovement where
  root := `Loam.MovementCli

lean_exe loamCapacity where
  root := `Loam.CapacityCli

lean_exe loamScheduled where
  root := `Loam.ScheduledCli

lean_exe loamDailyQuantity where
  root := `Loam.DailyQuantityCli

lean_exe loamShadowAudit where
  root := `Loam.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.ShadowQuantityCli

lean_exe loamShadowDay where
  root := `Loam.ShadowDayCli

lean_exe loamShadowScheduledDay where
  root := `Loam.ShadowScheduledDayCli