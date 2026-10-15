import Loam.Tui.EditorSession
import Loam.ActualDate
import Loam.Publisher.ActualValidityPublisher
import Loam.Tui.Main
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.Layout
import Loam.Tui.ModalSurface

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

/-- Compact terminals without sufficient review space must not accept a
    blind Publish. This changes no date, target, or draft; larger screens retain
    the same editor transitions and publisher intent. -/
def updateForBounds (bounds : Bounds) (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  if state.mode == .preview && key == .enter &&
      (bounds.height < 14 || Loam.Tui.Layout.contentWidth bounds < 46) then
    { state := { state with
        notice := "Enlarge terminal to review the date and target before Publish." } }
  else update state key

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
        Loam.Tui.Layout.inputSpan (width - 2 - Loam.Tui.Layout.displayWidth " New date:      ")
          (!preview) state.input]
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
/-!
# Shared adaptive presentation surface

Only the placement of the existing date editor changes. Target selection,
date validation, edit/preview intent and Actual publication remain owned by
their existing modules and the Selected Day session.
-/

/-- A compact date form can float without hiding either date or the target. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 72 23 76 18

/-- The date editor receives only the visible space inside the outer frame. -/
def editorBounds (bounds : Bounds) : Bounds :=
  Loam.Tui.ModalSurface.contentBounds bounds (floatingGeometry? bounds)

/-- Keep the original edit and preview renderer, including its compact fallback. -/
def viewForBounds (bounds : Bounds) (state : State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Actual / Date" (fun inner => view inner state)

end Loam.Tui.ActualDateCorrection
