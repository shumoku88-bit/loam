import Loam.ActualDate

namespace Loam.Tui.Calendar

set_option autoImplicit false

structure Month where
  year : Nat
  month : Nat
  deriving Repr, DecidableEq

def padded (width value : Nat) : String :=
  let text := toString value
  String.ofList (List.replicate (width - text.length) '0') ++ text

def parseDate? (text : String) : Option (Nat × Nat × Nat) := do
  if !Loam.ActualDate.validIsoDate text then none else do
    let [yearText, monthText, dayText] := text.splitOn "-" | none
    let year ← yearText.toNat?
    let month ← monthText.toNat?
    let day ← dayText.toNat?
    pure (year, month, day)

def monthOf? (text : String) : Option Month := do
  let (year, month, _) ← parseDate? text
  pure { year, month }

def isLeapYear (year : Nat) : Bool :=
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)

def daysInMonth? (month : Month) : Option Nat :=
  match month.month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => some 31
  | 4 | 6 | 9 | 11 => some 30
  | 2 => if isLeapYear month.year then some 29 else some 28
  | _ => none

def dateForDay (month : Month) (day : Nat) : String :=
  padded 4 month.year ++ "-" ++ padded 2 month.month ++ "-" ++ padded 2 day

private def monthOffset : Nat → Nat
  | 1 => 0
  | 2 => 3
  | 3 => 2
  | 4 => 5
  | 5 => 0
  | 6 => 3
  | 7 => 5
  | 8 => 1
  | 9 => 4
  | 10 => 6
  | 11 => 2
  | 12 => 4
  | _ => 0

/-- Monday-first weekday index for the first day of a Gregorian month. -/
def firstWeekdayMonday (month : Month) : Nat :=
  let year := if month.month < 3 then month.year - 1 else month.year
  let sundayFirst :=
    (year + year / 4 + year / 400 + monthOffset month.month + 1 - year / 100) % 7
  (sundayFirst + 6) % 7

/-- Six stable calendar rows, padded with `none` before and after this month. -/
def slots (month : Month) : List (Option String) :=
  match daysInMonth? month with
  | none => List.replicate 42 none
  | some count =>
      let leading := firstWeekdayMonday month
      let dates := (List.range count).map fun index => some (dateForDay month (index + 1))
      let used := leading + count
      List.replicate leading none ++ dates ++ List.replicate (42 - used) none

def monthLabel (month : Month) : String :=
  padded 4 month.year ++ "-" ++ padded 2 month.month

example : firstWeekdayMonday { year := 2026, month := 9 } = 1 := by native_decide
example : (slots { year := 2026, month := 9 })[1]? = some (some "2026-09-01") := by native_decide
example : (slots { year := 2026, month := 9 })[30]? = some (some "2026-09-30") := by native_decide

end Loam.Tui.Calendar
