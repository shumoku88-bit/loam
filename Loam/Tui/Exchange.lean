import Loam.Tui.EditorSession
import Loam.Application.ExchangeAdmission
import Loam.Presentation.MeasurePresentation
import Loam.Persistence.TokenSyntax
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.Layout

namespace Loam.Tui.Exchange

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Exchange editor

A small presentation-only editor for one direct cross-Measure exchange.

The user enters positive human-facing source/destination amounts. The semantic
draft stores source as a negative Effect and destination as a positive Effect.
No FX rate is calculated or retained.
-/

structure Form where
  date : String
  description : String := ""
  sourceLocus : String := ""
  sourceMeasure : String := "jpy"
  sourceAmount : String := ""
  destinationLocus : String := ""
  destinationMeasure : String := ""
  destinationAmount : String := ""
  focus : Nat := 0

inductive Mode where
  | editing
  | preview (draft : Loam.ExchangeAdmission.Draft) (choice : Nat)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""
  measurePresentation : List Loam.MeasurePresentation.Metadata := []

abbrev Step :=
  Loam.Tui.EditorSession.Step State (Loam.ExchangeAdmission.Draft)

def initialWithMeasure (measure : MeasureId) (date : String) : State :=
  { form := { date := date, sourceMeasure := measure.token } }

/-- Backward-compatible no-configuration entrance for the current JPY household. -/
def initial (date : String) : State :=
  initialWithMeasure ⟨"jpy"⟩ date

def withMeasurePresentation
    (state : State) (metadata : List Loam.MeasurePresentation.Metadata) : State :=
  { state with measurePresentation := metadata }

private def focusCount : Nat := 10
private def previewAction : Nat := 8

private def moveFocus (form : Form) (back : Bool) : Form :=
  { form with focus := Loam.Tui.CyclicIndex.move focusCount form.focus back }

private def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus = 0 then { form with date := edit form.date }
  else if form.focus = 1 then { form with description := edit form.description }
  else if form.focus = 2 then { form with sourceLocus := edit form.sourceLocus }
  else if form.focus = 3 then { form with sourceMeasure := edit form.sourceMeasure }
  else if form.focus = 4 then { form with sourceAmount := edit form.sourceAmount }
  else if form.focus = 5 then { form with destinationLocus := edit form.destinationLocus }
  else if form.focus = 6 then { form with destinationMeasure := edit form.destinationMeasure }
  else if form.focus = 7 then { form with destinationAmount := edit form.destinationAmount }
  else form

private def parsedPositive?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (measure : MeasureId) (text label : String) : Except String Quantity := do
  let scale := Loam.MeasurePresentation.scaleFor metadata measure
  let some quanta := Loam.MeasurePresentation.parseQuanta? metadata measure text
    | throw (label ++ " must be a positive amount with at most " ++
        toString scale ++ " decimal places.")
  if quanta <= 0 then
    throw (label ++ " must be positive.")
  pure (Quantity.ofQuanta quanta)

/-- Convert the local form into one exact cross-Measure exchange draft. -/
def draft? (state : State) : Except String Loam.ExchangeAdmission.Draft := do
  if !Loam.Persistence.validToken state.form.sourceLocus then
    throw "Source Locus must be a nonempty single-line token."
  if !Loam.Persistence.validToken state.form.destinationLocus then
    throw "Destination Locus must be a nonempty single-line token."
  if !Loam.Persistence.validToken state.form.sourceMeasure then
    throw "Source Measure must be a nonempty single-line token."
  if !Loam.Persistence.validToken state.form.destinationMeasure then
    throw "Destination Measure must be a nonempty single-line token."

  let sourceMeasure : MeasureId := ⟨state.form.sourceMeasure⟩
  let destinationMeasure : MeasureId := ⟨state.form.destinationMeasure⟩
  if sourceMeasure = destinationMeasure then
    throw "Source and destination Measures must differ."

  let sourceQuantity ← parsedPositive?
    state.measurePresentation sourceMeasure state.form.sourceAmount "Source amount"
  let destinationQuantity ← parsedPositive?
    state.measurePresentation destinationMeasure state.form.destinationAmount "Destination amount"

  pure {
    validOn := state.form.date
    description :=
      if state.form.description.isEmpty then none else some state.form.description
    effects := [
      Effect.ofQuantity
        ⟨"exchange-source"⟩
        ⟨state.form.sourceLocus⟩
        sourceMeasure
        (Quantity.ofQuanta (-sourceQuantity.quanta)),
      Effect.ofQuantity
        ⟨"exchange-destination"⟩
        ⟨state.form.destinationLocus⟩
        destinationMeasure
        destinationQuantity
    ]
    source := ⟨"exchange-source"⟩
    destination := ⟨"exchange-destination"⟩
  }

private def enterPreview
    (world : Loam.ExchangeAdmission.World) (state : State) : State :=
  match draft? state with
  | .error message => { state with notice := message }
  | .ok draft =>
      match Loam.ExchangeAdmission.admit? world draft with
      | .error message => { state with notice := message }
      | .ok _ => { state with mode := .preview draft 0, notice := "" }

/-- Pure local Exchange interaction. Durable publication stays in the session shell. -/
def update
    (world : Loam.ExchangeAdmission.World)
    (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
      match state.mode with
      | .preview draft choice =>
          match key with
          | .tab | .right =>
              { state := { state with
                  mode := .preview draft (Loam.Tui.CyclicIndex.forward 3 choice) } }
          | .shiftTab | .left =>
              { state := { state with
                  mode := .preview draft (Loam.Tui.CyclicIndex.backward 3 choice) } }
          | .input 'e' | .input 'E' =>
              { state := { state with mode := .editing, notice := "" } }
          | .enter =>
              if choice = 0 then
                { state, publish := some draft }
              else if choice = 1 then
                { state := { state with mode := .editing, notice := "" } }
              else
                { state, cancel := true }
          | _ => { state }
      | .editing =>
          match key with
          | .tab => { state := { state with form := moveFocus state.form false } }
          | .shiftTab => { state := { state with form := moveFocus state.form true } }
          | .backspace =>
              { state := { state with form := editActive state.form Loam.Tui.Terminal.backspaceText, notice := "" } }
          | .input char =>
              { state := { state with
                  form := editActive state.form (fun text => text.push char)
                  notice := "" } }
          | .enter =>
              if state.form.focus < 7 then
                { state := { state with form := moveFocus state.form false } }
              else if state.form.focus = 7 || state.form.focus = previewAction then
                { state := enterPreview world state }
              else
                { state, cancel := true }
          | _ => { state }

def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def field (width : Nat) (form : Form) (index : Nat) (label text : String) : Widget :=
  let caption := Loam.Tui.Layout.ellipsize (width / 2 - 2) label ++ ": "
  .row [span caption .muted,
    Loam.Tui.Layout.inputSpan (width - Loam.Tui.Layout.displayWidth caption)
      (form.focus = index) text]

private def actionRow (form : Form) : Widget :=
  .row [
    span "[Preview] " (if form.focus = 8 then .selected else .normal),
    span "[Cancel]" (if form.focus = 9 then .selected else .normal)
  ]

private def effectLine
    (metadata : List Loam.MeasurePresentation.Metadata)
    (effect : Effect) : Widget :=
  line (
    "  " ++ effect.locus.token ++ "  " ++
    Loam.MeasurePresentation.formatQuanta
      metadata effect.measure effect.quantity.quanta ++
    " " ++ effect.measure.token)

/-- Render one direct source/destination exchange editor. -/
def viewForContentBounds (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  match state.mode with
  | .editing =>
      let fields := [
        field width state.form 0 "Date" state.form.date,
        field width state.form 1 "Description" state.form.description,
        field width state.form 2 "Source Locus" state.form.sourceLocus,
        field width state.form 3 "Source Measure" state.form.sourceMeasure,
        field width state.form 4 "Source amount" state.form.sourceAmount,
        field width state.form 5 "Destination Locus" state.form.destinationLocus,
        field width state.form 6 "Destination Measure" state.form.destinationMeasure,
        field width state.form 7 "Destination amount" state.form.destinationAmount,
        actionRow state.form]
      let footer := Loam.Tui.Layout.boundFeedbackFooter bounds
        [line state.notice, muted "Tab / Shift-Tab focus   Enter next/preview   Esc cancel"]
      let capacity := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
      let heading := if capacity > fields.length then [line "Exchange / Record"] else []
      let visible := (Loam.Tui.Layout.centeredListWindow fields state.form.focus
        (capacity - heading.length)).map Prod.snd
      .column ((Loam.Tui.Layout.fitWithFooter bounds (heading ++ visible) footer).map
        (Loam.Tui.Layout.clipWidgetRow width))
  | .preview draft choice =>
      let body :=
        [line "Exchange / Preview", line draft.validOn,
         line (draft.description.getD "(no description)")] ++
        draft.effects.map (effectLine state.measurePresentation) ++
        [muted "Exact observed quantities only; no FX rate is inferred."]
      let footer := Loam.Tui.Layout.boundFeedbackFooter bounds
        [.row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice = index then .selected else .normal)),
         muted "Tab select   Enter confirm   e edit   Esc cancel",
         line state.notice]
      .column ((Loam.Tui.Layout.fitWithFooter bounds body footer).map
        (Loam.Tui.Layout.clipWidgetRow width))

def view (state : State) : Widget :=
  viewForContentBounds {width := 80, height := 24} state

end Loam.Tui.Exchange
