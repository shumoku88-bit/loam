import Loam.Core.Event
import Loam.Persistence.TokenSyntax
import Std

namespace Loam.MovementEntry

set_option autoImplicit false

/-- Prompt for one line while keeping the movement entrance interactive. -/
private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def movementEffect
    (measure : Loam.Core.MeasureId)
    (index : Nat)
    (locusToken : String)
    (negative : Bool)
    (amount : Int) : Loam.Core.Effect :=
  let signedAmount := if negative then -amount else amount
  Loam.Core.Effect.ofQuantity
    ⟨"effect-" ++ toString index⟩ ⟨locusToken⟩ measure
    (Loam.Core.Quantity.ofQuanta signedAmount)

/--
Collect one nonempty side of a human-entered movement.

`negative` only controls the interface-level sign assigned to the Effects created
by this entrance. No source/destination role is retained in Core beyond the
ordinary signed quantity Effects themselves.
-/
private partial def collectSide
    (measure : Loam.Core.MeasureId)
    (label : String)
    (negative : Bool)
    (nextIndex : Nat)
    (effects : List Loam.Core.Effect)
    (total : Int)
    (count : Nat) :
    IO (Except String (Nat × List Loam.Core.Effect × Int)) := do
  let locusToken ← promptLine (label ++ " locus (blank when done)? ")
  if locusToken.isEmpty then
    if count = 0 then
      return Except.error ("loam: at least one " ++ label.toLower ++ " locus is required")
    else
      return Except.ok (nextIndex, effects, total)
  else if !Loam.Persistence.validToken locusToken then
    return Except.error ("loam: " ++ label.toLower ++ " locus must be a nonempty single-line token")
  else
    let amountText ← promptLine (label ++ " amount? ")
    match amountText.toInt? with
    | none =>
        return Except.error "loam: movement amount must be a positive integer"
    | some amount =>
        if amount <= 0 then
          return Except.error "loam: movement amount must be a positive integer"
        else
          let effect := movementEffect measure nextIndex locusToken negative amount
          collectSide measure label negative (nextIndex + 1)
            (effects ++ [effect]) (total + amount) (count + 1)

/--
Collect the shared human-facing shape for one balanced single-Measure movement.

Ordinary recording and movement correction use this adapter so they cannot drift
into different FROM/TO conventions. Equality is still only an entrance rule.
The returned Core Effects retain signed quantities and explicit Measure identity,
not source/destination roles.
This module deliberately has no executable `main`; callers keep their own
application entrances separate.
-/
def collectMovementEffects
    (measure : Loam.Core.MeasureId) :
    IO (Except String (List Loam.Core.Effect × Int)) := do
  match ← collectSide measure "From" true 1 [] 0 0 with
  | Except.error message =>
      return Except.error message
  | Except.ok (nextIndex, fromEffects, fromTotal) =>
      match ← collectSide measure "To" false nextIndex fromEffects 0 0 with
      | Except.error message =>
          return Except.error message
      | Except.ok (_, effects, toTotal) =>
          if fromTotal != toTotal then
            return Except.error
              ("loam: movement totals differ: from " ++ toString fromTotal ++
                " " ++ measure.token ++ ", to " ++ toString toTotal ++
                " " ++ measure.token)
          else
            return Except.ok (effects, fromTotal)

end Loam.MovementEntry
