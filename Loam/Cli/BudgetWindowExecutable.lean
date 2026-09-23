import Loam.Cli.BudgetWindowCli

/-- Compatibility executable entry for the Budget Window projection. -/
def main (args : List String) : IO UInt32 :=
  Loam.BudgetWindowCli.run args
