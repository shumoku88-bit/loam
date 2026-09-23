import Loam.Cli.PlainTextAccountingExportCli

/-- Compatibility executable entry for Plain Text Accounting export. -/
def main (args : List String) : IO UInt32 :=
  Loam.PlainTextAccountingExportCli.run args
