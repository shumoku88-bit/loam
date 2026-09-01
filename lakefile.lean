import Lake
open Lake DSL

package loam

@[default_target]
lean_lib Loam

lean_exe loam where
  root := `Loam.WriterCli

lean_exe loamShadowAudit where
  root := `Loam.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.ShadowQuantityCli
