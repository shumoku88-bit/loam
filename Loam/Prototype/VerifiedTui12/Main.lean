import Loam.Prototype.VerifiedTui11.Main

namespace Loam.Prototype.VerifiedTui12.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

abbrev Snapshot := Loam.Prototype.VerifiedTui11.Main.Snapshot
abbrev BaseState := Loam.Prototype.VerifiedTui11.Main.State
abbrev ReviewRecord := Loam.Prototype.VerifiedTui11.Main.ReviewRecord
abbrev ScheduledRecord := Loam.Prototype.VerifiedTui11.Main.ScheduledRecord
abbrev ScheduledEvidence := Loam.Prototype.VerifiedTui11.Main.ScheduledEvidence

inductive HomeTarget where
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

/--
Prototype 12 wraps the already-qualified Prototype 11 state instead of replacing it.
Actual keeps its existing Home/Browse/Detail model. Scheduled adds exactly one new
read-only workspace surface, carrying the Home state it was opened from so the same
SelectedDay is restored exactly on Back.
-/
inductive Surface where
  | base (state : BaseState)
  | scheduled (home : BaseState)

structure State where
  surface : Surface := .base Loam.Prototype.VerifiedTui11.Main.initialState
  target : HomeTarget := .actual

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


def toggleTarget : HomeTarget → HomeTarget
  | .actual => .scheduled
  | .scheduled => .actual

private def delegateBase
    (snapshot : Snapshot) (state : State)
    (event : Loam.Prototype.VerifiedTui11.Main.Event) : Step :=
  match state.surface with
  | .scheduled _ => { state }
  | .base base =>
      let step := Loam.Prototype.VerifiedTui11.Main.update snapshot base event
      { state := { state with surface := .base step.state }, quit := step.quit }


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
          | .home _ => { state := { state with target := toggleTarget state.target } }
          | .actual _ _ => { state }
  | .enter =>
      match state.surface with
      | .scheduled _ => { state }
      | .base base =>
          match base.surface with
          | .home _ =>
              match state.target with
              | .scheduled => { state := { state with surface := .scheduled base } }
              | .actual => delegateBase snapshot state .enter
          | .actual _ _ => delegateBase snapshot state .enter
  | .back =>
      match state.surface with
      | .scheduled home => { state := { state with surface := .base home } }
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
    (snapshot : Snapshot) (home : BaseState) (target : HomeTarget) :
    (update snapshot { surface := .scheduled home, target := target } .back).state.surface =
      .base home := by
  rfl


theorem back_from_scheduled_preserves_day
    (snapshot : Snapshot) (home : BaseState) (target : HomeTarget) :
    selectedDate ((update snapshot { surface := .scheduled home, target := target } .back).state) =
      Loam.Prototype.VerifiedTui11.Main.selectedDate home := by
  rfl

private def scheduledAt? : List ScheduledRecord → Nat → Option ScheduledRecord
  | [], _ => none
  | record :: _, 0 => some record
  | _ :: records, index + 1 => scheduledAt? records index

private def targetHeaderSpans
    (selected : Bool) (text : String) : List Span :=
  let marker := if selected then "▶ " else "  "
  [ span marker .muted
  , span text (if selected then .selected else .normal)
  ]

private def actualPreviewSpans
    (snapshot : Snapshot) (base : BaseState) (index : Nat) : List Span :=
  match Loam.Prototype.VerifiedTui10.Main.recordAt?
      (Loam.Prototype.VerifiedTui11.Main.homeActualPreviewRecords snapshot base) index with
  | none => [span ""]
  | some record =>
      let description :=
        if record.description.isEmpty then "(no description)"
        else Loam.ActualReview.shortText 18 record.description
      let eventId := Loam.ActualReview.shortText 10 record.event.id.token
      [ span "- " .muted
      , span description
      , span (" [" ++ eventId ++ "]") .muted
      ]

private def scheduledPreviewSpans
    (snapshot : Snapshot) (base : BaseState) (index : Nat) : List Span :=
  match scheduledAt?
      (Loam.Prototype.VerifiedTui11.Main.homeScheduledPreviewRecords snapshot base) index with
  | none => [span ""]
  | some record =>
      let text := Loam.ActualReview.shortText 31 (Loam.ScheduledReview.summary record)
      let scheduledId := Loam.ActualReview.shortText 11 record.id.token
      [ span "- " .muted
      , span text
      , span (" [" ++ scheduledId ++ "]") .muted
      ]

private def scheduledHeaderText (snapshot : Snapshot) (base : BaseState) : String :=
  match Loam.Prototype.VerifiedTui11.Main.homeScheduledEvidence snapshot base with
  | .due _ rest =>
      "Scheduled / Due / " ++ toString (rest.length + 1) ++ " explicit"
  | .unknown => "Scheduled / Unknown"
  | .unknownCompletionScheduled => "Scheduled / refused completion evidence"
  | .unknownRetirementScheduled => "Scheduled / refused retirement evidence"
  | .unknownReplacementScheduled => "Scheduled / refused replacement evidence"
  | .invalidReplacementGraph => "Scheduled / refused replacement graph"
  | .conflictingTerminalEvidence => "Scheduled / refused terminal evidence"

private def evidenceSpans
    (snapshot : Snapshot) (state : State) (base : BaseState) : Nat → List Span
  | 0 =>
      targetHeaderSpans (state.target == .actual)
        ("Actual / " ++
          toString (Loam.Prototype.VerifiedTui11.Main.homeActualRecords snapshot base).length ++
          " current")
  | 1 => actualPreviewSpans snapshot base 0
  | 2 => actualPreviewSpans snapshot base 1
  | 3 => actualPreviewSpans snapshot base 2
  | 4 =>
      targetHeaderSpans (state.target == .scheduled) (scheduledHeaderText snapshot base)
  | 5 => scheduledPreviewSpans snapshot base 0
  | 6 => scheduledPreviewSpans snapshot base 1
  | _ => [span ""]

private def calendarOrBlankSpans (base : BaseState) (row : Nat) : List Span :=
  if row < 5 then
    Loam.Prototype.VerifiedTui10.Main.calendarSpans base row
  else
    [span "                            "]

private def homeEvidenceRow
    (snapshot : Snapshot) (state : State) (base : BaseState) (row : Nat) : Widget :=
  .row <|
    calendarOrBlankSpans base row ++ [span "    "] ++ evidenceSpans snapshot state base row

private def actualSummary (snapshot : Snapshot) (base : BaseState) : String :=
  let total := (Loam.Prototype.VerifiedTui11.Main.homeActualRecords snapshot base).length
  if total = 0 then
    "Actual: none on selected day."
  else
    "Actual: " ++ toString total ++ " current record(s)."

private def scheduledSummary (snapshot : Snapshot) (base : BaseState) : String :=
  match Loam.Prototype.VerifiedTui11.Main.homeScheduledEvidence snapshot base with
  | .due _ rest =>
      "Scheduled: Due; " ++ toString (rest.length + 1) ++ " explicit occurrence(s)."
  | .unknown => "Scheduled: Unknown (no explicit evidence)."
  | .unknownCompletionScheduled => "Scheduled: refused completion evidence."
  | .unknownRetirementScheduled => "Scheduled: refused retirement evidence."
  | .unknownReplacementScheduled => "Scheduled: refused replacement evidence."
  | .invalidReplacementGraph => "Scheduled: refused replacement graph."
  | .conflictingTerminalEvidence => "Scheduled: refused terminal evidence."

private def targetName : HomeTarget → String
  | .actual => "Actual"
  | .scheduled => "Scheduled"


def homeView (snapshot : Snapshot) (state : State) (base : BaseState) : Widget :=
  .column <|
    [ .row
        [ span "LOAM Home  [CANONICAL READ-ONLY]"
        , span "        "
        , span (" " ++ Loam.Prototype.VerifiedTui11.Main.selectedDate base ++ " ") .selected
        ]
    , Loam.Prototype.VerifiedTui09.Main.mutedLine
        "One SelectedDay; Tab only chooses which semantic workspace Enter opens."
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , .row
        [ span "    September 2026"
        , span "              "
        , span "Selected-day evidence"
        ]
    , .row
        [ span "Mon Tue Wed Thu Fri Sat Sun" .muted
        , span "     "
        , span (Loam.Prototype.VerifiedTui11.Main.selectedDate base) .muted
        ]
    ] ++
    (List.range 7).map (homeEvidenceRow snapshot state base) ++
    [ .row [span "                                ", span (actualSummary snapshot base) .muted]
    , .row [span "                                ", span (scheduledSummary snapshot base) .muted]
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , .row
        [ span ("Undated current Actual: " ++ toString snapshot.actual.undatedCount) .muted
        , span "          "
        , span ("Open target: " ++ targetName state.target) .muted
        ]
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , Loam.Prototype.VerifiedTui09.Main.mutedLine
        "←/→ Day    ↑/↓ Week    Tab Target    Enter Open    q Quit"
    , Loam.Prototype.VerifiedTui09.Main.mutedLine base.notice
    ]

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


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .scheduled home => scheduledWorkspaceView snapshot home
  | .base base =>
      match base.surface with
      | .home _ => homeView snapshot state base
      | .actual _ _ => Loam.Prototype.VerifiedTui11.Main.view snapshot base


def screenBounds : Bounds :=
  Loam.Prototype.VerifiedTui11.Main.screenBounds


def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui12.Main
