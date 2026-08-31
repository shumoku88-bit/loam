import Loam.Core.EventCorrectionMemory
import Loam.Core.EventMemory
import Std

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Minimal persistence boundary

The first practical persisted value is one runtime `SomeAmount`: a stable
measure identity together with an exact signed quantity. Event persistence then
keeps one `EventId` and every detailed `Effect` intact so aggregate projections
can be recomputed after reload. Event-memory persistence keeps several Events
without turning their serialization order into semantic history. Correction-
memory persistence keeps raw explicit correction relations separately from the
Event stream and does not require their referenced Events to be present.

The text formats are deliberately tiny and versioned:

```text
LOAM-AMOUNT<TAB>1
<measure-token><TAB><signed-decimal-quanta>
```

```text
LOAM-EVENT<TAB>1
<event-token>
<effect-key><TAB><locus-token><TAB><measure-token><TAB><signed-decimal-quanta>
...
```

```text
LOAM-EVENT-MEMORY<TAB>1
EVENT<TAB><event-token>
EFFECT<TAB><effect-key><TAB><locus-token><TAB><measure-token><TAB><signed-decimal-quanta>
...
EVENT<TAB><event-token>
...
```

```text
LOAM-EVENT-CORRECTION-MEMORY<TAB>1
CORRECTION<TAB><correction-token><TAB><target-event-token><TAB><replacement-event-token>
...
```

Persisted identity tokens are opaque tokens, not display names. To keep these
first formats unambiguous without introducing an escaping layer, the
persistence boundary admits only nonempty tokens without tab or line-break
characters.

Event row order, Event-memory block order, and Correction-memory row order
preserve the current practical representation only; none acquires temporal,
causal, priority, authority, debit/credit, or posting-order meaning.

Event-memory and Correction-memory publication first write the complete encoded
representation to a sibling staging path and only then replace the target with
a filesystem rename. Thus the target path is not truncated while a new
representation is still being written. Each target is an atomic publication
boundary where the underlying rename has replacement atomicity; this is not a
cross-stream transaction, concurrent-writer lock, or power-loss durability
guarantee, and an interrupted process may leave the staging file.

Filesystem failures remain ordinary `IO` exceptions. Malformed or unsupported
file contents return `none` from the relevant decode/load boundary.
-/

/-- Version marker for the first persisted LOAM amount format. -/
def amountHeader : String := "LOAM-AMOUNT\t1"

/-- Version marker for the first persisted LOAM event format. -/
def eventHeader : String := "LOAM-EVENT\t1"

/-- Version marker for the first persisted multi-Event memory format. -/
def eventMemoryHeader : String := "LOAM-EVENT-MEMORY\t1"

/-- Version marker for the first persisted raw Event-correction memory format. -/
def eventCorrectionMemoryHeader : String := "LOAM-EVENT-CORRECTION-MEMORY\t1"

/-- Whether one opaque identity token is representable by the first text formats. -/
def validToken (token : String) : Bool :=
  !token.isEmpty &&
    !token.contains '\t' &&
    !token.contains '\n' &&
    !token.contains '\r'

/-- Compatibility name for the original amount persistence boundary. -/
def validMeasureToken (token : String) : Bool :=
  validToken token

/-- Encode one runtime amount without changing its exact quanta. -/
def encode? (amount : SomeAmount) : Option String :=
  let token := amount.measure.token
  if validMeasureToken token then
    some (amountHeader ++ "\n" ++ token ++ "\t" ++
      toString amount.quantity.quanta ++ "\n")
  else
    none

/-- Decode one amount from the exact version-1 text shape. -/
def decode? (input : String) : Option SomeAmount :=
  match input.splitOn "\n" with
  | [header, row, trailing] =>
      if header = amountHeader then
        if trailing = "" then
          match row.splitOn "\t" with
          | [token, quantaText] =>
              if validMeasureToken token then
                match quantaText.toInt? with
                | some quanta =>
                    some (SomeAmount.ofQuantity
                      ⟨token⟩ (Quantity.ofQuanta quanta))
                | none => none
              else
                none
          | _ => none
        else
          none
      else
        none
  | _ => none

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
    | some rows =>
        some (String.intercalate "\n" ([eventHeader, event.id.token] ++ rows) ++ "\n")
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
  | some blocks =>
      some (String.intercalate "\n" (eventMemoryHeader :: blocks.flatten) ++ "\n")
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

/-- Encode one raw Event-correction row without checking Event availability. -/
private def encodeEventCorrectionRow? (correction : EventCorrection) : Option String :=
  let correctionToken := correction.id.token
  let targetToken := correction.target.token
  let replacementToken := correction.replacement.token
  if validToken correctionToken && validToken targetToken && validToken replacementToken then
    some ("CORRECTION\t" ++ correctionToken ++ "\t" ++ targetToken ++ "\t" ++ replacementToken)
  else
    none

/-- Decode one raw Event-correction row without performing referential admission. -/
private def decodeEventCorrectionRow? (row : String) : Option EventCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", correctionToken, targetToken, replacementToken] =>
      if validToken correctionToken && validToken targetToken && validToken replacementToken then
        some {
          id := ⟨correctionToken⟩
          target := ⟨targetToken⟩
          replacement := ⟨replacementToken⟩
        }
      else
        none
  | _ => none

/--
Encode raw correction memory as its own physical stream.

Correction row order is deterministic representation only. Referenced Event
identity is preserved even when an endpoint is not present in any current
`EventMemory`; referential admission remains a later Core projection.
-/
def encodeEventCorrectionMemory? (memory : EventCorrectionMemory) : Option String :=
  match memory.corrections.mapM encodeEventCorrectionRow? with
  | some rows =>
      some (String.intercalate "\n" (eventCorrectionMemoryHeader :: rows) ++ "\n")
  | none => none

/--
Decode one version-1 raw correction memory. Repeated `EventCorrectionId` is
rejected through `EventCorrectionMemory.ofCorrections?`; missing target or
replacement Events are deliberately not checked at this persistence boundary.
-/
def decodeEventCorrectionMemory? (input : String) : Option EventCorrectionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = eventCorrectionMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows =>
            match reversedRows.reverse.mapM decodeEventCorrectionRow? with
            | some corrections => EventCorrectionMemory.ofCorrections? corrections
            | none => none
        | _ => none
      else
        none
  | _ => none

/--
Write one amount to a UTF-8 file when its measure token is admitted by the
format. Returns `false` only for an unrepresentable token; filesystem failures
remain `IO` exceptions.
-/
def save? (path : System.FilePath) (amount : SomeAmount) : IO Bool := do
  match encode? amount with
  | some text =>
      IO.FS.writeFile path text
      return true
  | none =>
      return false

/--
Read and decode one UTF-8 amount file. Malformed contents return `none`;
filesystem failures remain `IO` exceptions.
-/
def load? (path : System.FilePath) : IO (Option SomeAmount) := do
  let input ← IO.FS.readFile path
  return decode? input

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

/-- Sibling staging path reserved for Event-memory publication. -/
private def eventMemoryStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

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
      let stagePath := eventMemoryStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
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

/-- Sibling staging path reserved for raw Event-correction-memory publication. -/
private def eventCorrectionMemoryStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/--
Publish one raw Event-correction memory as one independently replaced stream.

This helper deliberately knows nothing about the Event stream. Callers that
coordinate both streams must preserve the observed relation-first publication
protocol themselves. This function does not create a cross-stream transaction,
serialize concurrent writers, or claim power-loss durability.
-/
def saveEventCorrectionMemory?
    (path : System.FilePath)
    (memory : EventCorrectionMemory) : IO Bool := do
  match encodeEventCorrectionMemory? memory with
  | some text =>
      let stagePath := eventCorrectionMemoryStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true
  | none =>
      return false

/--
Read and decode one raw Event-correction-memory file. Missing Event endpoints do
not make the raw relation stream malformed; referential admission remains a
separate Core operation.
-/
def loadEventCorrectionMemory?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  let input ← IO.FS.readFile path
  return decodeEventCorrectionMemory? input

end Loam.Persistence
