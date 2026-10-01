import Loam.ActualDate
import Loam.Tui.Calendar

namespace Loam.Tui.DateJump

open Loam.Tui.Calendar

set_option autoImplicit false

inductive ZoomLevel where
  | day
  | month
  | year
  deriving Repr, DecidableEq, BEq

def cycleZoom : ZoomLevel → ZoomLevel
  | .day => .month
  | .month => .year
  | .year => .day

def zoomLabel : ZoomLevel → String
  | .day => "Day"
  | .month => "Month"
  | .year => "Year"

/-- Result of a parsed jump query: target date (ISO YYYY-MM-DD) and intended zoom level. -/
structure JumpTarget where
  date : String
  zoom : ZoomLevel
  deriving Repr, DecidableEq, BEq

private def isDigits (text : String) : Bool :=
  !text.isEmpty && text.all Char.isDigit

private def normalizeSeparators (text : String) : String :=
  text.map (fun c => if c == '/' then '-' else c)

/--
Parse an interactive jump target query from an optional base date (ISO YYYY-MM-DD).

Supported patterns:
- Full date: `YYYY-MM-DD`, `YYYY/MM/DD`, or 8-digit `YYYYMMDD` (zooms to Day)
- Month: `YYYY-MM`, `YYYY/MM`, or 6-digit `YYYYMM` (zooms to Month, target day 01)
- Year: `YYYY` 4-digit year (zooms to Year, target Jan 01)
- Short date: `MM-DD`, `M-D`, `MM/DD` (uses base date year, zooms to Day)
- Day of current month: `DD` or `D` (uses base date year & month, zooms to Day)
-/
def parseJumpTarget (baseDate : String) (raw : String) : Option JumpTarget := do
  let clean := raw.trimAsciiEnd.toString.trimAsciiStart.toString
  if clean.isEmpty then none else do
  let norm := normalizeSeparators clean

  -- 1. Full ISO date YYYY-MM-DD (or YYYY/MM/DD)
  if Loam.ActualDate.validIsoDate norm then
    some { date := norm, zoom := .day }

  -- 2. Full compact date YYYYMMDD (8 digits)
  else if norm.length == 8 && isDigits norm then
    let y := norm.take 4
    let m := (norm.drop 4).take 2
    let d := norm.drop 6
    let iso := s!"{y}-{m}-{d}"
    if Loam.ActualDate.validIsoDate iso then
      some { date := iso, zoom := .day }
    else
      none

  -- 3. Compact month YYYYMM (6 digits)
  else if norm.length == 6 && isDigits norm then
    let y ← (norm.take 4).toNat?
    let m ← (norm.drop 4).toNat?
    if 1000 ≤ y && y ≤ 9999 && 1 ≤ m && m ≤ 12 then
      some { date := s!"{padded 4 y}-{padded 2 m}-01", zoom := .month }
    else
      none

  -- 4. Year only YYYY (4 digits)
  else if norm.length == 4 && isDigits norm then
    let y ← norm.toNat?
    if 1000 ≤ y && y ≤ 9999 then
      some { date := s!"{padded 4 y}-01-01", zoom := .year }
    else
      none

  -- 5. Split by '-'
  else
    match norm.splitOn "-" with
    -- YYYY-MM (e.g. 2026-10 or 2026-9)
    | [yText, mText] =>
        if yText.length == 4 && isDigits yText && isDigits mText then do
          let y ← yText.toNat?
          let m ← mText.toNat?
          if 1000 ≤ y && y ≤ 9999 && 1 ≤ m && m ≤ 12 then
            some { date := s!"{padded 4 y}-{padded 2 m}-01", zoom := .month }
          else
            none
        -- Short date MM-DD or M-D using base year
        else if (mText.length == 1 || mText.length == 2) && isDigits yText && isDigits mText then do
          let (baseYear, _, _) ← parseDate? baseDate
          let m ← yText.toNat?
          let d ← mText.toNat?
          let iso := s!"{padded 4 baseYear}-{padded 2 m}-{padded 2 d}"
          if Loam.ActualDate.validIsoDate iso then
            some { date := iso, zoom := .day }
          else
            none
        else
          none

    -- Day of current month DD or D (1 or 2 digits)
    | [dText] =>
        if (dText.length == 1 || dText.length == 2) && isDigits dText then do
          let (baseYear, baseMonth, _) ← parseDate? baseDate
          let d ← dText.toNat?
          let iso := s!"{padded 4 baseYear}-{padded 2 baseMonth}-{padded 2 d}"
          if Loam.ActualDate.validIsoDate iso then
            some { date := iso, zoom := .day }
          else
            none
        else
          none

    | _ => none

-- Verification examples
example : parseJumpTarget "2026-10-01" "2025-08-15" =
    some { date := "2025-08-15", zoom := .day } := by native_decide
example : parseJumpTarget "2026-10-01" "2025/08/15" =
    some { date := "2025-08-15", zoom := .day } := by native_decide
example : parseJumpTarget "2026-10-01" "20250815" =
    some { date := "2025-08-15", zoom := .day } := by native_decide
example : parseJumpTarget "2026-10-01" "2025-08" =
    some { date := "2025-08-01", zoom := .month } := by native_decide
example : parseJumpTarget "2026-10-01" "2025/8" =
    some { date := "2025-08-01", zoom := .month } := by native_decide
example : parseJumpTarget "2026-10-01" "2025" =
    some { date := "2025-01-01", zoom := .year } := by native_decide
example : parseJumpTarget "2026-10-01" "12-25" =
    some { date := "2026-12-25", zoom := .day } := by native_decide
example : parseJumpTarget "2026-10-01" "15" =
    some { date := "2026-10-15", zoom := .day } := by native_decide
example : parseJumpTarget "2026-10-01" "99" = none := by native_decide
example : parseJumpTarget "2026-10-01" "invalid" = none := by native_decide

end Loam.Tui.DateJump
