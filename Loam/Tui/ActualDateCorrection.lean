import Loam.Tui.EditorSession
import Loam.ActualDate
import Loam.Publisher.ActualValidityPublisher
import Loam.Tui.Main
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.Layout

namespace Loam.Tui.ActualDateCorrection

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

inductive Mode where
  | editing
  | preview
  deriving Repr, DecidableEq, BEq

/-- Presentation-only date editor bound to one selected current Actual identity. -/
structure State where
  target : EventId
  originalDate : String
  input : String
  mode : Mode := .editing
  notice : String := ""
  deriving Repr, DecidableEq

abbrev Step :=
  Loam.Tui.EditorSession.Step State (Loam.ActualValidityPublisher.Draft)

/-- Prefill visible current date evidence. This is convenience, never publication authority. -/
def initial? (record : Loam.Tui.Main.ReviewRecord) : Except String State := do
  let date ←
    match record.date with
    | some date => pure date
    | none => throw "This Actual has no current occurrence date to edit from the selected-day workspace."
  pure {
    target := record.event.id
    originalDate := date
    input := date
  }

private def allowedDateChar (char : Char) : Bool :=
  char.isDigit || char = '-'

/--
Pure local interaction. Calendar validity is checked with the existing shared date
utility for preview feedback, then checked again by ActualValidityPublisher under
writer ownership before any canonical change.
-/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .backspace =>
          { state := { state with input := Loam.Tui.Terminal.backspaceText state.input, notice := "" } }
      | .input char =>
          if allowedDateChar char && state.input.length < 10 then
            { state := { state with input := state.input.push char, notice := "" } }
          else
            { state }
      | .enter =>
          if Loam.ActualDate.validIsoDate state.input then
            { state := { state with mode := .preview, notice := "" } }
          else
            { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }
      | _ => { state }
  | .preview =>
      match key with
      | .enter =>
          { state, publish := some { target := state.target, validOn := state.input } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .editing, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Return a failed publication attempt to the local editor without changing its draft. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def wrapped (columns : Nat) (text : String) (style : Style) : List Widget :=
  (Loam.Tui.Layout.wrapColumns columns text).map fun piece => .row [span piece style]

/-- Distinguish the retained Event, old date and only editable date.
    The shared Layout owns clipping and the fixed feedback/shortcut footprint. -/
def view (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let preview := state.mode == .preview
  let feedback := wrapped width state.notice .normal
  let footer := Loam.Tui.Layout.boundFeedbackFooter bounds <|
    (if feedback.isEmpty then [line ""] else feedback) ++
    (if preview then
      [.row [span "[Publish date change]" .selected],
       muted " Enter publish   Esc/e edit   q cancel"]
     else
      [muted " Type YYYY-MM-DD   Backspace edit",
       muted " Enter preview   Esc/q cancel"])
  let detail : List Widget :=
    [ .row [span " Current date:  " .muted, span state.originalDate]
    , .row [span (if preview then " Proposed date: " else " New date:      ") .muted,
        span state.input (if preview then .normal else .selected)]
    , line ""
    ] ++ wrapped (width - 2) (" Target Actual: " ++ state.target.token) .muted ++
    (if preview then wrapped (width - 2) " Only the occurrence date changes." .muted else [])
  let title := if preview then "Actual / Date / Preview" else "Actual / Date / Edit"
  let panel := Loam.Tui.Layout.framedPanel width
    (min 9 (Loam.Tui.Layout.footerBodyCapacity bounds footer.length))
    title (.column detail) true
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows panel) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)
end Loam.Tui.ActualDateCorrection
