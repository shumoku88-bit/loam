import Loam.Tui.EditorSession
import Loam.ActualDate
import Loam.Application.PracticalMovement
import Loam.Publisher.ActualReversalPublisher
import Loam.Tui.Main
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.Layout
import Loam.Tui.Scroll

namespace Loam.Tui.ActualReversal

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

inductive Mode where
  | editing
  | preview
  deriving Repr, DecidableEq, BEq

/--
Presentation-only reversal confirmation for one selected Actual.

Only the occurrence date is editable. Inverse postings are derived from the
selected visible Actual solely for preview; `ActualReversalPublisher` re-reads
and re-derives the authoritative inverse under writer ownership.
-/
structure State where
  target : EventId
  targetDate : Option String
  description : String
  targetEffects : List Effect
  inputDate : String
  mode : Mode := .editing
  notice : String := ""
  /-- Scroll position for the derived inverse posting preview only. -/
  previewScroll : Nat := 0

abbrev Step :=
  Loam.Tui.EditorSession.Step State (Loam.ActualReversalPublisher.Draft)

/--
Seed the editable occurrence coordinate from today as a presentation convenience.
Reversal itself does not imply temporal ordering relative to the target Actual.
-/
def initial?
    (record : Loam.Tui.Main.ReviewRecord) (today : String) : Except String State := do
  if !Loam.ActualDate.validIsoDate today then
    throw "Current date is unavailable for the reversal editor."
  if (Loam.PracticalMovement.ofSingleMeasureEffects? record.event.effects).isNone then
    throw "This Actual is outside the practical balanced single-Measure reversal entrance."
  pure {
    target := record.event.id
    targetDate := record.date
    description := record.description
    targetEffects := record.event.effects
    inputDate := today
  }

private def allowedDateChar (char : Char) : Bool :=
  char.isDigit || char = '-'

/-- Local preview-only inverse of the selected visible target. -/
def inversePreview (state : State) : List (LocusId × Quantity × MeasureId) :=
  state.targetEffects.map fun effect =>
    (effect.locus, -effect.quantity, effect.measure)

/-- Emit a durable intent only after exact-inverse preview confirmation. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .backspace =>
          { state := { state with inputDate := Loam.Tui.Terminal.backspaceText state.inputDate, notice := "" } }
      | .input char =>
          if allowedDateChar char && state.inputDate.length < 10 then
            { state := { state with inputDate := state.inputDate.push char, notice := "" } }
          else
            { state }
      | .enter =>
          if Loam.ActualDate.validIsoDate state.inputDate then
            { state := { state with mode := .preview, notice := "" } }
          else
            { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }
      | _ => { state }
  | .preview =>
      match key with
      | .enter =>
          { state, publish := some { target := state.target, validOn := state.inputDate } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .editing, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Failed shared publication returns to the date editor; inverse postings remain derived. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def wrapped (columns : Nat) (text : String) (style : Style) : List Widget :=
  (Loam.Tui.Layout.wrapColumns columns text).map fun piece => .row [span piece style]

private def targetDateText (state : State) : String :=
  state.targetDate.getD "(unknown)"

private def descriptionText (state : State) : String :=
  if state.description.isEmpty then "(no description)" else state.description

/-- Wrap complete signed inverse quanta at narrow terminal widths. -/
private def inverseRows (columns : Nat) (state : State) : List Widget :=
  (inversePreview state).flatMap fun (locus, quantity, measure) =>
    let signed := (if quantity.quanta > 0 then "+" else "") ++ toString quantity.quanta
    wrapped columns (" " ++ locus.token ++ "  " ++ signed ++ " " ++ measure.token) .normal

private def footer (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := wrapped width state.notice .normal
  Loam.Tui.Layout.boundFeedbackFooter bounds <|
    (if feedback.isEmpty then [line ""] else feedback) ++
    (if state.mode == .preview then
      [ muted " Original retained; inverse Event added."
      , .row [span "[Publish reversal]" .selected]
      , muted " Up/Down PgUp/Dn review  Esc/e edit  q cancel"
      ]
    else
      [ muted " Postings are fixed: exact additive inverse."
      , muted " Date YYYY-MM-DD  Enter preview  Esc/q cancel"
      ])

/-- Physical rows available after reserved summary, borders and footer. -/
def previewCapacity (bounds : Bounds) (state : State) : Nat :=
  (Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds state).length - 5) - 2

def previewScrollLimit (bounds : Bounds) (state : State) : Nat :=
  Loam.Tui.Scroll.maxOffset
    (inverseRows (Loam.Tui.Layout.contentWidth bounds - 2) state).length
    (previewCapacity bounds state)

/-- Read-only preview scrolling; ordinary update retains sole publication intent. -/
def updateForBounds (bounds : Bounds) (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  if state.mode == .preview then
    let limit := previewScrollLimit bounds state
    let page := max 1 (previewCapacity bounds state)
    let at := min state.previewScroll limit
    match key with
    | .up => { state := { state with previewScroll := at - 1 } }
    | .down => { state := { state with previewScroll := min limit (at + 1) } }
    | .pageUp => { state := { state with previewScroll := at - page } }
    | .pageDown => { state := { state with previewScroll := min limit (at + page) } }
    | .home => { state := { state with previewScroll := 0 } }
    | .«end» => { state := { state with previewScroll := limit } }
    | .enter =>
        if previewCapacity bounds state == 0 then
          { state := { state with notice := "Enlarge terminal to review inverse postings." } }
        else update state key
    | _ => update state key
  else
    update state key

/-- Bounded date input and exact inverse review. The original stays retained. -/
def view (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let actions := footer bounds state
  let capacity := Loam.Tui.Layout.footerBodyCapacity bounds actions.length
  let panels : List Widget :=
    if state.mode == .preview then
      let summary := Loam.Tui.Layout.framedPanel width (min 5 capacity)
        "Actual / Reverse / Preview"
        (.column [
          .row [span " Target: " .muted, span state.target.token],
          .row [span " Target date: " .muted, span (targetDateText state)],
          .row [span " Reversal date: " .muted, span state.inputDate]
        ]) true
      let lines := inverseRows (width - 2) state
      let visible := previewCapacity bounds state
      let offset := Loam.Tui.Scroll.clamp lines.length visible state.previewScroll
      let count := min (offset + visible) lines.length
      let progress := s!"{count}/{lines.length} lines" ++
        (if offset > 0 then " ▲" else "") ++
        (if count < lines.length then " ▼" else "")
      let postings := Loam.Tui.Layout.framedPanel width (capacity - 5)
        "Inverse postings" (.column ((lines.drop offset).take visible))
        false (some progress)
      [summary, postings]
    else
      let content : List Widget :=
        [ .row [span " Target: " .muted, span state.target.token],
          .row [span " Target date: " .muted, span (targetDateText state)],
          .row [span " Reversal date: " .muted, span state.inputDate .selected]
        ] ++ wrapped (width - 2) (" Description: " ++ descriptionText state) .muted
      [Loam.Tui.Layout.framedPanel width (min 9 capacity)
        "Actual / Reverse / Date" (.column content) true]
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows (.column panels)) actions).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)
end Loam.Tui.ActualReversal
