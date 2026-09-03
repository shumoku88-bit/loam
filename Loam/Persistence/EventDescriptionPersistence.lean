import Loam.Core.EventDescription
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Minimal Event-scoped description persistence

Stores human recognition text associated with Events in an adjacent stream:
`<memoryPath>.descriptions`

Wire format (version 1):
```text
LOAM-EVENT-DESCRIPTION-MEMORY<TAB>1
DESC<TAB><event-token><TAB><escaped-text>
...
```

Escaping rules:
- Backslash `\` is escaped as `\\`
- Tab `\t` is escaped as `\t`
- Newline `\n` is escaped as `\n`
- Carriage return `\r` is escaped as `\r`
- All other Unicode characters, spaces, punctuation, quotes are preserved verbatim.
- Invalid escape sequences or dangling trailing backslashes fail closed (`none`).

Invariants:
- Unknown header or version returns `none`.
- Missing trailing newline or malformed row structure returns `none`.
- Duplicate `EventId` within the stream returns `none`.
- EventId tokens must satisfy `validToken` (no whitespace/tabs/newlines).
-/

/-- Version marker for Event-description persistence. -/
def eventDescriptionMemoryHeader : String := "LOAM-EVENT-DESCRIPTION-MEMORY\t1"

/--
Path convention placing Event descriptions adjacent to their Event memory.
-/
def eventDescriptionPathForEventMemory (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".descriptions")

/--
Escape text for single-line tab-separated persistence.
Escapes `\`, `\n`, `\r`, `\t`.
-/
def escapeText (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '\n' => acc ++ "\\n"
    | '\r' => acc ++ "\\r"
    | '\t' => acc ++ "\\t"
    | other => acc.push other) ""

/--
Decode escaped text.
Returns `none` if an unrecognized escape sequence or dangling trailing backslash is found.
-/
def unescapeText? (s : String) : Option String :=
  let rec loop (chars : List Char) (acc : String) : Option String :=
    match chars with
    | [] => some acc
    | '\\' :: next :: rest =>
        match next with
        | '\\' => loop rest (acc.push '\\')
        | 'n'  => loop rest (acc.push '\n')
        | 'r'  => loop rest (acc.push '\r')
        | 't'  => loop rest (acc.push '\t')
        | _    => none
    | '\\' :: [] => none
    | c :: rest => loop rest (acc.push c)
  loop s.toList ""

private def encodeDescriptionRow? (desc : EventDescription) : Option String :=
  if validToken desc.event.token then
    some ("DESC\t" ++ desc.event.token ++ "\t" ++ escapeText desc.text)
  else
    none

/--
Encode one Event-description memory as single-image text representation.
Row order preserves representation order only.
-/
def encodeEventDescriptionMemory? (memory : EventDescriptionMemory) : Option String := do
  let rows ← memory.entries.mapM encodeDescriptionRow?
  pure (String.intercalate "\n" (eventDescriptionMemoryHeader :: rows) ++ "\n")

private def decodeDescriptionRows : List String → Option (List EventDescription)
  | [] => some []
  | row :: rest => do
      let entries ← decodeDescriptionRows rest
      match row.splitOn "\t" with
      | ["DESC", eventToken, escapedText] =>
          if validToken eventToken then
            match unescapeText? escapedText with
            | some text => pure ({ event := ⟨eventToken⟩, text := text } :: entries)
            | none => none
          else
            none
      | _ => none

/--
Decode Event-description memory from its version-1 text representation.
Fails closed (`none`) on malformed headers, malformed escapes, invalid tokens,
or duplicate EventIds.
-/
def decodeEventDescriptionMemory? (input : String) : Option EventDescriptionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = eventDescriptionMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => do
            let entries ← decodeDescriptionRows reversedRows.reverse
            EventDescriptionMemory.ofEntries? entries
        | _ => none
      else
        none
  | _ => none

private def eventDescriptionStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/--
Publish one Event-description memory using sibling staging and atomic filesystem replace.
-/
def saveEventDescriptionMemory?
    (path : System.FilePath)
    (memory : EventDescriptionMemory) : IO Bool := do
  match encodeEventDescriptionMemory? memory with
  | some text =>
      let stagePath := eventDescriptionStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      pure true
  | none => pure false

/--
Load and decode one Event-description memory file.
Returns `none` if the file is malformed, has duplicate EventIds, or unsupported version.
-/
def loadEventDescriptionMemory?
    (path : System.FilePath) : IO (Option EventDescriptionMemory) := do
  let input ← IO.FS.readFile path
  pure (decodeEventDescriptionMemory? input)

end Loam.Persistence
