import Loam.BoundaryPresetConfig
import Loam.ScheduledCreationPublisher
import Loam.ScheduledCycleFill
import Loam.ScheduledOccurrenceConstruction
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCycleFill

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Scheduled fill-through-horizon presentation

This is process-local interaction state only. The selected boundary suggestion and
cadence are meaningful construction input, but neither is retained after
ordinary Scheduled occurrences are published.
-/

abbrev Draft := Loam.ScheduledCreationPublisher.Draft
abbrev Horizon := Loam.BoundaryPresetConfig.HorizonSuggestion

inductive Mode where
  | horizon (choice : Nat)
  | cadence (choice : Nat)
  | preview (cadence : Loam.ScheduledCycleFill.GenerationCadence)
      (drafts : List Draft) (choice : Nat)

structure State where
  source : Loam.Tui.Main.ScheduledRecord
  horizons : List Horizon
  horizon : Horizon
  observedAt : String
  mode : Mode
  notice : String := ""

structure Step where
  state : State
  cadence : Option Loam.ScheduledCycleFill.GenerationCadence := none
  publish : Bool := false
  cancel : Bool := false

def initial?
    (source : Loam.Tui.Main.ScheduledRecord)
    (horizons : List Horizon)
    (observedAt : String) : Option State := do
  let first ← horizons.head?
  pure {
    source
    horizons
    horizon := first
    observedAt
    mode := if horizons.length > 1 then .horizon 0 else .cadence 0
  }

private def cadenceAt (choice : Nat) : Loam.ScheduledCycleFill.GenerationCadence :=
  match choice % 3 with
  | 0 => .monthly
  | 1 => .everyTwoMonths
  | _ => .yearly

private def chooseHorizon (state : State) (choice : Nat) : State :=
  let count := state.horizons.length
  if count = 0 then
    { state with notice := "No boundary horizon suggestion is available." }
  else
    match state.horizons[choice % count]? with
    | some horizon =>
        { state with horizon := horizon, mode := .cadence 0, notice := "" }
    | none =>
        { state with notice := "Selected fill horizon is unavailable." }

def withDrafts
    (state : State)
    (cadence : Loam.ScheduledCycleFill.GenerationCadence)
    (drafts : List Draft) : State :=
  { state with mode := .preview cadence drafts 0, notice := "" }

def withNotice (state : State) (notice : String) : State :=
  { state with notice := notice }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
      match state.mode with
      | .horizon choice =>
          let count := state.horizons.length
          let previous := if count = 0 then 0 else (choice + count - 1) % count
          let next := if count = 0 then 0 else (choice + 1) % count
          match key with
          | .left | .up | .shiftTab =>
              { state := { state with mode := .horizon previous, notice := "" } }
          | .right | .down | .tab =>
              { state := { state with mode := .horizon next, notice := "" } }
          | .enter => { state := chooseHorizon state choice }
          | _ => { state }
      | .cadence choice =>
          match key with
          | .left | .up | .shiftTab =>
              { state := { state with mode := .cadence ((choice + 2) % 3), notice := "" } }
          | .right | .down | .tab =>
              { state := { state with mode := .cadence ((choice + 1) % 3), notice := "" } }
          | .enter => { state, cadence := some (cadenceAt choice) }
          | _ => { state }
      | .preview cadence drafts choice =>
          match key with
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

private def horizonText (horizon : Horizon) : String :=
  horizon.start ++ " <= due < " ++ horizon.endExclusive

private def horizonView (state : State) (choice : Nat) : Widget :=
  let count := state.horizons.length
  let rows := state.horizons.zipIdx.map fun (horizon, index) =>
    .row
      [ span (if count > 0 && index = choice % count then " > " else "   ")
          (if count > 0 && index = choice % count then .selected else .normal)
      , span ("through boundary " ++ horizon.endExclusive ++
          "   (" ++ horizonText horizon ++ ")")
      ]
  .column <|
    [ line "Scheduled / Fill Plans"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose how far to fill using only explicitly configured boundaries:"
    ] ++ rows ++
    [ line ""
    , line "The horizon is construction input only; no cycle or recurrence fact is stored."
    , line "Arrows / Tab select   Enter continue   Esc cancel"
    , line state.notice
    ]

private def cadenceView (state : State) (choice : Nat) : Widget :=
  .column
    [ line "Scheduled / Fill Plans"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Horizon: " ++ horizonText state.horizon)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose how this one creation action should step through calendar months:"
    , .row
        [ option (choice % 3 = 0) "Monthly"
        , option (choice % 3 = 1) "Every 2 months"
        , option (choice % 3 = 2) "Yearly"
        ]
    , line ""
    , line "Cadence is construction input only; no recurrence authority is retained."
    , line "An older source may seed every explicit slot through this horizon."
    , line "Each generated occurrence will be editable before the final publish review."
    , line "Arrows / Tab select   Enter continue   Esc cancel"
    , line state.notice
    ]

private def draftSummary (index : Nat) (draft : Draft) : Widget :=
  line
    ("  " ++ toString (index + 1) ++ ". " ++ draft.scheduledOn ++
     "  " ++ toString
       (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++ " jpy")

private def previewView
    (state : State)
    (cadence : Loam.ScheduledCycleFill.GenerationCadence)
    (drafts : List Draft)
    (choice : Nat) : Widget :=
  .column <|
    [ line "Scheduled / Fill Plans / Final Review"
    , line ("Source: " ++ state.source.id.token)
    , line ("Horizon: " ++ horizonText state.horizon)
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
  | .cadence choice => cadenceView state choice
  | .preview cadence drafts choice => previewView state cadence drafts choice

end Loam.Tui.ScheduledCycleFill
