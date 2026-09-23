import Loam.Cli.ActualRoutingCli

/-- Compatibility executable entry for scriptable Actual routing. -/
def main (args : List String) : IO UInt32 :=
  Loam.ActualRoutingCli.run args
