import Loam.Core.ActualReversal
import Loam.Persistence.TokenSyntax
import Loam.Persistence.SiblingStage
import Loam.Persistence.VersionedRows

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
  pure (encodeVersionedRows actualReversalMemoryHeader rows)

private def decodeRow? (row : String) : Option ActualReversal :=
  match row.splitOn "\t" with
  | ["REVERSE", target, reversal] =>
      if !validToken target || !validToken reversal || target = reversal then
        none
      else
        some { target := ⟨target⟩, reversal := ⟨reversal⟩ }
  | _ => none

/-- Decode version 1 and re-admit endpoint uniqueness fail-closed. -/
def decodeActualReversalMemory? (input : String) : Option ActualReversalMemory := do
  let rows ← decodeVersionedRows? actualReversalMemoryHeader input
  let relations ← rows.mapM decodeRow?
  ActualReversalMemory.ofReversals? relations

/-- Publish a complete reversal image by sibling staging plus rename. -/
def saveActualReversalMemory?
    (path : System.FilePath) (memory : ActualReversalMemory) : IO Bool := do
  match encodeActualReversalMemory? memory with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read one configured complete reversal authority image. -/
def loadActualReversalMemory?
    (path : System.FilePath) : IO (Option ActualReversalMemory) := do
  let input ← IO.FS.readFile path
  return decodeActualReversalMemory? input

end Loam.Persistence
