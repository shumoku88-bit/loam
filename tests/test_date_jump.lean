import Loam.Tui.DateJump

open Loam.Tui.DateJump

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

def main : IO Unit := do
  -- Full ISO date
  let r1 := parseJumpTarget "2026-10-01" "2025-08-15"
  expect (r1 == some { date := "2025-08-15", zoom := .day }) "Failed full ISO date"

  -- Slash format
  let r2 := parseJumpTarget "2026-10-01" "2025/08/15"
  expect (r2 == some { date := "2025-08-15", zoom := .day }) "Failed slash format"

  -- Compact 8 digits
  let r3 := parseJumpTarget "2026-10-01" "20250815"
  expect (r3 == some { date := "2025-08-15", zoom := .day }) "Failed compact 8 digits"

  -- Month format YYYY-MM
  let r4 := parseJumpTarget "2026-10-01" "2025-08"
  expect (r4 == some { date := "2025-08-01", zoom := .month }) "Failed YYYY-MM"

  -- Compact 6 digits
  let r5 := parseJumpTarget "2026-10-01" "202508"
  expect (r5 == some { date := "2025-08-01", zoom := .month }) "Failed YYYYMM"

  -- Year format YYYY
  let r6 := parseJumpTarget "2026-10-01" "2025"
  expect (r6 == some { date := "2025-01-01", zoom := .year }) "Failed YYYY"

  -- Short MM-DD using base year
  let r7 := parseJumpTarget "2026-10-01" "12-25"
  expect (r7 == some { date := "2026-12-25", zoom := .day }) "Failed MM-DD"

  -- Day only using base year & month
  let r8 := parseJumpTarget "2026-10-01" "15"
  expect (r8 == some { date := "2026-10-15", zoom := .day }) "Failed DD"

  -- Zoom cycle
  expect (cycleZoom .day == .month) "cycle day -> month"
  expect (cycleZoom .month == .year) "cycle month -> year"
  expect (cycleZoom .year == .day) "cycle year -> day"

  -- Invalid dates
  expect (parseJumpTarget "2026-10-01" "99" == none) "Day 99 must be rejected"
  expect (parseJumpTarget "2026-10-01" "2026-02-30" == none) "Feb 30 must be rejected"
  expect (parseJumpTarget "2026-10-01" "abc" == none) "abc must be rejected"
  expect (parseJumpTarget "2026-10-01" "" == none) "empty must be rejected"

  IO.println "All DateJump tests passed successfully!"
