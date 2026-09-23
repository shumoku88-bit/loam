import Loam.Cli.CapacityCli

/-- Compatibility executable entry for Capacity recording and inspection. -/
def main (args : List String) : IO UInt32 :=
  Loam.CapacityCli.run args
