import Std

namespace Loam.ActualDate

set_option autoImplicit false

private def isLeapYear (year : Nat) : Bool :=
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)

private def daysInMonth? (year month : Nat) : Option Nat :=
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => some 31
  | 4 | 6 | 9 | 11 => some 30
  | 2 => if isLeapYear year then some 29 else some 28
  | _ => none

/--
Validate the practical occurrence-date spelling used by the CLI and persistence.

The retained coordinate is still an ordinary ISO `YYYY-MM-DD` token supplied to
`ActualValidity String`; this adapter only prevents malformed or impossible
calendar dates from entering that practical stream. It does not add a date field
to `Event` or introduce a general calendar framework.
-/
def validIsoDate (text : String) : Bool :=
  match text.splitOn "-" with
  | [yearText, monthText, dayText] =>
      if yearText.length != 4 || monthText.length != 2 || dayText.length != 2 then
        false
      else
        match yearText.toNat?, monthText.toNat?, dayText.toNat? with
        | some year, some month, some day =>
            if year = 0 || day = 0 then
              false
            else
              match daysInMonth? year month with
              | none => false
              | some limit => day <= limit
        | _, _, _ => false
  | _ => false

/-- Read the host-local calendar day in the same ISO spelling used by the CLI. -/
def todayIso? : IO (Option String) := do
  try
    let output ← IO.Process.output {
      cmd := "date"
      args := #["+%Y-%m-%d"]
    }
    if output.exitCode = 0 then
      let text := output.stdout.trimAsciiEnd.toString.trimAsciiStart.toString
      if validIsoDate text then return some text else return none
    else
      return none
  catch _ =>
    return none

private def validateOccurrenceDate (text : String) : Except String String :=
  if validIsoDate text then
    Except.ok text
  else
    Except.error "loam: date must be a real calendar date in YYYY-MM-DD form"

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def defaultOccurrenceDate : IO (Except String String) := do
  match ← todayIso? with
  | some today => return Except.ok today
  | none =>
      return Except.error
        "loam: could not determine the local date; set LOAM_OCCURRENCE_DATE=YYYY-MM-DD"

/--
Choose the shared practical Actual occurrence date.

Interactive callers may accept the host-local day or type another ISO date.
Redirected callers do not consume stdin for the date: `LOAM_OCCURRENCE_DATE`
may provide an explicit day, otherwise the host-local day is used. Movement
recording and Scheduled completion share this adapter so their Actual date
entry cannot drift into different conventions.
-/
def practicalOccurrenceDate : IO (Except String String) := do
  let stdin ← IO.getStdin
  if !(← stdin.isTty) then
    match ← IO.getEnv "LOAM_OCCURRENCE_DATE" with
    | some configured => return validateOccurrenceDate configured
    | none => defaultOccurrenceDate
  else
    match ← todayIso? with
    | some today =>
        let entered ← promptLine ("Date [" ++ today ++ "]: ")
        if entered.isEmpty then
          return Except.ok today
        else
          return validateOccurrenceDate entered
    | none =>
        let entered ← promptLine "Date (YYYY-MM-DD): "
        return validateOccurrenceDate entered

example : validIsoDate "2026-09-03" = true := by native_decide
example : validIsoDate "2024-02-29" = true := by native_decide
example : validIsoDate "2026-02-29" = false := by native_decide
example : validIsoDate "2026-13-01" = false := by native_decide
example : validIsoDate "26-09-03" = false := by native_decide

end Loam.ActualDate
