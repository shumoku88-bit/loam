import Loam.Prototype.VerifiedTui10.Main
import Loam.ScheduledReview

namespace Loam.Prototype.VerifiedTui11.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

abbrev ActualSnapshot := Loam.Prototype.VerifiedTui10.Main.Snapshot
abbrev ReviewRecord := Loam.Prototype.VerifiedTui10.Main.ReviewRecord
abbrev ScheduledRecord := Loam.ScheduledReview.Record
abbrev ReviewCursor := Loam.Prototype.VerifiedTui10.Main.ReviewCursor
abbrev ActualMode := Loam.Prototype.VerifiedTui10.Main.ActualMode
abbrev Surface := Loam.Prototype.VerifiedTui10.Main.Surface
abbrev State := Loam.Prototype.VerifiedTui10.Main.State
abbrev Event := Loam.Prototype.VerifiedTui10.Main.Event
abbrev Step := Loam.Prototype.VerifiedTui10.Main.Step

/--
One admitted read-only household snapshot. `openScheduled` is derived at startup
from canonical Scheduled + lifecycle evidence and selected Movement Event evidence.
It is not presentation state and is never persisted by the TUI.
-/
structure Snapshot where
  actual : ActualSnapshot
  openScheduled : List ScheduledRecord


def initialState : State :=
  Loam.Prototype.VerifiedTui10.Main.initialState


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  Loam.Prototype.VerifiedTui10.Main.update snapshot.actual state event


def selectedDate (state : State) : String :=
  Loam.Prototype.VerifiedTui09.Main.dayDate state.day

/-- Actual and Scheduled projections share this one selected-day coordinate. -/
def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  Loam.Prototype.VerifiedTui10.Main.homeActualRecords snapshot.actual state


def homeScheduledRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  Loam.ScheduledReview.selectDay snapshot.openScheduled (selectedDate state)


def homeActualPreviewRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  (homeActualRecords snapshot state).take 3


def homeScheduledPreviewRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  (homeScheduledRecords snapshot state).take 2


theorem home_actual_preview_is_selected_day
    (snapshot : Snapshot) (state : State) :
    homeActualPreviewRecords snapshot state =
      (Loam.ActualReview.select snapshot.actual.allRecords (.day (selectedDate state))).take 3 := by
  rfl


theorem home_scheduled_preview_is_selected_day
    (snapshot : Snapshot) (state : State) :
    homeScheduledPreviewRecords snapshot state =
      (Loam.ScheduledReview.selectDay snapshot.openScheduled (selectedDate state)).take 2 := by
  rfl


theorem actual_workspace_and_home_share_day_count
    (snapshot : Snapshot) (state : State) :
    (Loam.Prototype.VerifiedTui09.Main.cursorForDay snapshot.actual state.day).totalCount =
      (homeActualRecords snapshot state).length := by
  rfl


theorem enter_preserves_shared_day
    (snapshot : Snapshot) (state : State) :
    (update snapshot state .enter).state.day = state.day := by
  simpa [update] using
    Loam.Prototype.VerifiedTui09.Main.enter_preserves_day snapshot.actual state

private def scheduledAt? : List ScheduledRecord → Nat → Option ScheduledRecord
  | [], _ => none
  | record :: _, 0 => some record
  | _ :: records, index + 1 => scheduledAt? records index

private def actualPreviewSpans
    (snapshot : Snapshot) (state : State) (index : Nat) : List Span :=
  match Loam.Prototype.VerifiedTui10.Main.recordAt?
      (homeActualPreviewRecords snapshot state) index with
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
    (snapshot : Snapshot) (state : State) (index : Nat) : List Span :=
  match scheduledAt? (homeScheduledPreviewRecords snapshot state) index with
  | none => [span ""]
  | some record =>
      let text := Loam.ActualReview.shortText 31 (Loam.ScheduledReview.summary record)
      let scheduledId := Loam.ActualReview.shortText 11 record.id.token
      [ span "- " .muted
      , span text
      , span (" [" ++ scheduledId ++ "]") .muted
      ]

private def evidenceSpans
    (snapshot : Snapshot) (state : State) : Nat → List Span
  | 0 =>
      [ span ("Actual / " ++ toString (homeActualRecords snapshot state).length ++ " current") ]
  | 1 => actualPreviewSpans snapshot state 0
  | 2 => actualPreviewSpans snapshot state 1
  | 3 => actualPreviewSpans snapshot state 2
  | 4 =>
      [ span ("Scheduled / " ++ toString (homeScheduledRecords snapshot state).length ++ " open") ]
  | 5 => scheduledPreviewSpans snapshot state 0
  | 6 => scheduledPreviewSpans snapshot state 1
  | _ => [span ""]

private def calendarOrBlankSpans (state : State) (row : Nat) : List Span :=
  if row < 5 then
    Loam.Prototype.VerifiedTui10.Main.calendarSpans state row
  else
    [span "                            "]

private def homeEvidenceRow (snapshot : Snapshot) (state : State) (row : Nat) : Widget :=
  .row <|
    calendarOrBlankSpans state row ++ [span "    "] ++ evidenceSpans snapshot state row

private def actualPreviewSummary (snapshot : Snapshot) (state : State) : String :=
  let total := (homeActualRecords snapshot state).length
  let shown := (homeActualPreviewRecords snapshot state).length
  if total = 0 then
    "Actual: none on selected day."
  else if shown < total then
    "Actual: showing " ++ toString shown ++ " here; Enter opens all " ++ toString total ++ "."
  else
    "Actual: all " ++ toString total ++ " selected-day record(s) visible here."

private def scheduledPreviewSummary (snapshot : Snapshot) (state : State) : String :=
  let total := (homeScheduledRecords snapshot state).length
  let shown := (homeScheduledPreviewRecords snapshot state).length
  if total = 0 then
    "Scheduled: none open on selected day."
  else if shown < total then
    "Scheduled: showing " ++ toString shown ++ " of " ++ toString total ++ " open occurrence(s)."
  else
    "Scheduled: all " ++ toString total ++ " selected-day open occurrence(s) visible here."


def homeView (snapshot : Snapshot) (state : State) : Widget :=
  .column <|
    [ .row
        [ span "LOAM Home  [CANONICAL READ-ONLY]"
        , span "        "
        , span (" " ++ selectedDate state ++ " ") .selected
        ]
    , Loam.Prototype.VerifiedTui09.Main.mutedLine
        "One SelectedDay drives both Actual and Scheduled evidence."
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , .row
        [ span "    September 2026"
        , span "              "
        , span "Selected-day evidence"
        ]
    , .row
        [ span "Mon Tue Wed Thu Fri Sat Sun" .muted
        , span "     "
        , span (selectedDate state) .muted
        ]
    ] ++
    (List.range 7).map (homeEvidenceRow snapshot state) ++
    [ .row [span "                                ", span (actualPreviewSummary snapshot state) .muted]
    , .row [span "                                ", span (scheduledPreviewSummary snapshot state) .muted]
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , .row
        [ span ("Undated current Actual: " ++ toString snapshot.actual.undatedCount) .muted
        , span "          "
        , span "Scheduled is preview-only in Prototype 11." .muted
        ]
    , Loam.Prototype.VerifiedTui09.Main.blankLine
    , Loam.Prototype.VerifiedTui09.Main.mutedLine
        "←/→ Day    ↑/↓ Week    Enter Actual    q Quit"
    , Loam.Prototype.VerifiedTui09.Main.mutedLine state.notice
    ]


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .home _ => homeView snapshot state
  | .actual cursor .browse =>
      Loam.Prototype.VerifiedTui09.Main.actualBrowseView cursor state
  | .actual cursor .detail =>
      Loam.Prototype.VerifiedTui09.Main.actualDetailView snapshot.actual cursor


def screenBounds : Bounds :=
  Loam.Prototype.VerifiedTui10.Main.screenBounds


def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui11.Main
