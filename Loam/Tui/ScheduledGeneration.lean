import Loam.ActualDate
import Loam.Config.BoundaryPresetConfig
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Application.ScheduledGeneration
import Loam.Application.ScheduledOccurrenceConstruction
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledGeneration

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Scheduled generation presentation

Boundary presets provide optional presentation suggestions only. The selected
exclusive fill limit and cadence are process-local construction input; neither is
retained after ordinary Scheduled occurrences are published.
-/

abbrev Draft := Loam.ScheduledCreationPublisher.Draft
abbrev Suggestion := Loam.BoundaryPresetConfig.HorizonSuggestion

inductive Mode where
  | horizon (choice : Nat)
  | customDate (value : String)
  | cadence (choice : Nat)
  | preview (cadence : Loam.ScheduledGeneration.GenerationCadence)
      (drafts : List Draft) (choice : Nat)

structure State where
  source : Loam.Tui.Main.ScheduledRecord
  suggestions : List Suggestion
  limit : Loam.ScheduledGeneration.FillLimit
  limitLabel : String := ""
  observedAt : String
  presetCadence : Option Loam.ScheduledGeneration.GenerationCadence := none
  mode : Mode
  notice : String := ""
  reviewRow : Nat := 0

structure Step where
  state : State
  cadence : Option Loam.ScheduledGeneration.GenerationCadence := none
  publish : Bool := false
  cancel : Bool := false

def initial
    (source : Loam.Tui.Main.ScheduledRecord)
    (suggestions : List Suggestion)
    (observedAt : String) : State :=
  let initialEnd := suggestions.head?.map (·.endExclusive) |>.getD observedAt
  {
    source
    suggestions
    limit := { endExclusive := initialEnd }
    observedAt
    mode := .horizon 0
  }

def initialWithCadence
    (source : Loam.Tui.Main.ScheduledRecord)
    (suggestions : List Suggestion)
    (observedAt : String)
    (cadence : Loam.ScheduledGeneration.GenerationCadence) : State :=
  { initial source suggestions observedAt with presetCadence := some cadence }

private def cadenceAt (choice : Nat) : Loam.ScheduledGeneration.GenerationCadence :=
  match choice % 5 with
  | 0 => .monthly
  | 1 => .everyTwoMonths
  | 2 => .everyThreeMonths
  | 3 => .everySixMonths
  | _ => .yearly

private def choiceCount (state : State) : Nat :=
  state.suggestions.length + 1

private def customChoice (state : State) : Nat :=
  state.suggestions.length

private def chooseHorizon (state : State) (choice : Nat) : State :=
  let selected := choice % choiceCount state
  if selected = customChoice state then
    { state with mode := .customDate "", notice := "" }
  else
    match state.suggestions[selected]? with
    | some suggestion =>
        { state with
          limit := { endExclusive := suggestion.endExclusive }
          limitLabel :=
            if state.presetCadence.isSome then suggestion.source
            else "boundary suggestion " ++ suggestion.endExclusive
          mode := .cadence 0
          notice := "" }
    | none =>
        { state with notice := "Selected boundary suggestion is unavailable." }

private def acceptCustomDate (state : State) (value : String) : State :=
  if !Loam.ActualDate.validIsoDate value then
    { state with
      mode := .customDate value
      notice := "Enter a real calendar date in YYYY-MM-DD form." }
  else if !(decide (state.observedAt < value)) then
    { state with
      mode := .customDate value
      notice := "Fill-through date must be later than the observation date." }
  else if !(decide (state.source.scheduledOn < value)) then
    { state with
      mode := .customDate value
      notice := "Fill-through date must be later than the selected source date." }
  else
    { state with
      limit := { endExclusive := value }
      limitLabel := "custom " ++ value
      mode := .cadence 0
      notice := "" }

def withDrafts
    (state : State)
    (cadence : Loam.ScheduledGeneration.GenerationCadence)
    (drafts : List Draft) : State :=
  { state with mode := .preview cadence drafts 0, reviewRow := 0, notice := "" }

def withNotice (state : State) (notice : String) : State :=
  { state with notice := notice }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .customDate value =>
      match key with
      | .escape =>
          { state := { state with mode := .horizon (customChoice state), notice := "" } }
      | .backspace =>
          { state := { state with
              mode := .customDate (Loam.Tui.Terminal.backspaceText value)
              notice := "" } }
      | .input char =>
          { state := { state with mode := .customDate (value.push char), notice := "" } }
      | .enter =>
          let next := acceptCustomDate state value
          match next.presetCadence, next.mode with
          | some cadence, .cadence _ => { state := next, cadence := some cadence }
          | _, _ => { state := next }
      | _ => { state }
  | .horizon choice =>
      match key with
      | .escape => { state, cancel := true }
      | .left | .up | .shiftTab =>
          let count := choiceCount state
          { state := { state with mode := .horizon ((choice + count - 1) % count), notice := "" } }
      | .right | .down | .tab =>
          { state := { state with mode := .horizon ((choice + 1) % choiceCount state), notice := "" } }
      | .enter =>
          let next := chooseHorizon state choice
          match next.presetCadence, next.mode with
          | some cadence, .cadence _ => { state := next, cadence := some cadence }
          | _, _ => { state := next }
      | _ => { state }
  | .cadence choice =>
      match key with
      | .escape => { state := { state with mode := .horizon 0, notice := "" } }
      | .left | .up | .shiftTab =>
          { state := { state with mode := .cadence ((choice + 4) % 5), notice := "" } }
      | .right | .down | .tab =>
          { state := { state with mode := .cadence ((choice + 1) % 5), notice := "" } }
      | .enter => { state, cadence := some (cadenceAt choice) }
      | _ => { state }
  | .preview cadence drafts choice =>
      match key with
      | .escape => { state, cancel := true }
      | .up | .input 'k' =>
          { state := { state with reviewRow := state.reviewRow - 1 } }
      | .down | .input 'j' =>
          { state := { state with reviewRow := min (drafts.length - 1) (state.reviewRow + 1) } }
      | .home => { state := { state with reviewRow := 0 } }
      | .«end» => { state := { state with reviewRow := drafts.length - 1 } }
      | .left | .right | .tab | .shiftTab =>
          { state := { state with mode := .preview cadence drafts ((choice + 1) % 2) } }
      | .enter =>
          if choice % 2 = 0 then { state, publish := true }
          else { state, cancel := true }
      | _ => { state }

private def line (text : String) : Widget := .row [span text]

private def option
    (selected : Bool) (label : String) : Span :=
  span ("[" ++ label ++ "] ") (if selected then .selected else .normal)

private def suggestionText (suggestion : Suggestion) : String :=
  suggestion.endExclusive ++
    "   (" ++ suggestion.start ++ " <= boundary window < " ++ suggestion.endExclusive ++ ")"

private def actionTitle (state : State) : String :=
  if state.presetCadence.isSome then "Scheduled / Extend Plan"
  else "Scheduled / Generate Plans"


/-- Stable two-row action/notice area. Long information remains in the owning
    state; a narrow terminal only clips its presentation. -/
private def footer (bounds : Bounds) (state : State) (help : String) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  [ .row [span (Loam.Tui.Layout.ellipsize width state.notice) .muted]
  , .row [span (Loam.Tui.Layout.ellipsize width help) .muted]
  ]

private def clippedLine (bounds : Bounds) (text : String) (style : Style := .normal) : Widget :=
  .row [span (Loam.Tui.Layout.ellipsize (Loam.Tui.Layout.contentWidth bounds) text) style]

/-- Reuse the existing panel and centered scrolling mechanics for option lists,
    without making their selection a separate TUI or domain model. -/
private def optionRows (bounds : Bounds) (title : String)
    (items : List Widget) (selected available : Nat) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let framed := width >= 24 && available >= 5
  let capacity := if framed then available - 2 else available
  let rows := (Loam.Tui.Layout.centeredListWindow items selected capacity).map Prod.snd
  if framed then
    Loam.Tui.Layout.widgetRows <|
      Loam.Tui.Layout.framedPanel width (min available (rows.length + 2))
        title (.column rows) true
  else rows

private def finish (bounds : Bounds) (body foot : List Widget) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  .column <| Loam.Tui.Layout.fitWithFooter bounds
    (body.map (Loam.Tui.Layout.clipWidgetRow width))
    (foot.map (Loam.Tui.Layout.clipWidgetRow width))

private def horizonView (bounds : Bounds) (state : State) (choice : Nat) : Widget := Id.run do
  let selected := choice % choiceCount state
  let foot := footer bounds state
    (if bounds.width < 50 then "Up/Dn select  Enter next  Esc" else
      "Arrows/Tab select  Enter continue  Esc cancel")
  let short := bounds.height < 16
  let header := [clippedLine bounds (actionTitle state),
    clippedLine bounds ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)] ++
    (if short then [] else [clippedLine bounds ("Known through: " ++ state.observedAt) .muted]) ++
    (match state.presetCadence with
     | some cadence => [clippedLine bounds ("Pattern: " ++ cadence.label)]
     | none => [])
  let notes :=
    if bounds.height >= 21 then
      if state.presetCadence.isSome then
        [clippedLine bounds "Only reviewed explicit dates will be created." .muted]
      else
        [clippedLine bounds "Boundary dates are suggestions only." .muted,
         clippedLine bounds "No automatic future recurrence is retained." .muted]
    else []
  let entries := (state.suggestions.zipIdx.map fun (suggestion, index) =>
    let label := if state.presetCadence.isSome then suggestion.source
      else "through " ++ suggestionText suggestion
    .row [span ((if selected == index then "> " else "  ") ++ label)
      (if selected == index then .selected else .normal)]) ++
    [.row [span ((if selected == customChoice state then "> " else "  ") ++ "Custom date…")
      (if selected == customChoice state then .selected else .normal)]]
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length -
    header.length - notes.length
  return finish bounds
    (header ++ optionRows bounds "Fill horizon" entries selected available ++ notes) foot

private def customDateView (bounds : Bounds) (state : State) (value : String) : Widget :=
  let foot := footer bounds state
    (if bounds.width < 50 then "Enter next  Backspace  Esc" else
      "Enter continue  Backspace edit  Esc back")
  let label := if bounds.width < 50 then "Fill through: " else "Fill through (exclusive): "
  let width := Loam.Tui.Layout.contentWidth bounds
  let input := .row [span label .muted,
    Loam.Tui.Layout.inputSpan (width - Loam.Tui.Layout.displayWidth label) true value]
  finish bounds
    ([clippedLine bounds (actionTitle state ++ " / Custom Fill Date"),
      clippedLine bounds ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn),
      clippedLine bounds ("Known through: " ++ state.observedAt) .muted,
      input] ++
      (if bounds.height >= 16 then
        [clippedLine bounds "YYYY-MM-DD; not necessarily a household boundary." .muted]
       else []))
    foot

private def cadenceView (bounds : Bounds) (state : State) (choice : Nat) : Widget := Id.run do
  let foot := footer bounds state
    (if bounds.width < 50 then "Up/Dn select  Enter next  Esc" else
      "Arrows/Tab select  Enter continue  Esc back")
  let header := [clippedLine bounds (actionTitle state),
    clippedLine bounds ("Fill through: " ++ state.limit.endExclusive)] ++
    (if bounds.height >= 16 then
      [clippedLine bounds ("Source: " ++ state.source.id.token ++
        "  Known through: " ++ state.observedAt) .muted] else [])
  let labels := ["Monthly", "Every 2 months", "Every 3 months", "Every 6 months", "Yearly"]
  let selected := choice % labels.length
  let entries := labels.zipIdx.map fun (label, index) =>
    .row [span ((if selected == index then "> " else "  ") ++ label)
      (if selected == index then .selected else .normal)]
  let notes := if bounds.height >= 21 then
    [clippedLine bounds "A cadence generates only the dates you explicitly review." .muted,
     clippedLine bounds "Each occurrence is edited separately before publishing." .muted]
    else []
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length -
    header.length - notes.length
  return finish bounds (header ++
    optionRows bounds "Construction cadence" entries selected available ++ notes) foot

private def draftSummary (index : Nat) (draft : Draft) (selected : Bool) : Widget :=
  .row [span ((if selected then "> " else "  ") ++
    toString (index + 1) ++ ". " ++ draft.scheduledOn ++ "  " ++
    toString (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++
    " " ++ draft.movement.measure.token)
    (if selected then .selected else .normal)]

private def previewView (bounds : Bounds) (state : State)
    (cadence : Loam.ScheduledGeneration.GenerationCadence)
    (drafts : List Draft) (choice : Nat) : Widget := Id.run do
  let foot := footer bounds state
    (if bounds.width < 50 then "j/k rows  Tab action  Enter" else
      "j/k review  Tab/Arrows action  Enter confirm  Esc cancel")
  let header := [clippedLine bounds (actionTitle state ++ " / Final Review"),
    clippedLine bounds ("Explicit Scheduled drafts: " ++ toString drafts.length)] ++
    (if bounds.height >= 16 then
      [clippedLine bounds ("Fill through: " ++ state.limit.endExclusive ++
        "  Cadence: " ++ cadence.label) .muted] else [])
  let actions := .row
    [ option (choice % 2 == 0) "Publish all"
    , option (choice % 2 == 1) "Cancel" ]
  let notes := if bounds.height >= 21 then
    [clippedLine bounds "Only the edited dates/amounts are published; no recurrence is stored." .muted]
    else []
  let available := Loam.Tui.Layout.footerBodyCapacity bounds foot.length -
    header.length - notes.length - 1
  let selected := min state.reviewRow (drafts.length - 1)
  let entries := drafts.zipIdx.map fun (draft, index) =>
    draftSummary index draft (index == selected)
  let rows := optionRows bounds "Reviewed occurrences" entries selected available
  return finish bounds (header ++ rows ++ notes ++ [actions]) foot

/-- A bounded, resize-ready view; no review or publication authority lives here. -/
def view (bounds : Bounds) (state : State) : Widget :=
  match state.mode with
  | .horizon choice => horizonView bounds state choice
  | .customDate value => customDateView bounds state value
  | .cadence choice => cadenceView bounds state choice
  | .preview cadence drafts choice => previewView bounds state cadence drafts choice

end Loam.Tui.ScheduledGeneration
