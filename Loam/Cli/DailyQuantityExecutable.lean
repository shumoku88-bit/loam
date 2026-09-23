import Loam.Cli.DailyQuantityCli

/-- Compatibility executable entry for explicit zero-origin quantity projections. -/
def main (args : List String) : IO UInt32 :=
  Loam.DailyQuantityCli.run args
