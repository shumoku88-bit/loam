import LeanTea.Tui

namespace Loam.Prototype.InteractionShellTeaMain

open LeanTea.Tui

set_option autoImplicit false

inductive Surface where
  | home
  | actual
  | scheduled
  | record
  deriving Repr, DecidableEq, BEq

inductive Msg where
  | previousDay
  | nextDay
  | previousRow
  | nextRow
  | openSelected
  | record
  | back
  | mockPublish
  | quit
  deriving Repr, DecidableEq, BEq

structure State where
  surface : Surface := .home
  dayIndex : Nat := 3
  selectedRow : Nat := 0
  done : Bool := false
  notice : String := ""
  deriving Repr

def selectedDay : Nat → String
  | 0 => "Sep 3"
  | 1 => "Sep 4"
  | 2 => "Sep 5"
  | 3 => "Sep 6"
  | _ => "Sep 7"

def dayStrip (dayIndex : Nat) : String :=
  let days := ["Sep 3", "Sep 4", "Sep 5", "Sep 6", "Sep 7"]
  let rendered := days.zipIdx.map fun (day, i) =>
    if i == dayIndex then "[ " ++ day ++ " ]" else day
  "‹  " ++ String.intercalate "    " rendered ++ "  ›"

def selectedMark (selected : Bool) : String :=
  if selected then "▶" else " "

def titleStyle : Style := { bold := true }
def dimStyle : Style := { dim := true }
def selectedStyle : Style := { fg := .cyan, bold := true }

def textRow (s : String) (style : Style := {}) : Widget Msg :=
  text s style

def homeRows (state : State) : List (Widget Msg) :=
  let actualSelected := state.selectedRow == 0
  let scheduledSelected := state.selectedRow == 1
  [
    textRow "LOAM UI Prototype 02  [SYNTHETIC / NO WRITES]" titleStyle,
    textRow "LeanTEA raw-input mechanics spike" dimStyle,
    textRow "",
    textRow (dayStrip state.dayIndex),
    textRow ("Selected day: " ++ selectedDay state.dayIndex),
    textRow "",
    textRow (selectedMark actualSelected ++ " Actual")
      (if actualSelected then selectedStyle else {}),
    textRow "    PayPay                         -138 JPY",
    textRow "    coffee                         +138 JPY",
    textRow "",
    textRow (selectedMark scheduledSelected ++ " Scheduled   Sep 10")
      (if scheduledSelected then selectedStyle else {}),
    textRow "    bank                        -50,000 JPY",
    textRow "    rent                        +50,000 JPY",
    textRow "",
    textRow "←/→ Day    ↑/↓ Select    Enter Open    r Record    q Quit" dimStyle,
    textRow state.notice dimStyle
  ]

def actualRows (state : State) : List (Widget Msg) :=
  [
    textRow "Actual evidence" titleStyle,
    textRow "",
    textRow "Sep 5   coffee",
    textRow "  PayPay                         -138 JPY",
    textRow "  coffee                         +138 JPY",
    textRow "",
    textRow "The signs show this synthetic movement effect directly." dimStyle,
    textRow "Esc/b Back    q Quit" dimStyle
  ]

def scheduledRows (state : State) : List (Widget Msg) :=
  [
    textRow "Scheduled expectation" titleStyle,
    textRow "",
    textRow "Sep 10   scheduled-7",
    textRow "  bank                        -50,000 JPY",
    textRow "  rent                        +50,000 JPY",
    textRow "",
    textRow "This is still expectation, not Actual evidence." dimStyle,
    textRow "r Record Actual mock    Esc/b Back    q Quit" dimStyle
  ]

def recordRows (state : State) : List (Widget Msg) :=
  [
    textRow "Record what happened  [MOCK DRAFT]" titleStyle,
    textRow "",
    textRow ("Date      [ " ++ selectedDay state.dayIndex ++ " ]"),
    textRow "Movement",
    textRow "  PayPay                         -138 JPY",
    textRow "  coffee                         +138 JPY",
    textRow "",
    textRow "Nothing is canonical. This spike cannot write files." dimStyle,
    textRow "Enter Mock publish    Esc/b Cancel    q Quit" dimStyle
  ]

def body (state : State) : Widget Msg :=
  vbox <|
    match state.surface with
    | .home => homeRows state
    | .actual => actualRows state
    | .scheduled => scheduledRows state
    | .record => recordRows state

def keyMessage (state : State) : Key → Option Msg
  | .char 'q' => some .quit
  | .esc => if state.surface == .home then none else some .back
  | .char 'b' => if state.surface == .home then none else some .back
  | .left => if state.surface == .home then some .previousDay else none
  | .right => if state.surface == .home then some .nextDay else none
  | .up => if state.surface == .home then some .previousRow else none
  | .down => if state.surface == .home then some .nextRow else none
  | .char 'r' =>
      match state.surface with
      | .home | .scheduled => some .record
      | _ => none
  | .enter =>
      match state.surface with
      | .home => some .openSelected
      | .record => some .mockPublish
      | _ => none
  | _ => none

def view (state : State) : Widget Msg :=
  let content := body state
  {
    render := fun width height _focused => content.render width height false,
    onKey := keyMessage state,
    focusId := "root",
    children := [content]
  }

def update : Msg → State → State
  | .previousDay, state =>
      if state.dayIndex == 0 then
        { state with notice := "Already at the first synthetic day." }
      else
        { state with dayIndex := state.dayIndex - 1, notice := "" }
  | .nextDay, state =>
      if state.dayIndex >= 4 then
        { state with notice := "Already at the last synthetic day." }
      else
        { state with dayIndex := state.dayIndex + 1, notice := "" }
  | .previousRow, state =>
      { state with selectedRow := if state.selectedRow == 0 then 1 else 0, notice := "" }
  | .nextRow, state =>
      { state with selectedRow := if state.selectedRow == 0 then 1 else 0, notice := "" }
  | .openSelected, state =>
      if state.selectedRow == 0 then
        { state with surface := .actual, notice := "" }
      else
        { state with surface := .scheduled, notice := "" }
  | .record, state =>
      { state with surface := .record, notice := "" }
  | .back, state =>
      { state with surface := .home, notice := "" }
  | .mockPublish, state =>
      { state with surface := .home, notice := "MOCK ONLY: no file was written." }
  | .quit, state =>
      { state with done := true }

def app : App State Msg := {
  init := {},
  view := view,
  update := update,
  quitWhen := fun state => state.done,
  initialFocus := "root"
}

def main : IO Unit :=
  App.runWith app {
    width := 84,
    height := 24,
    focusOrder := ["root"]
  }

end Loam.Prototype.InteractionShellTeaMain
