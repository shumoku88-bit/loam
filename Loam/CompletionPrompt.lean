import Loam.Core.EventMemory
import Std

namespace Loam.CompletionPrompt

set_option autoImplicit false

private def addIfAbsent (tokens : List String) (token : String) : List String :=
  if token ∈ tokens then tokens else tokens ++ [token]

/--
Collect the Locus tokens that are actually present in recorded Effects.

Retained order is only a stable display convenience inherited from the current
memory representation. It carries no temporal, priority, or accounting meaning.
-/
def knownLoci (memory : Loam.Core.EventMemory) : List String :=
  memory.events.foldl
    (fun loci event =>
      event.effects.foldl
        (fun current effect => addIfAbsent current effect.locus.token)
        loci)
    []

/--
Return previously observed Locus tokens whose text begins with the typed text.
No candidates are exposed until two characters have been entered. Matching is
case-sensitive and does not reinterpret or rank Loci.
-/
def candidatesForPrefix (known : List String) (typed : String) : List String :=
  if typed.length < 2 then
    []
  else
    known.filter (fun token => token.startsWith typed)

example : candidatesForPrefix ["smbc", "food", "tobacco"] "s" = [] := by native_decide
example : candidatesForPrefix ["smbc", "food", "tobacco"] "sm" = ["smbc"] := by native_decide
example : candidatesForPrefix ["smbc", "food", "tobacco"] "fo" = ["food"] := by native_decide
example : candidatesForPrefix ["smbc", "food", "tobacco"] "ta" = ["tobacco"] := by native_decide

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def terminalState? : IO (Option String) := do
  try
    let output ← IO.Process.output {
      cmd := "sh"
      args := #["-c", "stty -g < /dev/tty"]
    }
    if output.exitCode = 0 then
      let state := output.stdout.trimAsciiEnd.toString.trimAsciiStart.toString
      if state.isEmpty then return none else return some state
    else
      return none
  catch _ =>
    return none

private def enterCharacterMode : IO Bool := do
  try
    let output ← IO.Process.output {
      cmd := "sh"
      args := #["-c", "stty -icanon -echo -isig min 1 time 0 < /dev/tty"]
    }
    return output.exitCode = 0
  catch _ =>
    return false

private def restoreTerminal (state : String) : IO Unit := do
  try
    let _ ← IO.Process.output {
      cmd := "sh"
      args := #["-c", "stty " ++ state ++ " < /dev/tty"]
    }
    pure ()
  catch _ =>
    pure ()

private def dropLastChar (text : String) : String :=
  match text.toList.reverse with
  | [] => ""
  | _ :: rest => String.ofList rest.reverse

private def candidateText (known : List String) (input : String) : String :=
  match (candidatesForPrefix known input).take 4 with
  | [] => ""
  | found => "  " ++ String.intercalate "  " found

private def redraw
    (stdout : IO.FS.Stream)
    (prompt input : String)
    (known : List String) : IO Unit := do
  stdout.putStr ("\r\u001b[2K" ++ prompt ++ input)
  stdout.putStr ("\n\u001b[2K" ++ candidateText known input)
  stdout.putStr "\u001b[1A\r"
  stdout.flush

private partial def readCharacters
    (stdin stdout : IO.FS.Stream)
    (prompt : String)
    (known : List String)
    (input : String) : IO String := do
  let bytes ← stdin.read 1
  match bytes.toList with
  | [] =>
      stdout.putStr "\n\u001b[2K\r"
      stdout.flush
      return input
  | byte :: _ =>
      if byte = 10 || byte = 13 then
        stdout.putStr "\n\u001b[2K\r"
        stdout.flush
        return input
      else if byte = 3 then
        stdout.putStr "^C\n\u001b[2K\r"
        stdout.flush
        throw <| IO.userError "interrupted"
      else if byte = 8 || byte = 127 then
        let next := dropLastChar input
        redraw stdout prompt next known
        readCharacters stdin stdout prompt known next
      else if byte >= 32 && byte <= 126 then
        let next := input.push (Char.ofUInt8 byte)
        redraw stdout prompt next known
        readCharacters stdin stdout prompt known next
      else
        readCharacters stdin stdout prompt known input

/--
Read one Locus token. On a real terminal, previously observed Loci are shown live
once the user has typed at least two ASCII characters. The typed text remains the
value that is accepted; a candidate is a hint, not an implicit selection.

When stdin or stdout is redirected, or when the small POSIX terminal adapter is
unavailable, this falls back to ordinary line input so scripted callers and CI
retain their existing behavior.
-/
def promptLocus (prompt : String) (known : List String) : IO String := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  if !(← stdin.isTty) || !(← stdout.isTty) then
    promptLine prompt
  else
    match ← terminalState? with
    | none => promptLine prompt
    | some state =>
        if !(← enterCharacterMode) then
          promptLine prompt
        else
          try
            stdout.putStr prompt
            stdout.flush
            readCharacters stdin stdout prompt known ""
          finally
            restoreTerminal state

end Loam.CompletionPrompt
