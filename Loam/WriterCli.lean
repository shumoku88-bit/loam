import Loam.Cli
import Loam.WriterOwnership

namespace Loam.WriterCli

set_option autoImplicit false

/-!
# Ownership-aware production CLI

`Loam.Cli` retains the human-facing command implementations. This executable
boundary adds process-level ownership only around commands that perform a
read/prepare/admit/publish writer operation against EventMemory.

The writer abstraction is deliberately not named after a household action such
as `spend`. `spend` remains an interface verb. The common protected operation is
publication from an observed canonical state.
-/

private def withMemoryOwnership
    (memoryPath : String)
    (action : IO UInt32) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership (System.FilePath.mk memoryPath) action

/--
Dispatch production writer entrances through one EventMemory-anchored ownership
scope. All read-only and single-object commands continue through `Loam.Cli.run`
unchanged.

For correction, the same EventMemory anchor spans the complete existing
relation-first protocol inside `correctSpend`: Correction publication first,
then Event publication, then ownership release.
-/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["spend", memoryPath] =>
      withMemoryOwnership memoryPath (Loam.Cli.spendJpy memoryPath)
  | ["correct", memoryPath, correctionPath] =>
      withMemoryOwnership memoryPath
        (Loam.CorrectionCli.correctSpend memoryPath correctionPath)
  | ["event-memory", "add", memoryPath, eventPath] =>
      withMemoryOwnership memoryPath
        (Loam.Cli.addRememberedEvent memoryPath eventPath)
  | _ =>
      Loam.Cli.run args

end Loam.WriterCli

def main (args : List String) : IO UInt32 :=
  Loam.WriterCli.run args
