import Loam.Review.ActualReview
import Loam.Review.CalendarMoneyReview
import Loam.Review.CycleSpendingPaceReview
import Loam.Presentation.MeasurePresentation
import Loam.Presentation.ReadState
import Loam.Review.ScheduledReview
import Loam.Tui.Calendar
import Loam.Tui.DateJump
import Loam.Tui.Terminal

namespace Loam.Tui.Main


set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record
abbrev ScheduledRecord := Loam.ScheduledReview.Record
abbrev ScheduledEvidence := Loam.ScheduledReview.DayEvidence
abbrev ScheduledAvailability := Except String Loam.ScheduledReview.EvidenceSnapshot

structure ActualSnapshot where
  today : String
  allRecords : List ReviewRecord

/-- Optional Home money-calendar answer plus exact per-Measure rendering convention. -/
structure MoneyCalendarSnapshot where
  flow : Loam.CalendarMoneyReview.Snapshot
  presentation : List Loam.MeasurePresentation.Metadata

/-- One admitted household read snapshot. It is process-local evidence, never TUI authority. -/
structure Snapshot where
  actual : ActualSnapshot
  /-- Scheduled refusal remains explicit and must never be reinterpreted as an empty household. -/
  scheduled : ScheduledAvailability
  /--
  Optional retrospective current-truth series for presentation. This is derived
  from canonical evidence at load time and is never retained as household state.
  -/
  paceHistory : Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot) :=
    .notRequested
  /--
  Optional role-aware daily money projection used by Home's money calendar and
  period summaries. Failure must not prevent ordinary navigation or accounting workspaces.
  -/
  moneyCalendar : Loam.Presentation.ReadState MoneyCalendarSnapshot := .notRequested

inductive HomePane where
  | calendar
  | detail
  deriving Repr, DecidableEq, BEq

/-- Production root state owns only Home presentation/navigation state. -/
structure State where
  selectedDate : String
  notice : String := ""
  /-- Presentation-only viewport offset for the responsive Home detail pane. -/
  detailScroll : Nat := 0
  /-- Scroll of the calendar surface, independent of record selection. -/
  overviewScroll : Nat := 0
  /-- Manual calendar browsing temporarily releases focus-following until date/zoom changes. -/
  overviewManualScroll : Bool := false
  /-- Zero-based index of the currently selected Actual transaction in detail view. -/
  detailCursor : Nat := 0
  /-- Calendar zoom level: Day, Month, or Year. -/
  zoomLevel : Loam.Tui.DateJump.ZoomLevel := .day
  /-- Active jump input buffer. When `some s`, Home is in jump-prompt mode. -/
  jumpPrompt : Option String := none
  /-- Currently active/focused pane on the Home surface. -/
  activePane : HomePane := .calendar

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

/-- Toggle focus between calendar and detail pane. -/
def toggleActivePane (state : State) : State :=
  let next :=
    match state.activePane with
    | .calendar => .detail
    | .detail => .calendar
  { state with activePane := next, notice := "" }

def focusCalendar (state : State) : State :=
  { state with activePane := .calendar, notice := "" }

def focusDetail (state : State) : State :=
  { state with activePane := .detail, notice := "" }

/-- Every change of period starts a fresh selection and viewport. -/
def setZoomLevel (state : State) (zoom : Loam.Tui.DateJump.ZoomLevel) : State :=
  { state with
    zoomLevel := zoom
    overviewScroll := 0
    overviewManualScroll := false
    notice := s!"View: {Loam.Tui.DateJump.zoomLabel zoom}"
    detailScroll := 0
    detailCursor := 0
    activePane := .calendar
  }

/-- Cycle calendar zoom level between Day, Month, and Year. -/
def cycleZoomLevel (state : State) : State :=
  setZoomLevel state (Loam.Tui.DateJump.cycleZoom state.zoomLevel)

def openJumpPrompt (state : State) : State :=
  { state with jumpPrompt := some "", notice := "" }

def closeJumpPrompt (state : State) : State :=
  { state with jumpPrompt := none, notice := "" }

def appendJumpChar (state : State) (char : Char) : State :=
  match state.jumpPrompt with
  | some buffer =>
      if buffer.length < 16 then
        { state with jumpPrompt := some (buffer.push char) }
      else
        state
  | none => state

def backspaceJump (state : State) : State :=
  match state.jumpPrompt with
  | some buffer =>
      { state with jumpPrompt := some (Loam.Tui.Terminal.backspaceText buffer) }
  | none => state

def executeJump (state : State) : State :=
  match state.jumpPrompt with
  | some buffer =>
      match Loam.Tui.DateJump.parseJumpTarget state.selectedDate buffer with
      | some target =>
          { state with
            selectedDate := target.date
            overviewScroll := 0
            overviewManualScroll := false
            zoomLevel := target.zoom
            jumpPrompt := none
            notice := s!"Jumped to {target.date} ({Loam.Tui.DateJump.zoomLabel target.zoom})."
            detailScroll := 0
            detailCursor := 0
            activePane := .calendar
          }
      | none =>
          { state with
            jumpPrompt := none
            notice := if buffer.isEmpty then "" else s!"Invalid date format: {buffer}"
          }
  | none => state


def recordsForDay (snapshot : Snapshot) (date : String) : List ReviewRecord :=
  Loam.ActualReview.select snapshot.actual.allRecords (.day date)

def recordsForMonth (snapshot : Snapshot) (year month : Nat) : List ReviewRecord :=
  let prefixText := s!"{Loam.Tui.Calendar.padded 4 year}-{Loam.Tui.Calendar.padded 2 month}-"
  snapshot.actual.allRecords.filter fun r =>
    match r.date with
    | some d => d.startsWith prefixText
    | none => false

def recordsForYear (snapshot : Snapshot) (year : Nat) : List ReviewRecord :=
  let prefixText := s!"{Loam.Tui.Calendar.padded 4 year}-"
  snapshot.actual.allRecords.filter fun r =>
    match r.date with
    | some d => d.startsWith prefixText
    | none => false


def selectedMonth (state : State) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? state.selectedDate).getD { year := 1970, month := 1 }

def moveDate (state : State) (offset : Int) : State :=
  match Loam.ActualDate.shiftDays? state.selectedDate offset with
  | none => { state with notice := "Calendar boundary reached." }
  | some date => { state with
      selectedDate := date, notice := "", detailScroll := 0, detailCursor := 0
      overviewScroll := 0, overviewManualScroll := false }

def moveMonth (state : State) (offset : Int) : State :=
  let cur := selectedMonth state
  let totalMonths := (cur.year * 12 + (cur.month - 1) : Int) + offset
  if totalMonths < 0 then
    { state with notice := "Calendar boundary reached." }
  else
    let targetYear := (totalMonths / 12).toNat
    let targetMonth := (totalMonths % 12).toNat + 1
    if targetYear < 1000 || targetYear > 9999 then
      { state with notice := "Calendar boundary reached." }
    else
      let day := match Loam.Tui.Calendar.parseDate? state.selectedDate with
        | some (_, _, d) => d
        | none => 1
      let maxDay := (Loam.Tui.Calendar.daysInMonth? { year := targetYear, month := targetMonth }).getD 31
      let clampedDay := if day > maxDay then maxDay else if day == 0 then 1 else day
      let newDate := Loam.Tui.Calendar.dateForDay { year := targetYear, month := targetMonth } clampedDay
      { state with
        selectedDate := newDate, notice := "", detailScroll := 0, detailCursor := 0
        overviewScroll := 0, overviewManualScroll := false }

def moveYear (state : State) (offset : Int) : State :=
  match Loam.Tui.Calendar.parseDate? state.selectedDate with
  | none => state
  | some (y, m, d) =>
      let targetYearInt := (y : Int) + offset
      if targetYearInt < 1000 || targetYearInt > 9999 then
        { state with notice := "Calendar boundary reached." }
      else
        let targetYear := targetYearInt.toNat
        let maxDay := (Loam.Tui.Calendar.daysInMonth? { year := targetYear, month := m }).getD 31
        let clampedDay := if d > maxDay then maxDay else d
        let newDate := Loam.Tui.Calendar.dateForDay { year := targetYear, month := m } clampedDay
        { state with
          selectedDate := newDate, notice := "", detailScroll := 0, detailCursor := 0
          overviewScroll := 0, overviewManualScroll := false }

/-- Home-only root navigation. Household evidence is consumed by presentation, not this transition. -/
def update (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left =>
      match state.zoomLevel with
      | .day => { state := moveDate state (-1) }
      | .month => { state := moveMonth state (-1) }
      | .year => { state := moveYear state (-1) }
  | .right =>
      match state.zoomLevel with
      | .day => { state := moveDate state 1 }
      | .month => { state := moveMonth state 1 }
      | .year => { state := moveYear state 1 }
  | .up =>
      match state.zoomLevel with
      | .day => { state := moveDate state (-7) }
      | .month => { state := moveMonth state (-3) }
      | .year => { state := moveYear state (-1) }
  | .down =>
      match state.zoomLevel with
      | .day => { state := moveDate state 7 }
      | .month => { state := moveMonth state 3 }
      | .year => { state := moveYear state 1 }
  | .other => { state }


def calendarSlot (state : State) (row col : Nat) : Option String :=
  match (Loam.Tui.Calendar.slots (selectedMonth state))[row * 7 + col]? with
  | none => none
  | some date => date


def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  match state.zoomLevel with
  | .day => recordsForDay snapshot state.selectedDate
  | .month =>
      let m := selectedMonth state
      recordsForMonth snapshot m.year m.month
  | .year =>
      let m := selectedMonth state
      recordsForYear snapshot m.year

/-- Reconcile ephemeral selection after a workspace reload changes the record set. -/
def normalizeDetailCursor (snapshot : Snapshot) (state : State) : State :=
  let count := (homeActualRecords snapshot state).length
  { state with detailCursor := min state.detailCursor (count - 1) }

def selectedDetailRecord? (snapshot : Snapshot) (state : State) : Option ReviewRecord :=
  let records := (homeActualRecords snapshot state).reverse
  records[(normalizeDetailCursor snapshot state).detailCursor]?

def moveDetailCursor (snapshot : Snapshot) (state : State) (offset : Int) : State :=
  let records := homeActualRecords snapshot state
  if records.isEmpty then state
  else
    let count := records.length
    let current := (state.detailCursor : Int)
    let nextInt := current + offset
    let clamped := if nextInt < 0 then 0 else if nextInt >= count then count - 1 else nextInt.toNat
    { state with detailCursor := clamped }


def homeScheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => Loam.ScheduledReview.dayEvidence scheduled state.selectedDate

end Loam.Tui.Main
