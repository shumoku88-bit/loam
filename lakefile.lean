import Lake
open Lake DSL

package loam where
  moreLinkObjs := #[`@/terminalNative]
  testDriver := "loamTests"

-- The terminal needs short POSIX reads and ioctl geometry, not buffered stdio
-- or a subprocess per key. This object contains no household semantics.
target terminalNative pkg : System.FilePath := do
  let src ← inputFile (pkg.dir / "Loam" / "Tui" / "terminal_native.c") true
  let lean ← getLeanInstall
  let obj ← buildO (pkg.buildDir / "native" / "terminal_native.o") src
    #["-I", lean.includeDir.toString] #["-O2", "-fPIC"]
  buildStaticLib (pkg.buildDir / "native" / nameToStaticLib "loam_terminal") #[obj]

lean_exe terminalProbe where
  root := `tests.TerminalProbe

lean_exe loamTests where
  root := `tests.TestDriver

@[default_target]
lean_lib Loam

lean_exe loam where
  root := `Loam.Cli

lean_exe loamMovementProposal where
  root := `Loam.Cli.MovementProposalExecutable

lean_exe loamMovementProposalRecord where
  root := `Loam.Cli.MovementProposalRecordExecutable

lean_exe loamScheduledSuppression where
  root := `Loam.Cli.ScheduledSuppressionCli

lean_exe loamBeancountExport where
  root := `Loam.Cli.BeancountExportExecutable

lean_exe loamShadowAudit where
  root := `Loam.Cli.ShadowAuditCli

lean_exe loamShadowQuantity where
  root := `Loam.Cli.ShadowQuantityCli

lean_exe loamHouseholdObservation where
  root := `Loam.Cli.HouseholdObservationCli

lean_exe loamTui where
  root := `Loam.Tui.Executable

lean_exe loamAttention where
  root := `Loam.Tui.AttentionMain

lean_exe loamMemory where
  root := `Loam.Cli.PersonalMemoryCli
