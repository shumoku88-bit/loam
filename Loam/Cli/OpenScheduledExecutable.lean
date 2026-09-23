import Loam.Cli.OpenScheduledCli

/-- Compatibility executable entry for current-open Scheduled inspection. -/
def main (args : List String) : IO UInt32 :=
  Loam.OpenScheduledCli.run args
