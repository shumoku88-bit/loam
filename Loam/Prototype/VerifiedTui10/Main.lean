import Loam.Prototype.VerifiedTui09.Main

namespace Loam.Prototype.VerifiedTui10.Main

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui09.Main

set_option autoImplicit false

abbrev ReviewRecord := Loam.Prototype.VerifiedTui09.Main.ReviewRecord
abbrev Snapshot := Loam.Prototype.VerifiedTui09.Main.Snapshot
abbrev ReviewCursor := Loam.Prototype.VerifiedTui09.Main.ReviewCursor
abbrev ActualMode := Loam.Prototype.VerifiedTui09.Main.ActualMode
abbrev Surface := Loam.Prototype.VerifiedTui09.Main.Surface
abbrev State := Loam.Prototype.VerifiedTui09.Main.State
abbrev Event := Loam.Prototype.VerifiedTui09.Main.Event
abbrev Step := Loam.Prototype.VerifiedTui09.Main.Step


def initialState : State :=
  Loam.Prototype.VerifiedTui09.Main.initialState


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  Loam.Prototype.VerifiedTui09.Main.update snapshot state event

/--
Home does not retain a second Actual collection. Its visible evidence is always
reconstructed from the same selected-day projection that feeds the Actual
workspace.
-/
def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.day


def homeActualPreviewRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  (homeActualRecords snapshot state).take 5


theorem home_actual_preview_is_selected_day
    (snapshot : Snapshot) (state : State) :
    homeActualPreviewRecords snapshot state =
      (Loam.ActualReview.select snapshot.allRecords (.day (dayDate state.day))).take 5 := by
  rfl


theorem home_and_actual_workspace_share_day_count
    (snapshot : Snapshot) (state : State) :
    (cursorForDay snapshot state.day).totalCount =
      (homeActualRecords snapshot state).length := by
  rfl


def recordAt? : List ReviewRecord → Nat → Option ReviewRecord
  | [], _ => none
  | record :: _, 0 => some record
  | _ :: records, index + 1 => recordAt? records index


def calendarSpans (state : State) (row : Nat) : List Span :=
  (List.range 7).map fun col => calendarCell state (row * 7 + col)


def previewSpans (snapshot : Snapshot) (state : State) (row : Nat) : List Span :=
  match recordAt? (homeActualPreviewRecords snapshot state) row with
  | none => [span ""]
  | some record =>
      let description :=
        if record.description.isEmpty then "(no description)"
        else Loam.ActualReview.shortText 14 record.description
      let eventId := Loam.ActualReview.shortText 10 record.event.id.token
      [ span "- " .muted
      , span description
      , span (" [" ++ eventId ++ "]") .muted
      ]


def homeEvidenceRow (snapshot : Snapshot) (state : State) (row : Nat) : Widget :=
  .row <| calendarSpans state row ++ [span "    "] ++ previewSpans snapshot state row


def homeHeader (state : State) : Widget :=
  .row
    [ span "LOAM Home  [CANONICAL READ-ONLY]"
    , span "        "
    , span (" " ++ dayDate state.day ++ " ") .selected
    ]


def calendarAndActualHeader (snapshot : Snapshot) (state : State) : List Widget :=
  let total := (homeActualRecords snapshot state).length
  [ .row
      [ span "    September 2026"
      , span "              "
      , span "Actual / selected day"
      ]
  , .row
      [ span "Mon Tue Wed Thu Fri Sat Sun" .muted
      , span "     "
      , span (toString total ++ " current record(s)") .muted
      ]
  ]


def previewSummary (snapshot : Snapshot) (state : State) : Widget :=
  let total := (homeActualRecords snapshot state).length
  let shown := (homeActualPreviewRecords snapshot state).length
  let text :=
    if total = 0 then
      "No current Actual records on this day."
    else if shown < total then
      "Showing " ++ toString shown ++ " here; Enter opens all " ++ toString total ++ "."
    else
      "All " ++ toString total ++ " selected-day record(s) are visible here."
  .row [span "                                ", span text .muted]


def homeView (snapshot : Snapshot) (state : State) : Widget :=
  .column <|
    [ homeHeader state
    , mutedLine "One temporal coordinate drives both calendar orientation and Actual evidence."
    , blankLine
    ] ++
    calendarAndActualHeader snapshot state ++
    (List.range 5).map (homeEvidenceRow snapshot state) ++
    [ previewSummary snapshot state
    , blankLine
    , .row
        [ span ("Undated current Actual: " ++ toString snapshot.undatedCount) .muted
        , span "          "
        , span "Enter opens the Actual workspace." .muted
        ]
    , blankLine
    , mutedLine "←/→ Day    ↑/↓ Week    Enter Actual    q Quit"
    , mutedLine state.notice
    ]


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .home _ => homeView snapshot state
  | .actual cursor .browse => actualBrowseView cursor state
  | .actual cursor .detail => actualDetailView snapshot cursor


def screenBounds : Bounds :=
  Loam.Prototype.VerifiedTui09.Main.screenBounds


def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui10.Main
