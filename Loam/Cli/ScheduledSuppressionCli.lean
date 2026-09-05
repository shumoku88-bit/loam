import Loam.Cli.ScheduledBalanceCli

set_option autoImplicit false

def main (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, endExclusive, scheduledId] =>
      Loam.ScheduledBalanceCli.reportSuppression rootPath endExclusive scheduledId
  | _ => do
      IO.eprintln
        "Usage: loamScheduledSuppression DATA_ROOT END_EXCLUSIVE SCHEDULED_ID"
      return 2
