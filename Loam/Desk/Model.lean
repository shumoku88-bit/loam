import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.Tui.Calendar

namespace Loam.Desk.Model

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record

structure Snapshot where
  today : String
  records : List ReviewRecord

structure State where
  focusDate : String
  selectedRow : Option Nat := none
  jumpEditing : Bool := false
  jumpText : String := ""
  showEvidence : Bool := false
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previousRow
  | nextRow
  | previousDay
  | nextDay
  | previousMonth
  | nextMonth
  | beginJump
  | jumpInput (char : Char)
  | jumpBackspace
  | acceptJump
  | cancelJump
  | toggleEvidence
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false

private def recordMonth?
    (record : ReviewRecord) : Option Loam.Tui.Calendar.Month := do
  let date ← record.date
  Loam.Tui.Calendar.monthOf? date

/-- Current Actual rows in one Gregorian month, oldest first. This is a projection only. -/
def recordsForMonth (snapshot : Snapshot) (month : Loam.Tui.Calendar.Month) :
    List ReviewRecord :=
  (snapshot.records.filter fun record =>
    record.isCurrent && recordMonth? record == some month).mergeSort fun a b =>
      if a.date == b.date then a.event.id.token <= b.event.id.token
      else a.date.getD "" <= b.date.getD ""

def focusedMonth? (state : State) : Option Loam.Tui.Calendar.Month :=
  Loam.Tui.Calendar.monthOf? state.focusDate

def visibleRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  match focusedMonth? state with
  | none => []
  | some month => recordsForMonth snapshot month

def recordsForDate (snapshot : Snapshot) (date : String) : List ReviewRecord :=
  snapshot.records.filter fun record =>
    record.isCurrent && record.date == some date

private def firstRowForDate?
    (records : List ReviewRecord) (date : String) : Option Nat :=
  let rec loop : Nat → List ReviewRecord → Option Nat
    | _, [] => none
    | index, record :: rest =>
        if record.date == some date then some index else loop (index + 1) rest
  loop 0 records

def selectedRecord? (snapshot : Snapshot) (state : State) : Option ReviewRecord := do
  let index ← state.selectedRow
  (visibleRecords snapshot state)[index]?

private def alignSelectionToDate
    (snapshot : Snapshot) (state : State) (date : String) : State :=
  let base := {
    state with
      focusDate := date
      selectedRow := none
      showEvidence := false
      notice := ""
  }
  let row := firstRowForDate? (visibleRecords snapshot base) date
  { base with selectedRow := row }

def initial (snapshot : Snapshot) (focusDate : String) : State :=
  alignSelectionToDate snapshot { focusDate := focusDate } focusDate

private def selectRow
    (snapshot : Snapshot) (state : State) (index : Nat) : State :=
  match (visibleRecords snapshot state)[index]? with
  | none => state
  | some record =>
      {
        state with
          selectedRow := some index
          focusDate := record.date.getD state.focusDate
          showEvidence := false
          notice := ""
      }

private def movePreviousRow (snapshot : Snapshot) (state : State) : State :=
  let records := visibleRecords snapshot state
  match state.selectedRow with
  | none =>
      if records.isEmpty then { state with notice := "No Actual rows in this month." }
      else selectRow snapshot state (records.length - 1)
  | some 0 => { state with notice := "No previous Actual row in this month." }
  | some (index + 1) => selectRow snapshot state index

private def moveNextRow (snapshot : Snapshot) (state : State) : State :=
  let records := visibleRecords snapshot state
  match state.selectedRow with
  | none =>
      if records.isEmpty then { state with notice := "No Actual rows in this month." }
      else selectRow snapshot state 0
  | some index =>
      if index + 1 < records.length then selectRow snapshot state (index + 1)
      else { state with notice := "No next Actual row in this month." }

private def shiftDay (snapshot : Snapshot) (state : State) (offset : Int) : State :=
  match Loam.ActualDate.shiftDays? state.focusDate offset with
  | none => { state with notice := "Calendar boundary reached." }
  | some date => alignSelectionToDate snapshot state date

private def shiftMonth
    (snapshot : Snapshot) (state : State) (forward : Bool) : State :=
  match Loam.Tui.Calendar.parseDate? state.focusDate with
  | none => { state with notice := "Current focus date is invalid." }
  | some (_, _, day) =>
      match Loam.Tui.Calendar.monthOf? state.focusDate with
      | none => { state with notice := "Current focus month is invalid." }
      | some month =>
          let target? :=
            if forward then some (Loam.Tui.Calendar.nextMonth month)
            else Loam.Tui.Calendar.previousMonth? month
          match target? with
          | none => { state with notice := "Calendar boundary reached." }
          | some target =>
              match Loam.Tui.Calendar.daysInMonth? target with
              | none => { state with notice := "Target calendar month is invalid." }
              | some count =>
                  let date := Loam.Tui.Calendar.dateForDay target (min day count)
                  alignSelectionToDate snapshot state date

private def backspace (text : String) : String :=
  String.ofList text.toList.dropLast

private def jumpCharacter (char : Char) : Bool :=
  (char.toNat >= '0'.toNat && char.toNat <= '9'.toNat) || char == '-'

private def acceptJump (snapshot : Snapshot) (state : State) : State :=
  if Loam.ActualDate.validIsoDate state.jumpText then
    let moved := alignSelectionToDate snapshot state state.jumpText
    { moved with jumpEditing := false, jumpText := "" }
  else
    { state with notice := "Enter a valid date as YYYY-MM-DD." }

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previousRow => { state := movePreviousRow snapshot state }
  | .nextRow => { state := moveNextRow snapshot state }
  | .previousDay => { state := shiftDay snapshot state (-1) }
  | .nextDay => { state := shiftDay snapshot state 1 }
  | .previousMonth => { state := shiftMonth snapshot state false }
  | .nextMonth => { state := shiftMonth snapshot state true }
  | .beginJump =>
      { state := { state with jumpEditing := true, jumpText := state.focusDate, notice := "" } }
  | .jumpInput char =>
      if state.jumpEditing && jumpCharacter char then
        { state := { state with jumpText := state.jumpText.push char, notice := "" } }
      else
        { state }
  | .jumpBackspace =>
      if state.jumpEditing then
        { state := { state with jumpText := backspace state.jumpText, notice := "" } }
      else
        { state }
  | .acceptJump =>
      if state.jumpEditing then { state := acceptJump snapshot state } else { state }
  | .cancelJump =>
      { state := { state with jumpEditing := false, jumpText := "", notice := "" } }
  | .toggleEvidence =>
      match selectedRecord? snapshot state with
      | none => { state := { state with notice := "Select an Actual row first." } }
      | some _ =>
          { state := { state with showEvidence := !state.showEvidence, notice := "" } }
  | .quit => { state, quit := true }
  | .other => { state }

end Loam.Desk.Model
