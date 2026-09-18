import Loam.ActualDate
import Loam.BoundaryPresetConfig
import Loam.ScheduledCreationPublisher
import Loam.ScheduledGeneration
import Loam.ScheduledOccurrenceConstruction
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
  mode : Mode
  notice : String := ""

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

private def cadenceAt (choice : Nat) : Loam.ScheduledGeneration.GenerationCadence :=
  match choice % 3 with
  | 0 => .monthly
  | 1 => .everyTwoMonths
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
          limitLabel := "boundary suggestion " ++ suggestion.endExclusive
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
  { state with mode := .preview cadence drafts 0, notice := "" }

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
              mode := .customDate (String.ofList value.toList.dropLast)
              notice := "" } }
      | .input char =>
          { state := { state with mode := .customDate (value.push char), notice := "" } }
      | .enter => { state := acceptCustomDate state value }
      | _ => { state }
  | .horizon choice =>
      match key with
      | .escape => { state, cancel := true }
      | .left | .up | .shiftTab =>
          let count := choiceCount state
          { state := { state with mode := .horizon ((choice + count - 1) % count), notice := "" } }
      | .right | .down | .tab =>
          { state := { state with mode := .horizon ((choice + 1) % choiceCount state), notice := "" } }
      | .enter => { state := chooseHorizon state choice }
      | _ => { state }
  | .cadence choice =>
      match key with
      | .escape => { state := { state with mode := .horizon 0, notice := "" } }
      | .left | .up | .shiftTab =>
          { state := { state with mode := .cadence ((choice + 2) % 3), notice := "" } }
      | .right | .down | .tab =>
          { state := { state with mode := .cadence ((choice + 1) % 3), notice := "" } }
      | .enter => { state, cadence := some (cadenceAt choice) }
      | _ => { state }
  | .preview cadence drafts choice =>
      match key with
      | .escape => { state, cancel := true }
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

private def horizonView (state : State) (choice : Nat) : Widget :=
  let count := choiceCount state
  let selected := choice % count
  let rows := state.suggestions.zipIdx.map fun (suggestion, index) =>
    .row
      [ span (if index = selected then " > " else "   ")
          (if index = selected then .selected else .normal)
      , span ("through " ++ suggestionText suggestion)
      ]
  let customRow : Widget :=
    .row
      [ span (if selected = customChoice state then " > " else "   ")
          (if selected = customChoice state then .selected else .normal)
      , span "Custom date…"
      ]
  .column <|
    [ line "Scheduled / Generate Plans"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose how far to generate:"
    ] ++ rows ++ [customRow] ++
    [ line ""
    , line "Boundary dates are suggestions only. Custom dates use the same generator."
    , line "No fill limit, cadence, cycle, or recurrence fact is stored."
    , line "Arrows / Tab select   Enter continue   Esc cancel"
    , line state.notice
    ]

private def customDateView (state : State) (value : String) : Widget :=
  .column
    [ line "Scheduled / Generate Plans / Custom Fill Date"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , .row [span "Fill through (exclusive): ", span (if value.isEmpty then "_" else value) .selected]
    , line ""
    , line "Type YYYY-MM-DD. The date need not be a household boundary."
    , line "Enter continue   Backspace edit   Esc back"
    , line state.notice
    ]

private def cadenceView (state : State) (choice : Nat) : Widget :=
  .column
    [ line "Scheduled / Generate Plans"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Fill through: " ++ state.limit.endExclusive)
    , line (if state.limitLabel.isEmpty then "" else "Source: " ++ state.limitLabel)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose how this one construction action should step through calendar months:"
    , .row
        [ option (choice % 3 = 0) "Monthly"
        , option (choice % 3 = 1) "Every 2 months"
        , option (choice % 3 = 2) "Yearly"
        ]
    , line ""
    , line "Cadence is construction input only; no recurrence authority is retained."
    , line "An older source may seed every explicit slot before the chosen fill limit."
    , line "Each generated occurrence will be editable before the final publish review."
    , line "Arrows / Tab select   Enter continue   Esc back"
    , line state.notice
    ]

private def draftSummary (index : Nat) (draft : Draft) : Widget :=
  line
    ("  " ++ toString (index + 1) ++ ". " ++ draft.scheduledOn ++
     "  " ++ toString
       (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++ " jpy")

private def previewView
    (state : State)
    (cadence : Loam.ScheduledGeneration.GenerationCadence)
    (drafts : List Draft)
    (choice : Nat) : Widget :=
  .column <|
    [ line "Scheduled / Generate Plans / Final Review"
    , line ("Source: " ++ state.source.id.token)
    , line ("Fill through: " ++ state.limit.endExclusive)
    , line ("Cadence used for this creation: " ++ cadence.label)
    , line ""
    , line "Explicit Scheduled drafts:"
    ] ++
    (drafts.zipIdx.map fun (draft, index) => draftSummary index draft) ++
    [ line ""
    , line "These dates and amounts were individually reviewed. Cadence will not be stored."
    , .row
        [ option (choice % 2 = 0) "Publish all"
        , option (choice % 2 = 1) "Cancel"
        ]
    , line "Tab / arrows select   Enter confirm   Esc cancel"
    , line state.notice
    ]

def view (state : State) : Widget :=
  match state.mode with
  | .horizon choice => horizonView state choice
  | .customDate value => customDateView state value
  | .cadence choice => cadenceView state choice
  | .preview cadence drafts choice => previewView state cadence drafts choice

end Loam.Tui.ScheduledGeneration
