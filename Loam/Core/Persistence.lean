import Loam.Core.Event
import Std

namespace Loam.Core

set_option autoImplicit false

/-!
# Minimal persistence boundary

The first practical persisted value is one runtime `SomeAmount`: a stable
measure identity together with an exact signed quantity. Event persistence then
keeps one `EventId` and every detailed `Effect` intact so aggregate projections
can be recomputed after reload.

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

Persisted identity tokens are opaque tokens, not display names. To keep these
first formats unambiguous without introducing an escaping layer, the
persistence boundary admits only nonempty tokens without tab or line-break
characters.

Event row order preserves the current practical representation only; it does
not acquire temporal, causal, priority, debit/credit, or posting-order meaning.

Filesystem failures remain ordinary `IO` exceptions. Malformed or unsupported
file contents return `none` from the relevant decode/load boundary.
-/

namespace Persistence

/-- Version marker for the first persisted LOAM amount format. -/
def amountHeader : String := "LOAM-AMOUNT\t1"

/-- Version marker for the first persisted LOAM event format. -/
def eventHeader : String := "LOAM-EVENT\t1"

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

/-- Decode one event effect row without assigning meaning to its sign or position. -/
private def decodeEffectRow? (row : String) : Option Effect :=
  match row.splitOn "\t" with
  | [keyToken, locusToken, measureToken, quantaText] =>
      if validToken keyToken && validToken locusToken && validToken measureToken then
        match quantaText.toInt? with
        | some quanta =>
            some (Effect.ofQuantity
              ⟨keyToken⟩ ⟨locusToken⟩ ⟨measureToken⟩
              (Quantity.ofQuanta quanta))
        | none => none
      else
        none
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

end Persistence

end Loam.Core
