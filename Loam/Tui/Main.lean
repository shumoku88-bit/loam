import Loam.ActualReview
import Loam.ScheduledReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel

namespace Loam.Tui.Main

open Loam.Tui.Kernel

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record
abbrev ScheduledRecord := Loam.ScheduledReview.Record
abbrev ScheduledEvidence := Loam.ScheduledReview.DayEvidence
abbrev ScheduledAvailability := Except String Loam.ScheduledReview.EvidenceSnapshot

structure ActualSnapshot where
  today : String
  allRecords : List ReviewRecord

/-- One admitted household read snapshot. It is process-local evidence, never TUI authority. -/
structure Snapshot where
  actual : ActualSnapshot
  /-- Scheduled refusal remains explicit and must never be reinterpreted as an empty household. -/
  scheduled : ScheduledAvailability

/-- Production root state now owns only Home date focus and a human-facing notice. -/
structure State where
  selectedDate : String
  notice : String := ""
  /-- Presentation-only viewport offset for the wide Home detail pane. -/
  detailScroll : Nat := 0

inductive Event where
  | left
  | right
  | up
  | down
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false


def initialState (selectedDate : String) : State :=
  { selectedDate := selectedDate }


def plainLine (text : String) : Widget := .row [span text]
def mutedLine (text : String) : Widget := .row [span text .muted]
def blankLine : Widget := .row []


def recordsForDay (snapshot : Snapshot) (date : String) : List ReviewRecord :=
  Loam.ActualReview.select snapshot.actual.allRecords (.day date)


def moveDate (state : State) (offset : Int) : State :=
  match Loam.ActualDate.shiftDays? state.selectedDate offset with
  | none => { state with notice := "Calendar boundary reached." }
  | some date => { state with selectedDate := date, notice := "", detailScroll := 0 }

/-- Home-only root navigation. Household evidence is consumed by presentation, not this transition. -/
def update (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left => { state := moveDate state (-1) }
  | .right => { state := moveDate state 1 }
  | .up => { state := moveDate state (-7) }
  | .down => { state := moveDate state 7 }
  | .other => { state }


def selectedMonth (state : State) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? state.selectedDate).getD { year := 1970, month := 1 }


def calendarSlot (state : State) (row col : Nat) : Option String :=
  match (Loam.Tui.Calendar.slots (selectedMonth state))[row * 7 + col]? with
  | none => none
  | some date => date


def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.selectedDate


def homeScheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => .ok (Loam.ScheduledReview.dayEvidence scheduled state.selectedDate)

end Loam.Tui.Main
