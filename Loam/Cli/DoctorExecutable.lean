import Loam.Cli.DoctorCli

/-- Compatibility executable entry for the standalone doctor target. -/
def main (args : List String) : IO UInt32 :=
  Loam.DoctorCli.run args
