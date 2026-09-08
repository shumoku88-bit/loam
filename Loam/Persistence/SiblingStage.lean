import Std

namespace Loam.Persistence

set_option autoImplicit false

/-!
# Sibling staged text replacement

This module owns only the shared physical operation of writing a complete text
candidate to the reserved sibling `.loam-stage` path and then renaming it over
the target. It is not a transaction, lock, recovery log, or durability claim.
Callers remain responsible for semantic admission and any stronger staged
verification protocol.
-/

/-- Replace one text target through its reserved sibling staging path. -/
def replaceTextViaSiblingStage
    (target : System.FilePath) (text : String) : IO Unit := do
  let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  IO.FS.rename stage target

end Loam.Persistence
