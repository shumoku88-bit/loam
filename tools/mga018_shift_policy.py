#!/usr/bin/env python3
from pathlib import Path

path = Path("Loam/Tui/Reports.lean")
text = path.read_text()
old = '''private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward)
'''
new = '''private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  let result := Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward
  if result.state = state.window then
    { state with notice := result.notice }
  else
    applyWindowResult state result
'''
if text.count(old) != 1:
    raise SystemExit(f"expected one shift wrapper, found {text.count(old)}")
path.write_text(text.replace(old, new, 1))
print("updated", path)
