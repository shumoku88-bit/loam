import Loam.Core.Event
import Loam.MovementAdmission
import Loam.Cli.Movement.RelationEntry
import Loam.Cli.Movement.DischargeEntry
import Loam.Persistence.TokenSyntax

namespace Loam.MovementProposal

open Loam.Core

set_option autoImplicit false

/-!
# Movement proposal transport

This module parses one small, line-oriented transport into the existing
`MovementAdmission.Draft`. It does not introduce imported transaction identity,
source continuity, publication authority, or a second Movement semantics.

Version 1 is intentionally inspectable by both humans and agents:

```text
LOAM-MOVEMENT-PROPOSAL<TAB>1
date<TAB>YYYY-MM-DD
description<TAB>optional recognition text
effect<TAB>-|EFFECT_KEY<TAB>LOCUS<TAB>MEASURE<TAB>SIGNED_QUANTA
relation<TAB>EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY
discharge<TAB>RELATION_ID<TAB>POSITIVE_QUANTITY
```

`-` means an anonymous Effect. A stable EffectKey is needed only when explicit
relation evidence refers to that Effect. The Movement total is derived from the
positive Effects rather than repeated in the transport.
-/

private structure ParseState where
  validOn : Option String := none
  description : Option String := none
  effects : List Effect := []
  relationRows : List String := []
  dischargeRows : List String := []

private def effectFromFields?
    (keyToken locusToken measureToken quantityText : String) : Except String Effect := do
  if !Loam.Persistence.validToken locusToken then
    throw "loam: proposal effect Locus must be a nonempty single-line token"
  if !Loam.Persistence.validToken measureToken then
    throw "loam: proposal effect Measure must be a nonempty single-line token"
  let quantity ← match quantityText.toInt? with
    | some quantity => pure quantity
    | none => throw "loam: proposal effect quantity must be a signed integer"
  if quantity = 0 then
    throw "loam: proposal effect quantity must be nonzero"
  let locus : LocusId := ⟨locusToken⟩
  let measure : MeasureId := ⟨measureToken⟩
  let exact := Quantity.ofQuanta quantity
  if keyToken = "-" then
    pure (Effect.ofAnonymousQuantity locus measure exact)
  else
    if !Loam.Persistence.validToken keyToken then
      throw "loam: proposal EffectKey must be '-' or a nonempty single-line token"
    pure (Effect.ofQuantity ⟨keyToken⟩ locus measure exact)

private def parseLine? (state : ParseState) (line : String) : Except String ParseState := do
  match line.splitOn "\t" with
  | ["date", validOn] =>
      if state.validOn.isSome then
        throw "loam: proposal contains more than one date"
      if validOn.isEmpty then
        throw "loam: proposal date must not be empty"
      pure { state with validOn := some validOn }
  | ["description", text] =>
      if state.description.isSome then
        throw "loam: proposal contains more than one description"
      if text.isEmpty then
        throw "loam: proposal description must not be empty"
      pure { state with description := some text }
  | ["effect", keyToken, locusToken, measureToken, quantityText] =>
      let effect ← effectFromFields? keyToken locusToken measureToken quantityText
      pure { state with effects := state.effects ++ [effect] }
  | ["relation", effectToken, direction, externalToken, quantityText] =>
      let row := String.intercalate "\t" [effectToken, direction, externalToken, quantityText]
      pure { state with relationRows := state.relationRows ++ [row] }
  | ["discharge", targetToken, quantityText] =>
      let row := String.intercalate "\t" [targetToken, quantityText]
      pure { state with dischargeRows := state.dischargeRows ++ [row] }
  | _ =>
      throw "loam: unsupported Movement proposal line"

private def parseBody? : List String → ParseState → Except String ParseState
  | [], state => pure state
  | raw :: rest, state => do
      let line := raw.trimAsciiEnd.toString
      if line.isEmpty then
        parseBody? rest state
      else
        let next ← parseLine? state line
        parseBody? rest next

private def dropBlankPrefix : List String → List String
  | [] => []
  | raw :: rest =>
      let line := raw.trimAsciiEnd.toString
      if line.isEmpty then dropBlankPrefix rest else line :: rest

/--
Parse one versioned proposal into the canonical semantic Movement draft.

This operation is pure. It allocates no durable identity, reads no household
authority, writes no persistence, and retains no source-to-LOAM mapping.
Admission against current household evidence remains the responsibility of
`MovementDraftReview.check` or the canonical writer.
-/
def parse? (text : String) : Except String Loam.MovementAdmission.Draft := do
  let lines := dropBlankPrefix (text.splitOn "\n")
  let body ← match lines with
    | [] => throw "loam: Movement proposal is empty"
    | header :: rest =>
        if header = "LOAM-MOVEMENT-PROPOSAL\t1" then
          pure rest
        else
          throw "loam: unsupported Movement proposal header; expected LOAM-MOVEMENT-PROPOSAL<TAB>1"
  let parsed ← parseBody? body {}
  let validOn ← match parsed.validOn with
    | some validOn => pure validOn
    | none => throw "loam: proposal requires exactly one date"
  if parsed.effects.isEmpty then
    throw "loam: proposal requires at least one effect"
  let relations ←
    Loam.MovementRelationEntry.parseScripted?
      parsed.effects (String.intercalate "\n" parsed.relationRows)
  let discharges ←
    Loam.MovementDischargeEntry.parseScripted?
      (String.intercalate "\n" parsed.dischargeRows)
  let total :=
    parsed.effects.foldl
      (fun sum effect => sum + max 0 effect.quantity.quanta) 0
  pure {
    validOn := validOn
    description := parsed.description
    effects := parsed.effects
    relations := relations
    discharges := discharges
    total := total
  }

end Loam.MovementProposal
