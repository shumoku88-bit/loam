import Loam.Config.ScheduledCoverageConfig
import Loam.Review.ScheduledCoverageSelector
import Loam.Review.ScheduledReview
import Loam.Tui.Layout
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCoverageSetup

open Loam.Tui.Kernel

set_option autoImplicit false

abbrev Record := Loam.Tui.Main.ScheduledRecord

structure CadenceChoice where
  label : String
  months : Nat
  deriving Repr, DecidableEq

def choices : List CadenceChoice :=
  [ { label := "Monthly", months := 1 }
  , { label := "Every 2 months", months := 2 }
  , { label := "Every 3 months", months := 3 }
  , { label := "Every 6 months", months := 6 }
  , { label := "Yearly", months := 12 }
  ]

structure State where
  source : Record
  selection : Nat := 0
  notice : String := ""

inductive Action where
  | save (months : Nat)
  | cancel
  deriving Repr, DecidableEq

structure Step where
  state : State
  action : Option Action := none

def initial (source : Record) : State := { source := source }

def cadenceLabel (months : Nat) : String :=
  match choices.find? (fun choice => choice.months == months) with
  | some choice => choice.label
  | none => "Every " ++ toString months ++ " months"

/--
Build one monitoring rule from an already explicit Scheduled occurrence.

The selected occurrence supplies the anchor and exact signed-Locus shape. The
human supplies only the expected month cadence. Amounts are deliberately absent
because coverage monitoring already ignores them.
-/
def ruleFor? (source : Record) (months : Nat) :
    Except String Loam.ScheduledCoverageConfig.Rule := do
  if months = 0 then
    throw "Monitoring cadence must be at least one month."
  let shape := Loam.ScheduledCoverageSelector.ofRecord source
  if !shape.usable then
    throw "The selected Scheduled occurrence has no usable signed-Locus shape."
  let name :=
    match shape.positiveLoci with
    | [only] => only
    | _ => source.id.token
  return {
    name := name
    anchor := source.scheduledOn
    everyMonths := months
    negativeLoci := shape.negativeLoci
    positiveLoci := shape.positiveLoci
  }

private def moveSelection (state : State) (back : Bool) : State :=
  if choices.isEmpty then state
  else
    let next :=
      if back then
        if state.selection = 0 then choices.length - 1 else state.selection - 1
      else if state.selection + 1 >= choices.length then
        0
      else
        state.selection + 1
    { state with selection := next, notice := "" }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, action := some .cancel }
  | .up | .input 'k' | .input 'K' | .shiftTab =>
      { state := moveSelection state true }
  | .down | .input 'j' | .input 'J' | .tab =>
      { state := moveSelection state false }
  | .enter =>
      match choices[state.selection]? with
      | some choice => { state, action := some (.save choice.months) }
      | none => { state := { state with notice := "No monitoring cadence is selected." } }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

/-- A bounded selection-following monitoring chooser, matching the creation
    handoff's presentation without changing Scheduled or monitoring authority. -/
def view (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  let help := (Loam.Tui.Layout.wrapColumns width
    "Enter save monitoring  Up/Down choose  Esc cancel").map muted
  let footer := Loam.Tui.Layout.boundFeedbackFooter bounds <|
    (if feedback.isEmpty then [line ""] else feedback) ++ help
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let selected := "Selected: " ++ state.source.scheduledOn ++ "  " ++
    Loam.ScheduledReview.summary state.source
  let header :=
    if available >= 8 then
      [ line "Scheduled / Plan Monitoring"
      , line (Loam.Tui.Layout.clip width selected)
      , muted "Choose the expected pace of explicit plans."
      ]
    else if available >= 5 then
      [ line "Scheduled / Plan Monitoring"
      , line (Loam.Tui.Layout.clip width selected)
      ]
    else
      [line "Scheduled / Plan Monitoring"]
  let note :=
    if available >= 10 then
      [muted "Monitoring only. No future Scheduled is created."] else []
  let height := min (choices.length + 2) (available - header.length - note.length)
  let capacity := height - 2
  let focus := min state.selection (choices.length - 1)
  let start := min (choices.length - capacity)
    (Loam.Tui.Layout.trailingWindowStart focus capacity)
  let visible := ((choices.drop start).take capacity).zipIdx
  let options : List Widget := visible.map fun (choice, index) =>
    let active := start + index == focus
    .row [ span (if active then "> " else "  ") .muted
         , span (Loam.Tui.Layout.clip (width - 4) choice.label)
             (if active then .selected else .normal) ]
  let more := (if start > 0 then " ▲" else "") ++
    (if start + capacity < choices.length then " ▼" else "")
  let panel := Loam.Tui.Layout.framedPanel width height "Expected pace"
    (.column options) true
    (some (s!"{focus + 1}/{choices.length}" ++ more))
  let body : Widget := .column (header ++ [panel] ++ note)
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows body) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)


/-!
## Newly created occurrence handoff

A newly published Scheduled is an individual, explicit occurrence. This optional
follow-up edits only the replaceable coverage-monitoring expectation, never that
Scheduled occurrence or its future instances. In particular, skipping the follow-up
does not remove or overwrite any existing plan monitoring.
-/

structure CreatedPaceState where
  source : Record
  selection : Nat := 0
  notice : String := ""

inductive CreatedPaceAction where
  | keepOne
  | save (months : Nat)
  | undecided

structure CreatedPaceStep where
  state : CreatedPaceState
  action : Option CreatedPaceAction := none

def createdPaceLabels : List String :=
  ["This occurrence only (leave monitoring unchanged)"] ++
    choices.map (·.label) ++
    ["Future pace undecided"]

def updateCreatedPace (state : CreatedPaceState)
    (key : Loam.Tui.Terminal.Key) : CreatedPaceStep :=
  let count := createdPaceLabels.length
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, action := some .keepOne }
  | .up | .left | .shiftTab | .input 'k' | .input 'K' =>
      { state := { state with selection := (state.selection + count - 1) % count } }
  | .down | .right | .tab | .input 'j' | .input 'J' =>
      { state := { state with selection := (state.selection + 1) % count } }
  | .enter =>
      if state.selection == 0 then
        { state, action := some .keepOne }
      else if state.selection == choices.length + 1 then
        { state, action := some .undecided }
      else
        match choices[state.selection - 1]? with
        | some choice => { state, action := some (.save choice.months) }
        | none => { state := { state with notice := "Invalid pace selection." } }
  | _ => { state }

/-- Bounded follow-up: the footer and selected cadence stay visible on short tty. -/
def viewCreatedPace (bounds : Bounds) (state : CreatedPaceState) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback :=
    (Loam.Tui.Layout.wrapColumns width state.notice).map line
  let footer := Loam.Tui.Layout.boundFeedbackFooter bounds <|
    (if feedback.isEmpty then [line ""] else feedback) ++
      [ muted "Enter choose  Up/Down move  Esc keep one" ]
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let height := available - 3
  let capacity := height - 2
  let focus := min state.selection (createdPaceLabels.length - 1)
  let start := min (createdPaceLabels.length - capacity)
    (Loam.Tui.Layout.trailingWindowStart focus capacity)
  let displayed := ((createdPaceLabels.drop start).take capacity).zipIdx
  let options : List Widget := displayed.map fun (label, index) =>
    let selected := start + index == focus
    .row [span (if selected then "> " else "  ") .muted,
      span (Loam.Tui.Layout.clip (width - 4) label)
        (if selected then .selected else .normal)]
  let more := (if start > 0 then " ▲" else "") ++
    (if start + capacity < createdPaceLabels.length then " ▼" else "")
  let panel := Loam.Tui.Layout.framedPanel width height "Expected pace"
    (.column options) true
    (some (s!"{focus + 1}/{createdPaceLabels.length}" ++ more))
  let body : Widget := .column
    [ line "Scheduled / Created / Expected pace"
    , .row [span (Loam.Tui.Layout.clip width
        ("Published " ++ state.source.scheduledOn ++
          ". Configure monitoring?"))]
    , panel
    , muted "No future Scheduled is created here."
    ]
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows body) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)

end Loam.Tui.ScheduledCoverageSetup
