import Loam.Tui.Terminal

namespace Loam.Tui.InputEdit

set_option autoImplicit false

/-!
# Pure single-line field editing

These three terminal keys share the same edit semantics across Record,
Scheduled posting editors, and Attention. The owner of an active field still
decides whether to apply the edit, how focus moves, what notice is cleared, and
whether any publication action may occur. Non-text keys never edit the value.
-/

/-- Return the text change requested by a normalized field-edit key, if any. -/
def operation? (key : Loam.Tui.Terminal.Key) : Option (String → String) :=
  match key with
  | .backspace => some Loam.Tui.Terminal.backspaceText
  | .input char => some (fun text => text.push char)
  | .paste payload =>
      let clean := Loam.Tui.Terminal.singleLinePaste payload
      some (fun text => text ++ clean)
  | _ => none

/-- Convenience for editors whose active field is itself a String. -/
def apply? (key : Loam.Tui.Terminal.Key) (text : String) : Option String :=
  (operation? key).map (fun operation => operation text)

end Loam.Tui.InputEdit
