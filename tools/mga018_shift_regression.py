#!/usr/bin/env python3
from pathlib import Path

path = Path("Loam/Tests/TuiReports.lean")
text = path.read_text()
needle = '''  let stockReportText := widgetText (Loam.Tui.Reports.view stockReport)
'''
insert = '''  let refusedShiftFromReport := (Loam.Tui.Reports.update stockReport .right).state
  expect refusedShiftFromReport.stockFlowSnapshot.isSome
    "refused non-calendar shift discarded the existing Stock-Flow snapshot"

  let stockReportText := widgetText (Loam.Tui.Reports.view stockReport)
'''
if text.count(needle) != 1:
    raise SystemExit(f"expected one stock report text marker, found {text.count(needle)}")
path.write_text(text.replace(needle, insert, 1))
print("updated", path)
