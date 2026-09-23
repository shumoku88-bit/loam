import Loam.Cli.JournalExportCli

/-- Compatibility executable entry for readable Actual journal export. -/
def main (args : List String) : IO UInt32 :=
  Loam.JournalExportCli.run args
