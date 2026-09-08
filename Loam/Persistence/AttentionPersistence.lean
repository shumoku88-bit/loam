import Loam.ActualDate
import Loam.Core.AttentionMemory
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.SiblingStage

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Attention persistence

This is a serialization boundary for the already-qualified Attention family.
It does not add lifecycle meaning, priority, taxonomy, or ordering semantics.

Version 1 stores retained Attention items and explicit closure evidence in one
complete image:

```text
LOAM-ATTENTION-MEMORY<TAB>1
ITEM<TAB><id><TAB>DUE_ON<TAB><yyyy-mm-dd><TAB><escaped-context>
ITEM<TAB><id><TAB>NO_DUE_DATE<TAB>-<TAB><escaped-context>
ITEM<TAB><id><TAB>DUE_UNDETERMINED<TAB>-<TAB><escaped-context>
CLOSE<TAB><id><TAB><known-on><TAB>RESOLVED|DROPPED
```

Row order is representation only. Referential closure validation remains the
shared Application inspection boundary rather than being invented here.
-/

/-- Version marker for the first complete Attention evidence stream. -/
def attentionMemoryHeader : String := "LOAM-ATTENTION-MEMORY\t1"

private def encodeAttentionRow? (item : Attention String) : Option String :=
  if !validToken item.id.token then
    none
  else
    let context := escapeText item.context
    match item.due with
    | .dueOn time =>
        if Loam.ActualDate.validIsoDate time then
          some ("ITEM\t" ++ item.id.token ++ "\tDUE_ON\t" ++ time ++ "\t" ++ context)
        else
          none
    | .noDueDate =>
        some ("ITEM\t" ++ item.id.token ++ "\tNO_DUE_DATE\t-\t" ++ context)
    | .dueUndetermined =>
        some ("ITEM\t" ++ item.id.token ++ "\tDUE_UNDETERMINED\t-\t" ++ context)

private def encodeClosureRow? (closure : AttentionClosure String) : Option String :=
  if !validToken closure.attention.token || !Loam.ActualDate.validIsoDate closure.knownOn then
    none
  else
    let kind := match closure.kind with
      | .resolved => "RESOLVED"
      | .dropped => "DROPPED"
    some ("CLOSE\t" ++ closure.attention.token ++ "\t" ++ closure.knownOn ++ "\t" ++ kind)

/-- Encode one complete Attention image without giving row order household meaning. -/
def encodeAttentionMemory?
    (items : AttentionMemory String)
    (closures : AttentionClosureMemory String) : Option String := do
  let itemRows ← items.items.mapM encodeAttentionRow?
  let closureRows ← closures.closures.mapM encodeClosureRow?
  pure (String.intercalate "\n" (attentionMemoryHeader :: itemRows ++ closureRows) ++ "\n")

private def decodeAttentionRow? (row : String) : Option (Attention String) :=
  match row.splitOn "\t" with
  | ["ITEM", idToken, dueKind, timeText, escapedContext] =>
      if !validToken idToken then
        none
      else do
        let context ← unescapeText? escapedContext
        let due ←
          match dueKind with
          | "DUE_ON" =>
              if Loam.ActualDate.validIsoDate timeText then
                some (AttentionDue.dueOn timeText)
              else
                none
          | "NO_DUE_DATE" =>
              if timeText = "-" then some AttentionDue.noDueDate else none
          | "DUE_UNDETERMINED" =>
              if timeText = "-" then some AttentionDue.dueUndetermined else none
          | _ => none
        pure { id := ⟨idToken⟩, context := context, due := due }
  | _ => none

private def decodeClosureRow? (row : String) : Option (AttentionClosure String) :=
  match row.splitOn "\t" with
  | ["CLOSE", idToken, knownOn, kindText] =>
      if !validToken idToken || !Loam.ActualDate.validIsoDate knownOn then
        none
      else
        match kindText with
        | "RESOLVED" => some { attention := ⟨idToken⟩, knownOn := knownOn, kind := .resolved }
        | "DROPPED" => some { attention := ⟨idToken⟩, knownOn := knownOn, kind := .dropped }
        | _ => none
  | _ => none

private def decodeRows :
    List String → Option (List (Attention String) × List (AttentionClosure String))
  | [] => some ([], [])
  | row :: rest => do
      let (items, closures) ← decodeRows rest
      if row.startsWith "ITEM\t" then
        let item ← decodeAttentionRow? row
        pure (item :: items, closures)
      else if row.startsWith "CLOSE\t" then
        let closure ← decodeClosureRow? row
        pure (items, closure :: closures)
      else
        none

/-- Decode version 1 and re-admit identity/one-closure uniqueness fail-closed. -/
def decodeAttentionMemory?
    (input : String) : Option (AttentionMemory String × AttentionClosureMemory String) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header != attentionMemoryHeader then
        none
      else
        match rows.reverse with
        | "" :: reversedRows => do
            let (rawItems, rawClosures) ← decodeRows reversedRows.reverse
            let items ← AttentionMemory.ofItems? rawItems
            let closures ← AttentionClosureMemory.ofClosures? rawClosures
            pure (items, closures)
        | _ => none
  | _ => none

/-- Publish one complete Attention image by sibling staging plus rename. -/
def saveAttentionMemory?
    (path : System.FilePath)
    (items : AttentionMemory String)
    (closures : AttentionClosureMemory String) : IO Bool := do
  match encodeAttentionMemory? items closures with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

/-- Read and fail-closed decode one configured Attention stream. -/
def loadAttentionMemory?
    (path : System.FilePath) : IO (Option (AttentionMemory String × AttentionClosureMemory String)) := do
  let input ← IO.FS.readFile path
  return decodeAttentionMemory? input

end Loam.Persistence
