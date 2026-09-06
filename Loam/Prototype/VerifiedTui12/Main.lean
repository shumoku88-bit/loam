import Loam.Prototype.VerifiedTui11.Main

namespace Loam.Prototype.VerifiedTui12.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

abbrev Snapshot := Loam.Prototype.VerifiedTui11.Main.Snapshot
abbrev BaseState := Loam.Prototype.VerifiedTui11.Main.State
abbrev ScheduledRecord := Loam.Prototype.VerifiedTui11.Main.ScheduledRecord
abbrev ScheduledEvidence := Loam.Prototype.VerifiedTui11.Main.ScheduledEvidence

/--
Prototype 12 wraps the already-qualified Prototype 11 state instead of replacing it.
Actual keeps its existing Home/Browse/Detail model. Scheduled adds exactly one new
read-only workspace surface carrying the Home state it was opened from.
-/
inductive Surface where
  | base (state : BaseState)
  | scheduled (home : BaseState)

structure State where
  surface : Surface := .base Loam.Prototype.VerifiedTui11.Main.initialState

inductive Event where
  | left
  | right
  | up
  | down
  | tab
  | enter
  | back
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false


def initialState : State := {}

private def delegateBase
    (snapshot : Snapshot) (state : State)
    (event : Loam.Prototype.VerifiedTui11.Main.Event) : Step :=
  match state.surface with
  | .scheduled _ => { state }
  | .base base =>
      let step := Loam.Prototype.VerifiedTui11.Main.update snapshot base event
      { state := { surface := .base step.state }, quit := step.quit }

/--
`Enter` remains Actual. `Tab` is a deliberately provisional one-key entrance to
Scheduled so this experiment can pressure-test the workspace without first adding
Home target state or a generic router.
-/
def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left => delegateBase snapshot state .left
  | .right => delegateBase snapshot state .right
  | .up => delegateBase snapshot state .up
  | .down => delegateBase snapshot state .down
  | .tab =>
      match state.surface with
      | .scheduled _ => { state }
      | .base base =>
          match base.surface with
          | .home _ => { state := { surface := .scheduled base } }
          | .actual _ _ => { state }
  | .enter => delegateBase snapshot state .enter
  | .back =>
      match state.surface with
      | .scheduled home => { state := { surface := .base home } }
      | .base _ => delegateBase snapshot state .back
  | .other => { state }


def baseState (state : State) : BaseState :=
  match state.surface with
  | .base base => base
  | .scheduled home => home


def selectedDate (state : State) : String :=
  Loam.Prototype.VerifiedTui11.Main.selectedDate (baseState state)

/-- The Scheduled workspace consumes the exact same open-world day answer as Home. -/
def scheduledWorkspaceEvidence (snapshot : Snapshot) (state : State) : ScheduledEvidence :=
  Loam.Prototype.VerifiedTui11.Main.homeScheduledEvidence snapshot (baseState state)


theorem scheduled_workspace_uses_selected_day
    (snapshot : Snapshot) (state : State) :
    scheduledWorkspaceEvidence snapshot state =
      Loam.Application.currentScheduledDayEvidenceWithReplacement
        snapshot.scheduled.scheduled
        snapshot.scheduled.completions
        snapshot.scheduled.retirements
        snapshot.scheduled.replacements
        snapshot.scheduled.events
        (selectedDate state) := by
  rfl


theorem back_from_scheduled_restores_exact_home
    (snapshot : Snapshot) (home : BaseState) :
    (update snapshot { surface := .scheduled home } .back).state.surface = .base home := by
  rfl


theorem back_from_scheduled_preserves_day
    (snapshot : Snapshot) (home : BaseState) :
    selectedDate ((update snapshot { surface := .scheduled home } .back).state) =
      Loam.Prototype.VerifiedTui11.Main.selectedDate home := by
  rfl

private def scheduledRecordLine (record : ScheduledRecord) : Widget :=
  let text := Loam.ActualReview.shortText 56 (Loam.ScheduledReview.summary record)
  let scheduledId := Loam.ActualReview.shortText 14 record.id.token
  .row
    [ span "- " .muted
    , span text
    , span (" [" ++ scheduledId ++ "]") .muted
    ]

private def refusedScheduledWorkspace
    (date : String) (message : String) : Widget :=
  .column
    [ Loam.Prototype.VerifiedTui09.Main.plainLine
        "Scheduled workspace / Refused  [CANONICAL READ-ONLY]"
    , Loam.Prototype.VerifiedTui09.Main.mutedLine "Home > Scheduled"
    , Loam.Prototype.VerifiedTui09.Main.plainLine date
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , Loam.Prototype.VerifiedTui09.Main.plainLine message
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , Loam.Prototype.VerifiedTui09.Main.mutedLine "b Home    q Quit"
    ]


def scheduledWorkspaceView (snapshot : Snapshot) (home : BaseState) : Widget :=
  let date := Loam.Prototype.VerifiedTui11.Main.selectedDate home
  match Loam.Prototype.VerifiedTui11.Main.homeScheduledEvidence snapshot home with
  | .due first rest =>
      let all := first :: rest
      let displayed := all.take 10
      .column <|
        [ Loam.Prototype.VerifiedTui09.Main.plainLine
            "Scheduled workspace / Due  [CANONICAL READ-ONLY]"
        , Loam.Prototype.VerifiedTui09.Main.mutedLine "Home > Scheduled"
        , Loam.Prototype.VerifiedTui09.Main.plainLine date
        , Loam.Prototype.VerifiedTui09.Main.mutedLine
            (toString all.length ++ " explicit current-open occurrence(s) on this day.")
        , Loam.Prototype.VerifiedTui09.Main.blankLine
        ] ++
        displayed.map scheduledRecordLine ++
        [ Loam.Prototype.VerifiedTui09.Main.blankLine
        , Loam.Prototype.VerifiedTui09.Main.mutedLine
            "This is Scheduled expectation evidence, not Actual evidence."
        , Loam.Prototype.VerifiedTui09.Main.mutedLine
            "No recurrence or completeness is inferred beyond retained evidence."
        , Loam.Prototype.VerifiedTui09.Main.blankLine
        , Loam.Prototype.VerifiedTui09.Main.mutedLine "b Home    q Quit"
        ]
  | .unknown =>
      .column
        [ Loam.Prototype.VerifiedTui09.Main.plainLine
            "Scheduled workspace / Unknown  [CANONICAL READ-ONLY]"
        , Loam.Prototype.VerifiedTui09.Main.mutedLine "Home > Scheduled"
        , Loam.Prototype.VerifiedTui09.Main.plainLine date
        , Loam.Prototype.VerifiedTui09.Main.blankLine
        , Loam.Prototype.VerifiedTui09.Main.plainLine
            "No explicit current-open Scheduled evidence is retained for this day."
        , Loam.Prototype.VerifiedTui09.Main.mutedLine
            "Unknown is not NotDue; LOAM has no completeness horizon here."
        , Loam.Prototype.VerifiedTui09.Main.blankLine
        , Loam.Prototype.VerifiedTui09.Main.mutedLine "b Home    q Quit"
        ]
  | .unknownCompletionScheduled =>
      refusedScheduledWorkspace date "Completion evidence references an unknown Scheduled identity."
  | .unknownRetirementScheduled =>
      refusedScheduledWorkspace date "Retirement evidence references an unknown Scheduled identity."
  | .unknownReplacementScheduled =>
      refusedScheduledWorkspace date "Replacement evidence references an unknown Scheduled identity."
  | .invalidReplacementGraph =>
      refusedScheduledWorkspace date "Scheduled replacement topology is invalid."
  | .conflictingTerminalEvidence =>
      refusedScheduledWorkspace date "Scheduled terminal evidence conflicts."

private def homeWithScheduledHint (snapshot : Snapshot) (base : BaseState) : Widget :=
  let hint :=
    if base.notice.isEmpty then
      "Prototype 12: Tab opens the Scheduled workspace."
    else
      base.notice ++ "  |  Tab opens Scheduled workspace."
  Loam.Prototype.VerifiedTui11.Main.homeView snapshot { base with notice := hint }


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .scheduled home => scheduledWorkspaceView snapshot home
  | .base base =>
      match base.surface with
      | .home _ => homeWithScheduledHint snapshot base
      | .actual _ _ => Loam.Prototype.VerifiedTui11.Main.view snapshot base


def screenBounds : Bounds :=
  Loam.Prototype.VerifiedTui11.Main.screenBounds


def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui12.Main
