import Loam.Core.OpenRelation
import Loam.Persistence

namespace Loam.MovementDischargeEntry

set_option autoImplicit false

/--
Human-input draft for one exact discharge against an existing RelationUnit.

The draft deliberately has no EventId. The later Event identity is allocated only
after writer ownership is acquired, so human think time cannot reserve durable
identity. Target identity and quantity are explicit; no automatic settlement or
matching is inferred from Movement Effects, endpoint labels, or source sign.
-/
structure Draft where
  target : Loam.Core.RelationUnitId
  quantity : Loam.Core.Quantity
  deriving Repr, DecidableEq

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def draftFromFields?
    (targetToken quantityText : String) : Except String Draft := do
  if !Loam.Persistence.validToken targetToken then
    throw "loam: discharge target must be a nonempty single-line RelationUnitId"
  let quantity ← match quantityText.toInt? with
    | some quantity => pure quantity
    | none => throw "loam: discharge quantity must be a positive integer"
  if quantity <= 0 then
    throw "loam: discharge quantity must be a positive integer"
  pure {
    target := ⟨targetToken⟩
    quantity := Loam.Core.Quantity.ofQuanta quantity
  }

private def parseScriptedRows : List String → Except String (List Draft)
  | [] => pure []
  | row :: rest => do
      let tail ← parseScriptedRows rest
      match row.splitOn "\t" with
      | [targetToken, quantityText] =>
          let draft ← draftFromFields? targetToken quantityText
          pure (draft :: tail)
      | _ =>
          throw
            "loam: LOAM_DISCHARGES rows must be RELATION_ID<TAB>POSITIVE_QUANTITY"

/--
Parse zero or more scripted discharge drafts.

Rows are newline-separated and fields are tab-separated:

```text
RELATION_ID<TAB>POSITIVE_QUANTITY
```

The target is checked again under writer ownership against the current admitted
relation frontier and the complete candidate discharge set.
-/
def parseScripted? (text : String) : Except String (List Draft) :=
  if text.isEmpty then
    pure []
  else
    parseScriptedRows ((text.splitOn "\n").filter fun row => !row.isEmpty)

private def collectOneInteractive : IO (Except String Draft) := do
  let targetToken ← promptLine "RelationUnit id to discharge? "
  if !Loam.Persistence.validToken targetToken then
    return Except.error
      "loam: discharge target must be a nonempty single-line RelationUnitId"
  let quantityText ← promptLine "Discharge quantity? "
  match quantityText.toInt? with
  | none => return Except.error "loam: discharge quantity must be a positive integer"
  | some quantity =>
      if quantity <= 0 then
        return Except.error "loam: discharge quantity must be a positive integer"
      else
        return Except.ok {
          target := ⟨targetToken⟩
          quantity := Loam.Core.Quantity.ofQuanta quantity
        }

private partial def collectInteractive
    (drafts : List Draft) : IO (Except String (List Draft)) := do
  let answer ← promptLine "Add relation discharge? [y/N]: "
  if answer.isEmpty || answer = "n" || answer = "N" then
    return Except.ok drafts
  else if answer = "y" || answer = "Y" then
    match ← collectOneInteractive with
    | Except.error message => return Except.error message
    | Except.ok draft => collectInteractive (drafts ++ [draft])
  else
    return Except.error "loam: answer y or n when adding relation discharge evidence"

/--
Collect optional relation-discharge meaning for one new Movement Event.

`LOAM_DISCHARGES` is authoritative when supplied, including an empty value.
Redirected callers therefore remain backward compatible when it is absent.
Interactive terminals may enter target RelationUnit identity and exact positive
quantity explicitly. Currentness, duplicate `(Event,target)` correspondence,
aggregate over-discharge, and Event activation are checked later under writer
ownership through the Application frontier.
-/
def collect : IO (Except String (List Draft)) := do
  match ← IO.getEnv "LOAM_DISCHARGES" with
  | some text => return parseScripted? text
  | none =>
      let stdin ← IO.getStdin
      let stdout ← IO.getStdout
      if (← stdin.isTty) && (← stdout.isTty) then
        IO.println ""
        IO.println "Relation discharge evidence (optional)"
        collectInteractive []
      else
        return Except.ok []

end Loam.MovementDischargeEntry
