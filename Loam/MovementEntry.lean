import Loam.CompletionPrompt
import Loam.Persistence
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

/--
Collect one nonempty side of a human-entered movement.

`negative` only controls the interface-level sign assigned to the Effects created
by this entrance. No source/destination role is retained in Core beyond the
ordinary signed quantity Effects themselves.
-/
private partial def collectSide
    (knownLoci : List String)
    (label : String)
    (negative : Bool)
    (nextIndex : Nat)
    (effects : List Loam.Core.Effect)
    (total : Int)
    (count : Nat) :
    IO (Except String (Nat × List Loam.Core.Effect × Int)) := do
  let locusToken ←
    Loam.CompletionPrompt.promptLocus
      (label ++ " locus (blank when done)? ") knownLoci
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
          let signedAmount := if negative then -amount else amount
          let effect :=
            Loam.Core.Effect.ofQuantity
              ⟨"effect-" ++ toString nextIndex⟩ ⟨locusToken⟩ ⟨"jpy"⟩
              (Loam.Core.Quantity.ofQuanta signedAmount)
          collectSide knownLoci label negative (nextIndex + 1)
            (effects ++ [effect]) (total + amount) (count + 1)

/--
Collect the shared human-facing shape for one balanced JPY movement.

Ordinary recording and movement correction use this adapter so they cannot drift
into different FROM/TO conventions. Equality is still only an entrance rule.
The returned Core Effects retain signed quantities, not source/destination roles.
This module deliberately has no executable `main`; callers keep their own
application entrances separate.
-/
def collectMovementEffects (knownLoci : List String := []) :
    IO (Except String (List Loam.Core.Effect × Int)) := do
  match ← collectSide knownLoci "From" true 1 [] 0 0 with
  | Except.error message =>
      return Except.error message
  | Except.ok (nextIndex, fromEffects, fromTotal) =>
      match ← collectSide knownLoci "To" false nextIndex fromEffects 0 0 with
      | Except.error message =>
          return Except.error message
      | Except.ok (_, effects, toTotal) =>
          if fromTotal != toTotal then
            return Except.error
              ("loam: movement totals differ: from " ++ toString fromTotal ++
                " jpy, to " ++ toString toTotal ++ " jpy")
          else
            return Except.ok (effects, fromTotal)

end Loam.MovementEntry
