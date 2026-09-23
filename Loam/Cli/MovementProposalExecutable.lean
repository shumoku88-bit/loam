import Loam.Cli.MovementProposalCli

/-- Compatibility executable entry for Movement proposal review. -/
def main (args : List String) : IO UInt32 :=
  Loam.MovementProposalCli.run args
