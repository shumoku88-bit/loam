import Loam.Cli.HouseholdObservation

/-- Compatibility executable entry for the standalone Household Observation target. -/
def main (args : List String) : IO UInt32 :=
  Loam.HouseholdObservationCli.run args
