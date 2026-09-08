import Loam.BudgetWindowReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.Reports

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Reports / Budget Window

This local interaction state edits explicit query coordinates. For convenience,
production may seed those coordinates with the Gregorian calendar month containing
the Home selected day. That constructor is presentation-only: it does not choose
a household cycle, budget period, or retained report identity. Canonical evidence
loading and budget / Headroom semantics remain outside this module in
`BudgetWindowReview` / Application.
-/

structure Form where
  start : String := ""
  endExclusive : String := ""
  focus : Fin 3 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

structure Query where
  start : String
  endExclusive : String
  deriving Repr, DecidableEq

structure State where
  form : Form := {}
  calendarAnchor : String := ""
  snapshot : Option Loam.BudgetWindowReview.Snapshot := none
  notice : String := ""
  deriving Repr, DecidableEq

structure Step where
  state : State
  back : Bool := false
  query : Option Query := none


def initial : State := {}

/-- Seed the editor with the explicit Gregorian month containing the selected day.
The resulting coordinates remain editable and carry no household-cycle meaning. -/
def initialForDate (selectedDate : String) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? selectedDate with
  | some (start, endExclusive) =>
      {
        form := { start := start, endExclusive := endExclusive, focus := ⟨2, by decide⟩ }
        calendarAnchor := selectedDate
      }
  | none =>
      {
        calendarAnchor := selectedDate
        notice := "Calendar-month prefill unavailable; enter an explicit window."
      }


def withSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with snapshot := some snapshot, notice := "" }


def withError (state : State) (message : String) : State :=
  { state with snapshot := none, notice := message }


def moveFocus (form : Form) (back : Bool) : Form :=
  let next := if back then (form.focus.val + 2) % 3 else (form.focus.val + 1) % 3
  { form with focus := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by decide)⟩ }


def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus.val = 0 then { form with start := edit form.start }
  else if form.focus.val = 1 then { form with endExclusive := edit form.endExclusive }
  else form

private def setCalendarWindow
    (state : State) (start endExclusive : String) : State :=
  { state with
      form := { state.form with start := start, endExclusive := endExclusive }
      snapshot := none
      notice := "" }

/-- Restore the calendar month containing the Home selected day. -/
def resetCalendarMonth (state : State) : State :=
  match Loam.Tui.Calendar.calendarMonthWindowForDate? state.calendarAnchor with
  | some (start, endExclusive) =>
      { (setCalendarWindow state start endExclusive) with
          form := { state.form with
            start := start
            endExclusive := endExclusive
            focus := ⟨2, by decide⟩ } }
  | none =>
      { state with
          snapshot := none
          notice := "Calendar-month reset unavailable; enter an explicit window." }

/-- Shift only when the currently visible coordinates are exactly one calendar month. -/
def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  match Loam.Tui.Calendar.shiftCalendarMonthWindow?
      state.form.start state.form.endExclusive forward with
  | some (start, endExclusive) => setCalendarWindow state start endExclusive
  | none =>
      { state with
          notice := "Arrow keys shift calendar-month windows only; press m to restore one." }


def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, back := true }
  | .left => { state := shiftCalendarMonth state false }
  | .right => { state := shiftCalendarMonth state true }
  | .tab => { state := { state with form := moveFocus state.form false, notice := "" } }
  | .shiftTab => { state := { state with form := moveFocus state.form true, notice := "" } }
  | .backspace =>
      { state := { state with
          form := editActive state.form (fun text => String.ofList text.toList.dropLast)
          snapshot := none
          notice := "" } }
  | .input 'm' | .input 'M' => { state := resetCalendarMonth state }
  | .input char =>
      { state := { state with
          form := editActive state.form (fun text => text.push char)
          snapshot := none
          notice := "" } }
  | .enter =>
      if state.form.focus.val < 2 then
        { state := { state with form := moveFocus state.form false, notice := "" } }
      else
        { state, query := some {
            start := state.form.start
            endExclusive := state.form.endExclusive
          } }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def field (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.form.focus.val = index then .selected else .normal)
    ]

private def rowLines (row : Loam.BudgetWindowReview.Row) : List Widget :=
  [ line
      ("- " ++ row.purpose.token ++
        ": entitlement " ++ toString row.entitlement.quanta ++
        " | consumption " ++ toString row.consumption.quanta ++
        " | remaining " ++ toString row.remaining.quanta ++ " jpy")
  , muted
      ("  commitment<end " ++ toString row.commitment.quanta ++
        " | headroom " ++ toString row.headroom.quanta ++ " jpy")
  ]

private def frontierLines
    (frontier : Option Loam.BudgetWindowReview.ScheduledFrontier) : List Widget :=
  match frontier with
  | none => [muted "Scheduled frontier: no remembered Capacity Purpose to project."]
  | some frontier =>
      [ muted
          ("Scheduled frontier jpy: unmanaged " ++ toString frontier.unmanaged.quanta ++
            " | unrouted " ++ toString frontier.unrouted.quanta ++
            " | unresolved eligibility " ++ toString frontier.unresolvedEligibility.quanta)
      ]

private def resultLines (state : State) : List Widget :=
  match state.snapshot with
  | none => [muted "No explicit window has been run yet."]
  | some snapshot =>
      [ line ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted ("Scheduled routing observed at " ++ snapshot.observedAt)
      , muted (toString snapshot.rows.length ++ " remembered purpose(s)")
      ] ++
      (snapshot.rows.take 10).flatMap rowLines ++
      frontierLines snapshot.scheduledFrontier ++
      [ muted "Remaining = window Entitlement - window Consumption."
      , muted "Headroom = Remaining - managed current-open Scheduled pressure due before End."
      , muted "Start does not discard overdue current-open Scheduled pressure."
      ]

/-- Render one explicit-coordinate Budget Window report editor/result surface. -/
def view (state : State) : Widget :=
  .column <|
    [ line "Reports / Budget Window"
    , muted "Home > Reports > Budget Window"
    , muted "Calendar month is only a coordinate convenience, not a household cycle."
    , blank
    , field state 0 "Start" state.form.start
    , field state 1 "End (exclusive)" state.form.endExclusive
    , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
    , muted "Coordinates stay explicit [start, end); no cycle or budget period is inferred."
    , blank
    ] ++
    resultLines state ++
    [ blank
    , muted "← / → calendar month   m selected-day month"
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc home   q quit"
    , line state.notice
    ]

end Loam.Tui.Reports
