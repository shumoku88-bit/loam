import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.FirstRun

open Loam.Tui.Kernel
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Explicit fresh-household choice on failed TUI startup

This is local *presentation state*, not a new household authority. A missing
directory may be offered as an initial destination, while an existing but
unreadable root always starts with a BLANK destination to prevent accidental
reuse. The publisher still checks existence at the instant of creation.

Neither opening this screen nor entering its review phase writes any bytes.
-/

inductive Phase where
  | editing
  | confirm
  deriving Repr, DecidableEq

structure State where
  selectedRoot : String
  readFailure : String
  selectedRootExists : Bool
  destination : String
  phase : Phase := .editing
  notice : String := ""
  deriving Repr

abbrev Step := Loam.Tui.EditorSession.Step State String

def initial (root : System.FilePath) (exists : Bool) (failure : String) : State :=
  { selectedRoot := root.toString
    readFailure := failure
    selectedRootExists := exists
    destination := if exists then "" else root.toString }

private def validDestination? (state : State) : Except String String := do
  let path := state.destination
  if path.trimAscii.toString.isEmpty then
    throw "Enter a NEW directory path. Existing data will never be overwritten."
  if path.toList.length > 240 then
    throw "Choose a shorter directory path."
  if path.toList.any (fun c => c.toNat < 32 || c.toNat = 127) then
    throw "Directory path must be one printable line."
  return path

private def isPrintable (char : Char) : Bool :=
  char.toNat >= 32 && char.toNat != 127

private def append (state : State) (input : String) : State :=
  let printable := String.ofList <| input.toList.filter isPrintable
  let next := String.ofList ((state.destination ++ printable).toList.take 240)
  { state with destination := next, notice := "" }

/-- Esc always cancels or returns to editing; only Confirm+Enter can publish. -/
def update (state : State) (key : Key) : Step :=
  match state.phase with
  | .editing =>
      match key with
      | .escape => { state := state, cancel := true }
      | .backspace => {
          state := { state with
            destination := backspaceText state.destination
            notice := "" } }
      | .input char =>
          { state := if isPrintable char then append state (String.singleton char) else state }
      | .paste text => { state := append state text }
      | .enter =>
          match validDestination? state with
          | .ok _ => { state := { state with phase := .confirm, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | _ => { state := state }
  | .confirm =>
      match key with
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with phase := .editing, notice := "" } }
      | .enter =>
          match validDestination? state with
          | .ok path => { state := state, publish := some path }
          | .error message =>
              { state := { state with phase := .editing, notice := message } }
      | _ => { state := state }

def withError (state : State) (message : String) : State :=
  { state with phase := .editing, notice := message }

/-- Bounded startup screen, including 32x9 and live resize. -/
def view (bounds : Bounds) (state : State) : Widget := Id.run do
  let width := Loam.Tui.Layout.contentWidth bounds
  let clipped (s : String) : Widget :=
    .row [span (Loam.Tui.Layout.ellipsize width s)]
  let muted (s : String) : Widget :=
    .row [span (Loam.Tui.Layout.ellipsize width s) .muted]
  let title := clipped "LOAM / Start a household"
  let status :=
    if state.selectedRootExists then
      muted "Selected household cannot be opened."
    else
      muted "No household exists at the selected path."
  let warning := muted "Existing files are never replaced."
  let notice := if state.notice.isEmpty then
      muted (if state.selectedRootExists then
        "Enter a DIFFERENT, unused directory."
      else
        "Check the destination before creating.")
    else
      muted state.notice
  let rows :=
    match state.phase with
    | .editing =>
        [ title
        , status
        , muted ("Selected: " ++ state.selectedRoot)
        , clipped "New household directory:"
        , .row [Loam.Tui.Layout.inputSpan width true state.destination]
        , notice
        , warning
        , clipped "Enter: review    Esc: cancel"
        ]
    | .confirm =>
        [ title
        , clipped "Create an INDEPENDENT household?"
        , muted ("New path: " ++ state.destination)
        , warning
        , muted "No history, balances or plans are invented."
        , notice
        , clipped "Enter: create    Esc/e: edit"
        ]
  return .column (rows.take bounds.height)

end Loam.Tui.FirstRun
