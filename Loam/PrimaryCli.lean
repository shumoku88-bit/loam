import Loam.Cli
import Loam.ReviewCli

namespace Loam.PrimaryCli

set_option autoImplicit false

/--
Thin primary dispatcher for practical commands that have outgrown the original
single CLI module. Commands not named here retain the existing `Loam.Cli`
behavior unchanged.
-/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["review", memoryPath] => Loam.ReviewCli.reviewRememberedEvents memoryPath
  | _ => Loam.Cli.run args

end Loam.PrimaryCli

def main (args : List String) : IO UInt32 :=
  Loam.PrimaryCli.run args
