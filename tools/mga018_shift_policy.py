#!/usr/bin/env python3
from pathlib import Path

report_window = Path("Loam/Tui/ReportWindow.lean")
window_text = report_window.read_text()
old_result = '''structure Result where
  state : State
  notice : String := ""
  deriving Repr, DecidableEq
'''
new_result = '''structure Result where
  state : State
  notice : String := ""
  changed : Bool := false
  deriving Repr, DecidableEq
'''
if window_text.count(old_result) != 1:
    raise SystemExit(f"expected one ReportWindow.Result, found {window_text.count(old_result)}")
window_text = window_text.replace(old_result, new_result, 1)

old_shift_success = '''      | some (start, endExclusive) =>
          { state := setCalendarCoordinates state start endExclusive }
'''
new_shift_success = '''      | some (start, endExclusive) =>
          { state := setCalendarCoordinates state start endExclusive
            changed := true }
'''
if window_text.count(old_shift_success) != 1:
    raise SystemExit(f"expected one shift success branch, found {window_text.count(old_shift_success)}")
window_text = window_text.replace(old_shift_success, new_shift_success, 1)
report_window.write_text(window_text)

reports = Path("Loam/Tui/Reports.lean")
text = reports.read_text()
old = '''private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward)
'''
new = '''private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  let result := Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward
  if result.changed then
    applyWindowResult state result
  else
    { state with notice := result.notice }
'''
if text.count(old) != 1:
    raise SystemExit(f"expected one shift wrapper, found {text.count(old)}")
reports.write_text(text.replace(old, new, 1))
print("updated", report_window)
print("updated", reports)
