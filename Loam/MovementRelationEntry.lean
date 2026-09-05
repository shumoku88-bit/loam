import Loam.Core.OpenRelation
import Loam.Core.Event
import Loam.Persistence

namespace Loam.MovementRelationEntry

set_option autoImplicit false

/--
Human-input draft for one positive open relation attached to an already-collected
Movement Effect.

The draft deliberately has no EventId or RelationUnitId. Durable identities are
allocated only after writer ownership is acquired. Debtor/creditor are already
explicit here, so Effect sign is never consulted for relation direction.
-/
structure Draft where
  sourceEffect : Loam.Core.EffectKey
  debtor : Loam.Core.RelationEndpoint
  creditor : Loam.Core.RelationEndpoint
  quantity : Loam.Core.Quantity
  deriving Repr, DecidableEq

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def findEffectByKey? :
    List Loam.Core.Effect → Loam.Core.EffectKey → Option Loam.Core.Effect
  | [], _ => none
  | effect :: rest, key =>
      if effect.key = key then some effect else findEffectByKey? rest key

private def draftFromFields?
    (effects : List Loam.Core.Effect)
    (effectToken direction externalToken quantityText : String) :
    Except String Draft := do
  if !Loam.Persistence.validToken effectToken then
    throw "loam: relation source effect must be a nonempty single-line EffectKey"
  if !Loam.Persistence.validToken externalToken then
    throw "loam: external endpoint id must be a nonempty single-line token"
  let effectKey : Loam.Core.EffectKey := ⟨effectToken⟩
  if (findEffectByKey? effects effectKey).isNone then
    throw ("loam: relation source EffectKey is not in this movement: " ++ effectToken)
  let quantity ← match quantityText.toInt? with
    | some quantity => pure quantity
    | none => throw "loam: relation quantity must be a positive integer"
  if quantity <= 0 then
    throw "loam: relation quantity must be a positive integer"
  let external : Loam.Core.RelationEndpoint := .external ⟨externalToken⟩
  let (debtor, creditor) ← match direction with
    | "E2H" => pure (external, Loam.Core.RelationEndpoint.household)
    | "H2E" => pure (Loam.Core.RelationEndpoint.household, external)
    | _ => throw "loam: relation direction must be E2H or H2E"
  pure {
    sourceEffect := effectKey
    debtor := debtor
    creditor := creditor
    quantity := Loam.Core.Quantity.ofQuanta quantity
  }

private def parseScriptedRows
    (effects : List Loam.Core.Effect) : List String → Except String (List Draft)
  | [] => pure []
  | row :: rest => do
      let tail ← parseScriptedRows effects rest
      match row.splitOn "\t" with
      | [effectToken, direction, externalToken, quantityText] =>
          let draft ← draftFromFields?
            effects effectToken direction externalToken quantityText
          pure (draft :: tail)
      | _ =>
          throw
            "loam: LOAM_RELATIONS rows must be EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>QUANTITY"

/--
Parse zero or more scripted relation drafts.

Rows are newline-separated and fields are tab-separated:

```text
EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY
```

`E2H` means external debtor -> Household creditor. `H2E` means Household debtor
-> external creditor. Effect sign is deliberately irrelevant.
-/
def parseScripted?
    (effects : List Loam.Core.Effect) (text : String) : Except String (List Draft) :=
  if text.isEmpty then
    pure []
  else
    parseScriptedRows effects ((text.splitOn "\n").filter fun row => !row.isEmpty)

private def printEffectChoices (effects : List Loam.Core.Effect) : IO Unit := do
  IO.println "Movement Effects"
  for entry in effects.zipIdx do
    let effect := entry.1
    let index := entry.2 + 1
    IO.println
      ("  " ++ toString index ++ ". " ++ effect.key.token ++
        "  " ++ effect.locus.token ++
        "  " ++ toString effect.quantity.quanta ++
        " " ++ effect.measure.token)

private def getEffectByIndex? :
    List Loam.Core.Effect → Nat → Option Loam.Core.Effect
  | [], _ => none
  | effect :: _, 0 => some effect
  | _ :: rest, index + 1 => getEffectByIndex? rest index

private def chooseEffect?
    (effects : List Loam.Core.Effect) : IO (Except String Loam.Core.EffectKey) := do
  printEffectChoices effects
  let entered ← promptLine "Relation source effect number? "
  match entered.toNat? with
  | none => return Except.error "loam: relation source effect must be selected by number"
  | some 0 => return Except.error "loam: relation source effect number is out of range"
  | some number =>
      match getEffectByIndex? effects (number - 1) with
      | none => return Except.error "loam: relation source effect number is out of range"
      | some effect => return Except.ok effect.key

private def collectOneInteractive
    (effects : List Loam.Core.Effect) : IO (Except String Draft) := do
  match ← chooseEffect? effects with
  | Except.error message => return Except.error message
  | Except.ok sourceEffect =>
      let externalToken ← promptLine "External endpoint id? "
      if !Loam.Persistence.validToken externalToken then
        return Except.error "loam: external endpoint id must be a nonempty single-line token"
      IO.println "Direction:"
      IO.println "  1. external -> household"
      IO.println "  2. household -> external"
      let direction ← promptLine "Select direction: "
      let external : Loam.Core.RelationEndpoint := .external ⟨externalToken⟩
      let endpoints? :=
        match direction with
        | "1" => some (external, Loam.Core.RelationEndpoint.household)
        | "2" => some (Loam.Core.RelationEndpoint.household, external)
        | _ => none
      match endpoints? with
      | none => return Except.error "loam: relation direction must be 1 or 2"
      | some (debtor, creditor) =>
          let quantityText ← promptLine "Relation quantity? "
          match quantityText.toInt? with
          | none => return Except.error "loam: relation quantity must be a positive integer"
          | some quantity =>
              if quantity <= 0 then
                return Except.error "loam: relation quantity must be a positive integer"
              else
                return Except.ok {
                  sourceEffect := sourceEffect
                  debtor := debtor
                  creditor := creditor
                  quantity := Loam.Core.Quantity.ofQuanta quantity
                }

private partial def collectInteractive
    (effects : List Loam.Core.Effect)
    (drafts : List Draft) : IO (Except String (List Draft)) := do
  let answer ← promptLine "Add open relation? [y/N]: "
  if answer.isEmpty || answer = "n" || answer = "N" then
    return Except.ok drafts
  else if answer = "y" || answer = "Y" then
    match ← collectOneInteractive effects with
    | Except.error message => return Except.error message
    | Except.ok draft => collectInteractive effects (drafts ++ [draft])
  else
    return Except.error "loam: answer y or n when adding open relation evidence"

/--
Collect optional open-relation meaning after Movement Effects already exist.

`LOAM_RELATIONS` is authoritative when supplied, including an empty value. This
keeps redirected callers deterministic and gives CI/scripts an explicit route.
Without the variable, non-TTY callers retain historical behavior and publish no
relation evidence. Interactive terminals may add zero or more relation drafts by
explicitly choosing an Effect, endpoint identity, direction, and quantity.
-/
def collect
    (effects : List Loam.Core.Effect) : IO (Except String (List Draft)) := do
  match ← IO.getEnv "LOAM_RELATIONS" with
  | some text => return parseScripted? effects text
  | none =>
      let stdin ← IO.getStdin
      let stdout ← IO.getStdout
      if (← stdin.isTty) && (← stdout.isTty) then
        IO.println ""
        IO.println "Open relation evidence (optional)"
        collectInteractive effects []
      else
        return Except.ok []

end Loam.MovementRelationEntry
