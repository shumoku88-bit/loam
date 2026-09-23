import Loam.Cli.ScheduledRoutingCli

/-- Compatibility executable entry for scriptable Scheduled routing. -/
def main (args : List String) : IO UInt32 :=
  Loam.ScheduledRoutingCli.run args
