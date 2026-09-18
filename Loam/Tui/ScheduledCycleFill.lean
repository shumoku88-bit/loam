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
# Scheduled cycle fill presentation

This is process-local interaction state only. The selected target boundary window
and cadence are meaningful construction input, but neither is retained after
ordinary Scheduled occurrences are published.
-/

abbrev Draft := Loam.ScheduledCreationPublisher.Draft

inductive Scope where
  | current
  | following
  deriving Repr, DecidableEq, BEq

namespace Scope

def label : Scope → String
  | .current => "Current cycle"
  | .following => "Next cycle"

end Scope

inductive Mode where
  | scope (choice : Nat)
  | cadence (choice : Nat)
  | preview (cadence : Loam.ScheduledCycleFill.GenerationCadence)
      (drafts : List Draft) (choice : Nat)

structure State where
  source : Loam.Tui.Main.ScheduledRecord
  currentWindow : Loam.BoundaryPresetConfig.CurrentWindow
  followingWindow : Option Loam.BoundaryPresetConfig.CurrentWindow
  window : Loam.BoundaryPresetConfig.CurrentWindow
  scope : Scope
  observedAt : String
  mode : Mode
  notice : String := ""

structure Step where
  state : State
  cadence : Option Loam.ScheduledCycleFill.GenerationCadence := none
  publish : Bool := false
  cancel : Bool := false

def initial
    (source : Loam.Tui.Main.ScheduledRecord)
    (currentWindow : Loam.BoundaryPresetConfig.CurrentWindow)
    (followingWindow : Option Loam.BoundaryPresetConfig.CurrentWindow)
    (observedAt : String) : State :=
  {
    source
    currentWindow
    followingWindow
    window := currentWindow
    scope := .current
    observedAt
    mode := if followingWindow.isSome then .scope 0 else .cadence 0
  }

private def cadenceAt (choice : Nat) : Loam.ScheduledCycleFill.GenerationCadence :=
  match choice % 3 with
  | 0 => .monthly
  | 1 => .everyTwoMonths
  | _ => .yearly

private def chooseScope (state : State) (choice : Nat) : State :=
  if choice % 2 = 0 then
    { state with
      window := state.currentWindow
      scope := .current
      mode := .cadence 0
      notice := "" }
  else
    match state.followingWindow with
    | some window =>
        { state with
          window := window
          scope := .following
          mode := .cadence 0
          notice := "" }
    | none =>
        { state with
          window := state.currentWindow
          scope := .current
          mode := .cadence 0
          notice := "No explicitly configured following cycle is available." }

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
      | .scope choice =>
          match key with
          | .left | .up | .shiftTab =>
              { state := { state with mode := .scope ((choice + 1) % 2), notice := "" } }
          | .right | .down | .tab =>
              { state := { state with mode := .scope ((choice + 1) % 2), notice := "" } }
          | .enter => { state := chooseScope state choice }
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

private def windowText (window : Loam.BoundaryPresetConfig.CurrentWindow) : String :=
  window.start ++ " <= due < " ++ window.endExclusive

private def scopeView (state : State) (choice : Nat) : Widget :=
  let followingText :=
    match state.followingWindow with
    | some window => windowText window
    | none => "(not explicitly configured)"
  .column
    [ line "Scheduled / Fill Cycle"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose which explicit boundary window to fill:"
    , .row
        [ option (choice % 2 = 0) "Current cycle"
        , option (choice % 2 = 1) "Next cycle"
        ]
    , line ("Current: " ++ windowText state.currentWindow)
    , line ("Next   : " ++ followingText)
    , line ""
    , line "The target window is construction input only; no cycle or recurrence fact is stored."
    , line "Arrows / Tab select   Enter continue   Esc cancel"
    , line state.notice
    ]

private def cadenceView (state : State) (choice : Nat) : Widget :=
  .column
    [ line "Scheduled / Fill Cycle"
    , line ("Source: " ++ state.source.id.token ++ "  " ++ state.source.scheduledOn)
    , line ("Target: " ++ state.scope.label)
    , line ("Cycle: " ++ windowText state.window)
    , line ("Known through: " ++ state.observedAt)
    , line ""
    , line "Choose how this creation action should step through calendar months:"
    , .row
        [ option (choice % 3 = 0) "Monthly"
        , option (choice % 3 = 1) "Every 2 months"
        , option (choice % 3 = 2) "Yearly"
        ]
    , line ""
    , line "Cadence is construction input only; no recurrence authority is retained."
    , line "A source from an earlier cycle may seed this explicit target window."
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
    [ line "Scheduled / Fill Cycle / Final Review"
    , line ("Source: " ++ state.source.id.token)
    , line ("Target: " ++ state.scope.label)
    , line ("Cadence used for this creation: " ++ cadence.label)
    , line ("Cycle: " ++ windowText state.window)
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
  | .scope choice => scopeView state choice
  | .cadence choice => cadenceView state choice
  | .preview cadence drafts choice => previewView state cadence drafts choice

end Loam.Tui.ScheduledCycleFill
