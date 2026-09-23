import Loam.Cli.MovementCli

/-- Compatibility executable entry for the standalone movement target. -/
def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
