import Loam.Application.BasisCut
import Loam.Persistence

namespace Loam.BasisCutPersistence

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Quantity-basis cut persistence

This tiny TSV relation records which Event correction roots are already reflected
by which quantity-basis correction roots:

```text
<basis-root-id><TAB><event-root-id>
```

The rows are durable application evidence because they affect current quantity.
They are not Events, Accounts, timestamps, or a replaceable view policy. Row
order has no chronology or authority meaning, and duplicate rows are harmless.
-/

private def decodeRow? (row : String) : Option BasisCutEntry :=
  match row.splitOn "\t" with
  | [basisToken, eventToken] =>
      if Loam.Persistence.validToken basisToken &&
          Loam.Persistence.validToken eventToken then
        some { basisRoot := ⟨basisToken⟩, eventRoot := ⟨eventToken⟩ }
      else
        none
  | _ => none

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

/-- Decode a complete basis-cut TSV image, failing closed on malformed rows. -/
def decode? (input : String) : Option BasisCut :=
  (dropOneTrailingEmpty (input.splitOn "\n")).mapM decodeRow?

/--
Load basis-cut evidence. A missing file means no Event occurrence has yet been
explicitly declared as already reflected by a quantity basis.
-/
def load? (path : System.FilePath) : IO (Option BasisCut) := do
  if ← path.pathExists then
    return decode? (← IO.FS.readFile path)
  else
    return some []

end Loam.BasisCutPersistence
