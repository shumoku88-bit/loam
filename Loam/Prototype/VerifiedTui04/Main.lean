import Loam.Prototype.VerifiedTui04.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Prototype.VerifiedTui04.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

inductive Surface where
  | home
  | actual
  | scheduled
  | recordDraft
  deriving Repr, DecidableEq, BEq

inductive Focus where
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

structure State where
  surface : Surface := .home
  day : Fin 30 := ⟨5, by decide⟩
  focus : Focus := .actual
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | left
  | right
  | up
  | down
  | tab
  | enter
  | record
  | back
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false
  deriving Repr, DecidableEq

def initialState : State := {}

def boundaryNotice : String :=
  "Adjacent month omitted in this prototype."

def movePreviousDay (state : State) : State :=
  if h : state.day.val = 0 then
    { state with notice := boundaryNotice }
  else
    { state with
      day := ⟨state.day.val - 1, by omega⟩
      notice := ""
    }

def moveNextDay (state : State) : State :=
  if h : state.day.val + 1 < 30 then
    { state with
      day := ⟨state.day.val + 1, h⟩
      notice := ""
    }
  else
    { state with notice := boundaryNotice }

def movePreviousWeek (state : State) : State :=
  if h : 7 ≤ state.day.val then
    { state with
      day := ⟨state.day.val - 7, by omega⟩
      notice := ""
    }
  else
    { state with notice := boundaryNotice }

def moveNextWeek (state : State) : State :=
  if h : state.day.val + 7 < 30 then
    { state with
      day := ⟨state.day.val + 7, h⟩
      notice := ""
    }
  else
    { state with notice := boundaryNotice }

def toggleFocus : Focus → Focus
  | .actual => .scheduled
  | .scheduled => .actual

def backHome (state : State) : State :=
  { state with surface := .home, notice := "" }

def update (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left =>
      if state.surface == .home then { state := movePreviousDay state } else { state }
  | .right =>
      if state.surface == .home then { state := moveNextDay state } else { state }
  | .up =>
      if state.surface == .home then { state := movePreviousWeek state } else { state }
  | .down =>
      if state.surface == .home then { state := moveNextWeek state } else { state }
  | .tab =>
      if state.surface == .home then
        { state := { state with focus := toggleFocus state.focus, notice := "" } }
      else
        { state }
  | .enter =>
      match state.surface with
      | .home =>
          { state :=
              { state with
                surface := if state.focus == .actual then .actual else .scheduled
                notice := ""
              }
          }
      | .recordDraft =>
          { state :=
              { state with
                surface := .home
                notice := "MOCK ONLY: no file was written."
              }
          }
      | _ => { state }
  | .record =>
      if state.surface == .home || state.surface == .scheduled then
        { state := { state with surface := .recordDraft, notice := "" } }
      else
        { state }
  | .back =>
      if state.surface == .home then { state } else { state := backHome state }
  | .other => { state }

theorem selection_bounds (state : State) : state.day.val < 30 :=
  state.day.isLt

theorem focus_closure (state : State) :
    state.focus = .actual ∨ state.focus = .scheduled := by
  cases state.focus <;> simp

theorem event_determinism (state : State) (event : Event) (left right : Step)
    (hLeft : update state event = left) (hRight : update state event = right) :
    left = right := by
  rw [← hLeft, ← hRight]

def screenBounds : Bounds :=
  { width := 80, height := 24 }

def plainLine (text : String) : Widget :=
  .row [span text]

def mutedLine (text : String) : Widget :=
  .row [span text .muted]

def blankLine : Widget :=
  .row []

def dayNumber (state : State) : Nat :=
  state.day.val + 1

def selectedDayText (state : State) : String :=
  "Sep " ++ toString (dayNumber state)

def dayCellText (day : Nat) : String :=
  if day < 10 then
    " " ++ toString day ++ "  "
  else
    toString day ++ "  "

def calendarCell (state : State) (slot : Nat) : Span :=
  if slot = 0 ∨ 30 < slot then
    span "    "
  else
    let style := if dayNumber state = slot then Style.selected else Style.normal
    span (dayCellText slot) style

def calendarRow (state : State) (row : Nat) : Widget :=
  .row <| (List.range 7).map fun col =>
    calendarCell state (row * 7 + col)

def calendarView (state : State) : List Widget :=
  [ plainLine "    September 2026"
  , mutedLine "Mon Tue Wed Thu Fri Sat Sun"
  ] ++ (List.range 5).map (calendarRow state)

def selectedDayLine (state : State) : Widget :=
  .row
    [ span "Selected day: "
    , span (" " ++ selectedDayText state ++ " ") .selected
    ]

def sectionTitle (selected : Bool) (label : String) : Widget :=
  let prefix := if selected then "▶ " else "  "
  .row [span (prefix ++ label) (if selected then .selected else .normal)]

def homeView (state : State) : Widget :=
  .column <|
    [ plainLine "LOAM UI Prototype 04  [SYNTHETIC / NO WRITES]"
    , mutedLine "Lean verified screen-diff mechanics spike"
    , blankLine
    ] ++
    calendarView state ++
    [ selectedDayLine state
    , blankLine
    , sectionTitle (state.focus == .actual) "Actual"
    , plainLine "    PayPay             -138 JPY"
    , plainLine "    coffee             +138 JPY"
    , blankLine
    , sectionTitle (state.focus == .scheduled) "Scheduled   Sep 10"
    , plainLine "    bank             -50,000 JPY"
    , plainLine "    rent             +50,000 JPY"
    , blankLine
    , mutedLine "←/→ Day    ↑/↓ Week    Tab Object    Enter Open    r Record    q Quit"
    , mutedLine state.notice
    ]

def actualView : Widget :=
  .column
    [ plainLine "Actual evidence"
    , blankLine
    , plainLine "Sep 5   coffee"
    , plainLine "    PayPay             -138 JPY"
    , plainLine "    coffee             +138 JPY"
    , blankLine
    , mutedLine "The signs show this synthetic movement effect directly."
    , mutedLine "b Back    q Quit"
    ]

def scheduledView : Widget :=
  .column
    [ plainLine "Scheduled expectation"
    , blankLine
    , plainLine "Sep 10   scheduled-7"
    , plainLine "    bank             -50,000 JPY"
    , plainLine "    rent             +50,000 JPY"
    , blankLine
    , mutedLine "This remains expectation, not Actual evidence."
    , mutedLine "r Record Actual mock    b Back    q Quit"
    ]

def recordView (state : State) : Widget :=
  .column
    [ plainLine "Record what happened  [MOCK DRAFT]"
    , blankLine
    , selectedDayLine state
    , plainLine "Movement"
    , plainLine "    PayPay             -138 JPY"
    , plainLine "    coffee             +138 JPY"
    , blankLine
    , mutedLine "Nothing is canonical. This prototype cannot write files."
    , mutedLine "Enter Mock publish    b Cancel    q Quit"
    ]

def view (state : State) : Widget :=
  match state.surface with
  | .home => homeView state
  | .actual => actualView
  | .scheduled => scheduledView
  | .recordDraft => recordView state

def screenFor (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view state)

def ansiStyle : Style → String
  | .normal => "\x1b[0m"
  | .selected => "\x1b[30;46m"
  | .muted => "\x1b[2m"

def cursorTo (row col : Nat) : String :=
  "\x1b[" ++ toString (row + 1) ++ ";" ++ toString (col + 1) ++ "H"

def emitPatch (changes : Patch screenBounds) : IO Unit := do
  for row in List.finRange screenBounds.height do
    for col in List.finRange screenBounds.width do
      let pos : Position screenBounds := { row, col }
      match changes pos with
      | none => pure ()
      | some cell =>
          IO.print (cursorTo row.val col.val ++ ansiStyle cell.style ++ toString cell.glyph)
  IO.print "\x1b[0m"
  (← IO.getStdout).flush

def emitOps (ops : List (TerminalOp screenBounds)) : IO Unit := do
  for op in ops do
    match op with
    | .patch changes => emitPatch changes

inductive Key where
  | left
  | right
  | up
  | down
  | tab
  | enter
  | record
  | back
  | quit
  | other
  deriving Repr, DecidableEq

def readByte : IO UInt8 := do
  let bytes ← (← IO.getStdin).read 1
  if bytes.isEmpty then
    return 0
  return bytes.get! 0

def readKey : IO Key := do
  let first ← readByte
  match first.toNat with
  | 27 =>
      let second ← readByte
      let third ← readByte
      if second.toNat != 91 then
        return .other
      match third.toNat with
      | 65 => return .up
      | 66 => return .down
      | 67 => return .right
      | 68 => return .left
      | _ => return .other
  | 9 => return .tab
  | 10 | 13 => return .enter
  | 114 | 82 => return .record
  | 98 | 66 => return .back
  | 113 | 81 => return .quit
  | _ => return .other

def keyEvent : Key → Event
  | .left => .left
  | .right => .right
  | .up => .up
  | .down => .down
  | .tab => .tab
  | .enter => .enter
  | .record => .record
  | .back => .back
  | .quit => .quit
  | .other => .other

def setTerminalMode (mode : String) : IO Unit := do
  discard <| IO.Process.run
    { cmd := "sh"
      args := #["-c", "stty " ++ mode ++ " < /dev/tty"]
    }

def enterTerminal : IO Unit := do
  setTerminalMode "-echo -icanon min 1 time 0"
  IO.print "\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H"
  (← IO.getStdout).flush

def leaveTerminal : IO Unit := do
  IO.print "\x1b[0m\x1b[?25h\x1b[?1049l"
  (← IO.getStdout).flush
  setTerminalMode "sane"

partial def loop (state : State) (screen : Screen screenBounds) : IO Unit := do
  let event := keyEvent (← readKey)
  let step := update state event
  if step.quit then
    return
  let nextScreen := screenFor step.state
  emitOps (diff screen nextScreen)
  loop step.state nextScreen

def main : IO Unit := do
  enterTerminal
  try
    let state := initialState
    let screen := screenFor state
    emitOps (diff (blankScreen screenBounds) screen)
    loop state screen
  finally
    leaveTerminal

end Loam.Prototype.VerifiedTui04.Main
