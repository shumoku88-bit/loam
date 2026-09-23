import Loam.Cli.BeancountExportCli

/-- Compatibility executable entry for Beancount export. -/
def main (args : List String) : IO UInt32 :=
  Loam.BeancountExportCli.run args
