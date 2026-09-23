import Loam.Cli.MovementProposalRecordCli

/-- Compatibility executable entry for Movement proposal publication. -/
def main (args : List String) : IO UInt32 :=
  Loam.MovementProposalRecordCli.run args
