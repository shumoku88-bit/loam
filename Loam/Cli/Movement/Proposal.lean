import Loam.Core.Event
import Loam.Core.MovementOperationEvidence
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
`MovementAdmission.Draft`.

Version 1 remains the original identity-free transport. Version 2 adds exactly
one explicit logical Movement operation identity for idempotent publication.
Neither version grants publication authority or introduces a second Movement
semantics.

Version 1 is intentionally inspectable by both humans and agents:

```text
LOAM-MOVEMENT-PROPOSAL<TAB>1
date<TAB>YYYY-MM-DD
description<TAB>optional recognition text
effect<TAB>-|EFFECT_KEY<TAB>LOCUS<TAB>MEASURE<TAB>SIGNED_QUANTA
relation<TAB>EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY
discharge<TAB>RELATION_ID<TAB>POSITIVE_QUANTITY
```

Version 2 adds one required row:

```text
LOAM-MOVEMENT-PROPOSAL<TAB>2
operation<TAB>STABLE_OPERATION_ID
...
```

`-` means an anonymous Effect. A stable EffectKey is needed only when explicit
relation evidence refers to that Effect. The Movement total is derived from the
positive Effects rather than repeated in the transport.
-/

private structure ParseState where
  operation : Option MovementOperationId := none
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
  | ["operation", token] =>
      if state.operation.isSome then
        throw "loam: proposal contains more than one operation identity"
      if !Loam.Persistence.validToken token then
        throw "loam: proposal operation identity must be a nonempty single-line token"
      pure { state with operation := some ⟨token⟩ }
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
One parsed proposal for record-time use.

Version 1 carries no operation identity. Version 2 carries exactly one stable
MovementOperationId used only by the idempotent publication entrance.
-/
structure ParsedProposal where
  operation : Option MovementOperationId
  draft : Loam.MovementAdmission.Draft

private inductive ProposalVersion where
  | v1
  | v2

private def parseVersionedState?
    (text : String) : Except String (ProposalVersion × ParseState) := do
  let lines := dropBlankPrefix (text.splitOn "\n")
  let (version, body) ← match lines with
    | [] => throw "loam: Movement proposal is empty"
    | header :: rest =>
        if header = "LOAM-MOVEMENT-PROPOSAL\t1" then
          pure (.v1, rest)
        else if header = "LOAM-MOVEMENT-PROPOSAL\t2" then
          pure (.v2, rest)
        else
          throw
            "loam: unsupported Movement proposal header; expected LOAM-MOVEMENT-PROPOSAL<TAB>1 or <TAB>2"
  let parsed ← parseBody? body {}
  match version with
  | .v1 =>
      if parsed.operation.isSome then
        throw "loam: Movement proposal v1 does not carry operation identity"
  | .v2 =>
      if parsed.operation.isNone then
        throw "loam: Movement proposal v2 requires exactly one operation identity"
  pure (version, parsed)

private def draftFromState?
    (parsed : ParseState) : Except String Loam.MovementAdmission.Draft := do
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

/--
Parse either supported version for record-time use.

The parser validates v2 operation identity but performs no authority read or
write. Version 1 returns `operation := none`; version 2 returns the explicit
stable identity supplied by the proposal.
-/
def parseRecord? (text : String) : Except String ParsedProposal := do
  let (_, parsed) ← parseVersionedState? text
  let draft ← draftFromState? parsed
  pure { operation := parsed.operation, draft := draft }

/--
Parse either supported proposal version into the canonical semantic Movement
Draft for read-only review.

Any v2 operation identity is deliberately discarded here. Review does not
reserve, publish, or retain operation identity.
-/
def parse? (text : String) : Except String Loam.MovementAdmission.Draft := do
  let parsed ← parseRecord? text
  pure parsed.draft

end Loam.MovementProposal
