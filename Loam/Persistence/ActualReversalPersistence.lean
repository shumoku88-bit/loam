import Loam.Core.ActualReversal
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Actual reversal persistence

The file is one complete image of explicit target -> reversal provenance:

```text
LOAM-ACTUAL-REVERSAL-MEMORY<TAB>1
REVERSE<TAB><target-event-id><TAB><reversal-event-id>
```

Row order carries no household meaning. Physical inverse validation and endpoint
presence are intentionally not serialization rules: relation-first interrupted
publication may retain a single relation whose reversal Event has not yet become
selected Movement authority.
-/

def actualReversalMemoryHeader : String := "LOAM-ACTUAL-REVERSAL-MEMORY\t1"

private def encodeRow? (relation : ActualReversal) : Option String :=
  if !validToken relation.target.token || !validToken relation.reversal.token ||
      relation.target = relation.reversal then
    none
  else
    some ("REVERSE\t" ++ relation.target.token ++ "\t" ++ relation.reversal.token)

/-- Encode one complete reversal authority image. -/
def encodeActualReversalMemory? (memory : ActualReversalMemory) : Option String := do
  let rows ← memory.reversals.mapM encodeRow?
  pure (String.intercalate "\n" (actualReversalMemoryHeader :: rows) ++ "\n")

private def decodeRow? (row : String) : Option ActualReversal :=
  match row.splitOn "\t" with
  | ["REVERSE", target, reversal] =>
      if !validToken target || !validToken reversal || target = reversal then
        none
      else
        some { target := ⟨target⟩, reversal := ⟨reversal⟩ }
  | _ => none

/-- Decode version 1 and re-admit endpoint uniqueness fail-closed. -/
def decodeActualReversalMemory? (input : String) : Option ActualReversalMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != actualReversalMemoryHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => do
            let relations ← reversedRows.reverse.mapM decodeRow?
            ActualReversalMemory.ofReversals? relations
        | _ => none
  | _ => none

private def stagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish a complete reversal image by sibling staging plus rename. -/
def saveActualReversalMemory?
    (path : System.FilePath) (memory : ActualReversalMemory) : IO Bool := do
  match encodeActualReversalMemory? memory with
  | none => return false
  | some text =>
      let stage := stagePath path
      IO.FS.writeFile stage text
      IO.FS.rename stage path
      return true

/-- Read one configured complete reversal authority image. -/
def loadActualReversalMemory?
    (path : System.FilePath) : IO (Option ActualReversalMemory) := do
  let input ← IO.FS.readFile path
  return decodeActualReversalMemory? input

end Loam.Persistence
