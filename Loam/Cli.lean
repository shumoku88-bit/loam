import Loam.Core.Persistence
import Std

namespace Loam.Cli

set_option autoImplicit false

/-- Render one admitted runtime amount without inventing display metadata. -/
def renderAmount (amount : Loam.Core.SomeAmount) : String :=
  amount.measure.token ++ "\t" ++ toString amount.quantity.quanta

private def usage : String :=
  "usage:\n  loam amount show FILE\n  loam event quantity FILE LOCUS MEASURE"

/-- Read one persisted amount and print its stable measure token and exact quanta. -/
def showAmount (path : String) : IO UInt32 := do
  match ← Loam.Core.Persistence.load? (System.FilePath.mk path) with
  | some amount =>
      IO.println (renderAmount amount)
      return 0
  | none =>
      IO.eprintln "loam: malformed or unsupported amount file"
      return 2

/--
Read one persisted event and project exact quanta at an explicit locus/measure
coordinate. The source event remains detailed; this command only exposes the
read-only `Event.quantityAt` projection.
-/
def showEventQuantity
    (path : String) (locusToken : String) (measureToken : String) : IO UInt32 := do
  match ← Loam.Core.Persistence.loadEvent? (System.FilePath.mk path) with
  | some event =>
      let quantity := Loam.Core.Event.quantityAt event ⟨locusToken⟩ ⟨measureToken⟩
      IO.println (toString quantity.quanta)
      return 0
  | none =>
      IO.eprintln "loam: malformed or unsupported event file"
      return 2

/-- Command dispatcher for the practical CLI surface. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["amount", "show", path] => showAmount path
  | ["event", "quantity", path, locus, measure] =>
      showEventQuantity path locus measure
  | _ => do
      IO.eprintln usage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args
