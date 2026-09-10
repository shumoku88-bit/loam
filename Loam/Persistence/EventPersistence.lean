import Loam.Core.EventMemory
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows
import Std

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Event persistence

This module owns the versioned wire representations for one `Event` and for an
`EventMemory`. Event-memory serialization order remains deterministic
representation only and acquires no temporal, causal, priority, authority,
debit/credit, or posting-order meaning.

Persisted identity tokens are opaque tokens, not display names. The format
admits only nonempty tokens without tab or line-break characters.
-/

/-- Version marker for the first persisted LOAM event format. -/
def eventHeader : String := "LOAM-EVENT\t1"

/-- Version marker for the first persisted multi-Event memory format. -/
def eventMemoryHeader : String := "LOAM-EVENT-MEMORY\t1"

/-- Encode one event effect row while preserving every explicit coordinate. -/
private def encodeEffectRow? (effect : Effect) : Option String :=
  let key := effect.key.token
  let locus := effect.locus.token
  let measure := effect.measure.token
  if validToken key && validToken locus && validToken measure then
    some (key ++ "\t" ++ locus ++ "\t" ++ measure ++ "\t" ++
      toString effect.quantity.quanta)
  else
    none

/-- Decode one event effect from already separated text fields. -/
private def decodeEffectFields?
    (keyToken locusToken measureToken quantaText : String) : Option Effect :=
  if validToken keyToken && validToken locusToken && validToken measureToken then
    match quantaText.toInt? with
    | some quanta =>
        some (Effect.ofQuantity
          ⟨keyToken⟩ ⟨locusToken⟩ ⟨measureToken⟩
          (Quantity.ofQuanta quanta))
    | none => none
  else
    none

/-- Decode one event effect row without assigning meaning to its sign or position. -/
private def decodeEffectRow? (row : String) : Option Effect :=
  match row.splitOn "\t" with
  | [keyToken, locusToken, measureToken, quantaText] =>
      decodeEffectFields? keyToken locusToken measureToken quantaText
  | _ => none

/--
Encode one event with its stable event identity and every detailed effect.
Distinct effect identity is retained even when several effects share one
locus/measure projection coordinate.
-/
def encodeEvent? (event : Event) : Option String :=
  if validToken event.id.token then
    match event.effects.mapM encodeEffectRow? with
    | some rows => some (encodeVersionedRows eventHeader (event.id.token :: rows))
    | none => none
  else
    none

/--
Decode one version-1 event and re-admit its effect collection through
`Event.ofEffects?`. Duplicate effect keys therefore fail closed instead of
silently collapsing or overwriting detail.
-/
def decodeEvent? (input : String) : Option Event :=
  match input.splitOn "\n" with
  | header :: eventToken :: rows =>
      if header = eventHeader && validToken eventToken then
        match rows.reverse with
        | "" :: reversedEffectRows =>
            match reversedEffectRows.reverse.mapM decodeEffectRow? with
            | some effects => Event.ofEffects? ⟨eventToken⟩ effects
            | none => none
        | _ => none
      else
        none
  | _ => none

/-- Encode one Event as tagged lines inside Event-memory persistence. -/
private def encodeMemoryEventLines? (event : Event) : Option (List String) :=
  if validToken event.id.token then
    match event.effects.mapM encodeEffectRow? with
    | some rows =>
        some (("EVENT\t" ++ event.id.token) ::
          rows.map (fun row => "EFFECT\t" ++ row))
    | none => none
  else
    none

/-- Decode one tagged Effect row from Event-memory persistence. -/
private def decodeMemoryEffectRow? (row : String) : Option Effect :=
  match row.splitOn "\t" with
  | ["EFFECT", keyToken, locusToken, measureToken, quantaText] =>
      decodeEffectFields? keyToken locusToken measureToken quantaText
  | _ => none

/-- Remove the optional final empty row left by a trailing newline in one chunk. -/
private def withoutTrailingEmpty (rows : List String) : List String :=
  match rows.reverse with
  | "" :: rest => rest.reverse
  | _ => rows

/-- Decode one Event chunk after its leading `EVENT<TAB>` marker was removed. -/
private def decodeMemoryEventChunk? (chunk : String) : Option Event :=
  match chunk.splitOn "\n" with
  | eventToken :: rawRows =>
      if validToken eventToken then
        match (withoutTrailingEmpty rawRows).mapM decodeMemoryEffectRow? with
        | some effects => Event.ofEffects? ⟨eventToken⟩ effects
        | none => none
      else
        none
  | _ => none

/--
Encode several Events without giving their serialization order domain meaning.
Event identity remains explicit and is already unique by `EventMemory` law.
-/
def encodeEventMemory? (memory : EventMemory) : Option String :=
  match memory.events.mapM encodeMemoryEventLines? with
  | some blocks => some (encodeVersionedRows eventMemoryHeader blocks.flatten)
  | none => none

/--
Decode one version-1 Event memory. The final `EventMemory.ofEvents?` admission
rejects repeated Event identity rather than treating repeated blocks as
multiplicity. Block order is retained only for deterministic round-trip.
-/
def decodeEventMemory? (input : String) : Option EventMemory :=
  if input = eventMemoryHeader ++ "\n" then
    EventMemory.ofEvents? []
  else
    match (input.splitOn "\n").reverse with
    | "" :: _ =>
        match input.splitOn "\nEVENT\t" with
        | header :: chunks =>
            if header = eventMemoryHeader then
              match chunks with
              | [] => none
              | _ =>
                  match chunks.mapM decodeMemoryEventChunk? with
                  | some events => EventMemory.ofEvents? events
                  | none => none
            else
              none
        | _ => none
    | _ => none

/--
Write one event to a UTF-8 file when every persisted identity token is admitted
by the format. Filesystem failures remain `IO` exceptions.
-/
def saveEvent? (path : System.FilePath) (event : Event) : IO Bool := do
  match encodeEvent? event with
  | some text =>
      IO.FS.writeFile path text
      return true
  | none =>
      return false

/--
Read and decode one UTF-8 event file. Malformed contents, unsupported versions,
and duplicate effect keys return `none`; filesystem failures remain `IO`
exceptions.
-/
def loadEvent? (path : System.FilePath) : IO (Option Event) := do
  let input ← IO.FS.readFile path
  return decodeEvent? input

/--
Publish one Event memory when every contained Event is representable.

The complete encoded representation is written to a sibling staging path before
`IO.FS.rename` replaces the target. For ordinary file targets this keeps staging
and target on the same filesystem and prevents a partially written new memory
from appearing at the target path before replacement. Event order remains
deterministic representation only.

This does not serialize concurrent writers and does not claim power-loss
durability. A process interrupted before rename may leave the staging file;
the next publication overwrites that reserved staging path.
-/
def saveEventMemory? (path : System.FilePath) (memory : EventMemory) : IO Bool := do
  match encodeEventMemory? memory with
  | some text =>
      replaceTextViaSiblingStage path text
      return true
  | none =>
      return false

/--
Read and decode one Event-memory file. Malformed contents, unsupported versions,
duplicate Effect keys, and duplicate Event identity return `none`; filesystem
failures remain `IO` exceptions.
-/
def loadEventMemory? (path : System.FilePath) : IO (Option EventMemory) := do
  let input ← IO.FS.readFile path
  return decodeEventMemory? input

end Loam.Persistence
