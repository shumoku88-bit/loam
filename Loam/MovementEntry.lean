import Loam.CompletionPrompt
import Loam.Core.BalancedMovement
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

private def movementEffect
    (index : Nat)
    (locusToken : String)
    (negative : Bool)
    (amount : Int) : Loam.Core.Effect :=
  let signedAmount := if negative then -amount else amount
  Loam.Core.Effect.ofQuantity
    ⟨"effect-" ++ toString index⟩ ⟨locusToken⟩ ⟨"jpy"⟩
    (Loam.Core.Quantity.ofQuanta signedAmount)

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
          let effect := movementEffect nextIndex locusToken negative amount
          collectSide knownLoci label negative (nextIndex + 1)
            (effects ++ [effect]) (total + amount) (count + 1)

private def promptDefaultLocus
    (knownLoci : List String)
    (label defaultLocus : String) : IO (Except String (Option String)) := do
  let entered ←
    Loam.CompletionPrompt.promptLocus
      (label ++ " locus [" ++ defaultLocus ++ "] (Enter keeps, - removes): ")
      knownLoci
  if entered.isEmpty then
    return Except.ok (some defaultLocus)
  else if entered = "-" then
    return Except.ok none
  else if Loam.Persistence.validToken entered then
    return Except.ok (some entered)
  else
    return Except.error
      ("loam: " ++ label.toLower ++ " locus must be a nonempty single-line token")

private def promptDefaultAmount
    (label : String)
    (defaultAmount : Int) : IO (Except String Int) := do
  let entered ← promptLine (label ++ " amount [" ++ toString defaultAmount ++ "]: ")
  if entered.isEmpty then
    return Except.ok defaultAmount
  else
    match entered.toInt? with
    | none => return Except.error "loam: movement amount must be a positive integer"
    | some amount =>
        if amount <= 0 then
          return Except.error "loam: movement amount must be a positive integer"
        else
          return Except.ok amount

private partial def collectAdditionalSide
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
      ("Additional " ++ label.toLower ++ " locus (blank when done)? ") knownLoci
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
    | none => return Except.error "loam: movement amount must be a positive integer"
    | some amount =>
        if amount <= 0 then
          return Except.error "loam: movement amount must be a positive integer"
        else
          let effect := movementEffect nextIndex locusToken negative amount
          collectAdditionalSide knownLoci label negative (nextIndex + 1)
            (effects ++ [effect]) (total + amount) (count + 1)

private partial def collectDefaultSide
    (knownLoci : List String)
    (label : String)
    (negative : Bool) :
    List (Loam.Core.MovementChange Loam.Core.LocusId) →
    Nat → List Loam.Core.Effect → Int → Nat →
    IO (Except String (Nat × List Loam.Core.Effect × Int))
  | [], nextIndex, effects, total, count =>
      collectAdditionalSide knownLoci label negative nextIndex effects total count
  | change :: rest, nextIndex, effects, total, count => do
      let defaultAmount :=
        if negative then -change.quantity.quanta else change.quantity.quanta
      match ← promptDefaultLocus knownLoci label change.coordinate.token with
      | Except.error message => return Except.error message
      | Except.ok none =>
          collectDefaultSide knownLoci label negative rest
            nextIndex effects total count
      | Except.ok (some locusToken) =>
          match ← promptDefaultAmount label defaultAmount with
          | Except.error message => return Except.error message
          | Except.ok amount =>
              let effect := movementEffect nextIndex locusToken negative amount
              collectDefaultSide knownLoci label negative rest
                (nextIndex + 1) (effects ++ [effect]) (total + amount) (count + 1)

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

/--
Collect an Actual movement with one Scheduled movement as editable terminal defaults.

This is a human-input convenience only. Pressing Enter retains an expected Locus
or amount in the draft; typing another value replaces only that draft field, `-`
removes one expected Locus row, and additional rows may still be entered. The
returned Effects are freshly constructed Actual evidence rather than reused
Scheduled facts.

Redirected callers keep the historical explicit-input protocol so scripts do not
silently inherit Scheduled values. Zero-valued expected changes also fall back to
explicit entry rather than inventing a special zero-edit convention.
-/
def collectMovementEffectsWithDefaults
    (knownLoci : List String)
    (defaults : Loam.Core.BalancedMovement Loam.Core.LocusId) :
    IO (Except String (List Loam.Core.Effect × Int)) := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  if !(← stdin.isTty) || !(← stdout.isTty) then
    collectMovementEffects knownLoci
  else if defaults.measure != ⟨"jpy"⟩ then
    collectMovementEffects knownLoci
  else if defaults.changes.any (fun change => change.quantity.quanta == 0) then
    IO.println "Scheduled movement has zero-valued changes; enter the Actual movement explicitly."
    collectMovementEffects knownLoci
  else
    IO.println "Press Enter to keep each scheduled movement value; type only what changed."
    let fromDefaults :=
      defaults.changes.filter fun change => change.quantity.quanta < 0
    let toDefaults :=
      defaults.changes.filter fun change => change.quantity.quanta > 0
    match ← collectDefaultSide knownLoci "From" true fromDefaults 1 [] 0 0 with
    | Except.error message => return Except.error message
    | Except.ok (nextIndex, fromEffects, fromTotal) =>
        match ← collectDefaultSide knownLoci "To" false toDefaults
            nextIndex fromEffects 0 0 with
        | Except.error message => return Except.error message
        | Except.ok (_, effects, toTotal) =>
            if fromTotal != toTotal then
              return Except.error
                ("loam: movement totals differ: from " ++ toString fromTotal ++
                  " jpy, to " ++ toString toTotal ++ " jpy")
            else
              return Except.ok (effects, fromTotal)

end Loam.MovementEntry
