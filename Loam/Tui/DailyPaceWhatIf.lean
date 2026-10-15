import Loam.Tui.Main
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.Terminal

namespace Loam.Tui.DailyPaceWhatIf

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Read-only Daily Pace purchase scenario

The only baseline is the already-admitted *current* Daily Pace answer. A
hypothetical purchase is an immediate JPY outflow from its configured balance
pool and is not already represented by Scheduled. This does not publish, reserve
money, infer account eligibility, or forecast a future cycle.
-/

structure State where
  amount : String := ""
  notice : String := ""
  deriving Repr, DecidableEq

inductive Step where
  | stay (state : State)
  | back

structure Projection where
  currentPerDay : Int
  projectedPerDay : Int
  changePerDay : Int
  availableAfter : Int
  deriving Repr, DecidableEq

/-- Require an admitted today-point, never substitute a stale historical value. -/
def current? (snapshot : Loam.Tui.Main.Snapshot) :
    Except String Loam.CycleSpendingPaceReview.Snapshot := do
  let periods ← match snapshot.pacePeriods with
    | .loaded periods => pure periods
    | .failed message => throw ("Current Daily Pace unavailable: " ++ message)
    | .unavailable => throw "Current Daily Pace unavailable."
    | .notRequested => throw "Current Daily Pace not requested."
  let some period := periods.find? (fun period => period.preset == .tenDays)
    | throw "Current Daily Pace period missing."
  let history ← match period.history with
    | .loaded history => pure history
    | .failed message => throw ("Current Daily Pace unavailable: " ++ message)
    | .unavailable => throw "Current Daily Pace unavailable."
    | .notRequested => throw "Current Daily Pace not requested."
  let some point := history.getLast?
    | throw "Current Daily Pace has no observations."
  if point.observedAt != snapshot.actual.today then
    throw "Current Daily Pace today-point missing; past estimates cannot price a purchase now."
  if point.measure.token != "jpy" then
    throw "This first calculator accepts JPY only; conversion is not assumed."
  if point.dailyPaceQuanta?.isNone then
    throw "Current Daily Pace has no valid remaining-day count."
  return point

/-- Exact integer-quanta projection; the existing pace owns all deductions. -/
def project? (point : Loam.CycleSpendingPaceReview.Snapshot)
    (input : String) : Except String Projection := do
  if point.measure.token != "jpy" then throw "JPY only."
  if point.remainingDays == 0 then throw "No remaining days in this cycle."
  if input.isEmpty || input.length > 18 ||
      !input.toList.all (fun c => decide (48 ≤ c.toNat && c.toNat ≤ 57)) then
    throw "Enter a nonnegative JPY amount (up to 18 digits)."
  let some quanta := input.toNat?
    | throw "Invalid JPY amount."
  let some baseline := point.dailyPaceQuanta?
    | throw "Current Daily Pace unavailable."
  let afterAvailable := point.availableThroughEnd.quanta - Int.ofNat quanta
  let projected := afterAvailable / Int.ofNat point.remainingDays
  return {
    currentPerDay := baseline
    projectedPerDay := projected
    changePerDay := projected - baseline
    availableAfter := afterAvailable
  }

/-- This editing state is ephemeral. Enter never commits anything. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' => .back
  | .backspace =>
      .stay { state with
        amount := Loam.Tui.Terminal.backspaceText state.amount, notice := "" }
  | .input char =>
      if decide (48 ≤ char.toNat && char.toNat ≤ 57) && state.amount.length < 18 then
        .stay { state with amount := state.amount.push char, notice := "" }
      else
        .stay { state with notice := "Only JPY digits, at most 18. Esc/q closes." }
  | .paste pasted =>
      let candidate := state.amount ++ pasted
      if candidate.length ≤ 18 &&
          candidate.toList.all (fun c => decide (48 ≤ c.toNat && c.toNat ≤ 57)) then
        .stay { state with amount := candidate, notice := "" }
      else
        .stay { state with notice := "Paste refused: enter up to 18 JPY digits." }
  | _ => .stay state

private def fmt (amount : Int) : String :=
  Loam.MeasurePresentation.groupDisplayedNumber (toString amount)

private def line (value : String) : Widget := .row [span value]

private def info (width : Nat) (value : String) : List Widget :=
  (Loam.Tui.Layout.wrapColumns width value).map line

def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 62 20 86 18

private def innerView (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot)
    (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let body := [line " Daily Pace / What if",
    .row [span " Purchase (JPY): " .muted,
      Loam.Tui.Layout.inputSpan (width - Loam.Tui.Layout.displayWidth " Purchase (JPY): ") true state.amount]]
    ++ (match current? snapshot with
      | .error message =>
          info width "Current projection unavailable (not zero)." ++ info width message
      | .ok point =>
          [line (" Current: " ++ fmt ((point.dailyPaceQuanta?).getD 0) ++ " jpy/day"),
           line (" Remaining days: " ++ toString point.remainingDays),
           line (" Already protected Scheduled: " ++ fmt point.automaticDeductions.quanta ++ " jpy")]
          ++ (if state.amount.isEmpty then
                [line " Enter amount to compare; nothing is recorded."]
              else
                match project? point state.amount with
                | .error message => info width message
                | .ok result =>
                    [line (" After purchase: " ++ fmt result.projectedPerDay ++ " jpy/day"),
                     line (" Daily change: " ++ fmt result.changePerDay ++ " jpy/day"),
                     line (" Available after: " ++ fmt result.availableAfter ++ " jpy")]))
    ++ (if state.notice.isEmpty then [] else info width state.notice)
  let footer := Loam.Tui.Layout.boundFeedbackFooter bounds
    [line " Immediate purchase from selected Daily Pace pool only.",
     line " Not already Scheduled. No writes or reservations. Esc/q closes."]
  .column ((Loam.Tui.Layout.fitWithFooter bounds body footer).map fun row =>
    Loam.Tui.Layout.clipWidgetRow width row)

/-- Same shared float/compact shell as other TUI editors; no writer or editor session. -/
def viewForBounds (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot)
    (state : State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Daily Pace / What if"
    (fun inner => innerView inner snapshot state)

end Loam.Tui.DailyPaceWhatIf
