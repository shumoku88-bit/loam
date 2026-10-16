import Loam.Presentation.LocusCatalog
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.LocusLabelSetup

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
Optional presentation metadata for one ALREADY admitted Locus. Stable canonical
identities, accounting roles, Actual, Scheduled, and historical evidence remain
unchanged. The same editor can reopen later for a changed friendly name.
-/

structure Draft where
  token : String
  label : String
  deriving Repr, DecidableEq

inductive Phase where
  | choose
  | editing
  | review
  deriving Repr, DecidableEq

structure State where
  catalog : Loam.LocusCatalog.Catalog
  selected : Nat := 0
  entered : String := ""
  phase : Phase := .choose
  notice : String := ""
  deriving Repr

abbrev Step := Loam.Tui.EditorSession.Step State Draft

def initial (catalog : Loam.LocusCatalog.Catalog) : State :=
  { catalog }

private def printable (char : Char) : Bool :=
  char.toNat >= 32 && !(char.toNat >= 0x7f && char.toNat <= 0x9f)

private def beginEditing (state : State) : State :=
  match state.catalog[state.selected]? with
  | none => { state with notice := "Admit a Locus before assigning a label." }
  | some entry =>
      { state with
        entered := if entry.label == entry.locus.token then "" else entry.label
        phase := .editing
        notice := "" }

def parse (state : State) : Except String Draft := do
  let some entry := state.catalog[state.selected]?
    | throw "No admitted Locus is selected."
  let name := state.entered.trimAscii.toString
  if name.isEmpty then
    throw "Enter a display name, or use the stable token as its name."
  if name.toList.length > 80 || !name.toList.all printable then
    throw "Use a single printable display name of at most 80 characters."
  return { token := entry.locus.token, label := name }

private def append (state : State) (input : String) : State :=
  let chars := (state.entered ++ String.ofList (input.toList.filter printable)).toList.take 80
  { state with entered := String.ofList chars, notice := "" }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.phase with
  | .choose =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .input 'k' =>
          { state := { state with selected := state.selected - 1, notice := "" } }
      | .down | .input 'j' =>
          { state := { state with
              selected := min (state.catalog.length - 1) (state.selected + 1),
              notice := "" } }
      | .enter => { state := beginEditing state }
      | _ => { state }
  | .editing =>
      match key with
      | .escape => { state := { state with phase := .choose, notice := "" } }
      | .backspace =>
          { state := { state with
              entered := Loam.Tui.Terminal.backspaceText state.entered,
              notice := "" } }
      | .input char =>
          { state := if printable char then append state (String.singleton char)
                     else state }
      | .paste input => { state := append state input }
      | .enter =>
          match parse state with
          | .ok _ => { state := { state with phase := .review, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | _ => { state }
  | .review =>
      match key with
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with phase := .editing, notice := "" } }
      | .enter =>
          match parse state with
          | .ok draft => { state, publish := some draft }
          | .error message => { state := { state with phase := .editing, notice := message } }
      | _ => { state }

def withError (state : State) (message : String) : State :=
  { state with phase := .editing, notice := message }

private def line (width : Nat) (value : String) (style : Style := .normal) : Widget :=
  .row [span (Loam.Tui.Layout.ellipsize width value) style]

def view (bounds : Bounds) (state : State) : Widget := Id.run do
  let width := Loam.Tui.Layout.contentWidth bounds
  let rows : List Widget :=
    match state.phase with
    | .choose =>
        let available := bounds.height - 5
        let offset := if state.selected < available then 0
          else state.selected + 1 - available
        let entries := (state.catalog.zipIdx.drop offset).take available
        [ line width "Household setup / Friendly names"
        , line width "Choose an admitted account or category." .muted
        ] ++
        (if state.catalog.isEmpty then [line width "No Loci admitted yet." .muted]
         else entries.map fun (entry, i) =>
           line width
             ((if i == state.selected then "> " else "  ") ++
                entry.locus.token ++ " : " ++ entry.label)
             (if i == state.selected then .selected else .normal)) ++
        [ line width "j/k select  Enter edit  Esc cancel" .muted
        , line width state.notice .muted ]
    | .editing =>
        let token := (state.catalog[state.selected]?).map (·.locus.token) |>.getD "?"
        [ line width "Household setup / Edit display name"
        , line width ("Stable identity: " ++ token)
        , line width "Name shown in menus and transaction pickers:" .muted
        , .row [span "Name: ", Loam.Tui.Layout.inputSpan (width - 6) true state.entered]
        , line width "Identity and historical records never change." .muted
        , line width "Enter review  Esc account list" .muted
        , line width state.notice .muted ]
    | .review =>
        let token := (state.catalog[state.selected]?).map (·.locus.token) |>.getD "?"
        [ line width "Review / Friendly display name"
        , line width ("Stable identity: " ++ token)
        , line width ("Display name: " ++ state.entered)
        , line width "Only the display catalog is updated." .muted
        , line width "Existing descriptions and old entries remain." .muted
        , line width "Enter save  Esc/e edit" .muted
        , line width state.notice .muted ]
  return .column (rows.take bounds.height)

end Loam.Tui.LocusLabelSetup
