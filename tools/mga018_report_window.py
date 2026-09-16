#!/usr/bin/env python3
from pathlib import Path
import re

path = Path("Loam/Tui/Reports.lean")
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    if text.count(old) != 1:
        raise SystemExit(f"expected one occurrence, found {text.count(old)}: {old[:80]!r}")
    text = text.replace(old, new, 1)


def replace_between(start: str, end: str, replacement: str) -> None:
    global text
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"missing start marker: {start!r}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"missing end marker: {end!r}")
    text = text[:a] + replacement + text[b:]

replace_once(
    "import Loam.Tui.RoleBalances\nimport Loam.Tui.Calendar\n",
    "import Loam.Tui.RoleBalances\nimport Loam.Tui.ReportWindow\nimport Loam.Tui.Calendar\n",
)

replace_between(
    "/-- Presentation-only source for the explicit report coordinates. -/\ninductive WindowSource where",
    "structure LiquidityForm where",
    "",
)

replace_once(
    "  form : Form := {}\n  liquidityForm : LiquidityForm := {}\n  calendarAnchor : String := \"\"\n  windowPresets : List Loam.BoundaryPresetConfig.Preset := []\n  windowSource : WindowSource := .calendarMonth\n",
    "  window : Loam.Tui.ReportWindow.State := {}\n  liquidityForm : LiquidityForm := {}\n",
)

replace_between(
    "def initialForDateWithPresets\n",
    "/-- Compatibility initializer when no named presets were loaded. -/",
    '''def initialForDateWithPresets
    (selectedDate : String)
    (presets : List Loam.BoundaryPresetConfig.Preset) : State :=
  let windowResult := Loam.Tui.ReportWindow.initialForDateWithPresets selectedDate presets
  {
    mode := .menu
    window := windowResult.state
    liquidityForm := liquidityFormForEndExclusive windowResult.state.form.endExclusive
    notice := windowResult.notice
  }

''',
)

replace_between(
    "def moveFocus (form : Form) (back : Bool) : Form :=",
    "private def moveLiquidityFocus",
    "",
)

replace_between(
    "def editActive (form : Form) (edit : String → String) : Form :=",
    "private def editLiquidityActive",
    "",
)

replace_between(
    "private def setCalendarWindow",
    "private def resetLiquidityHorizon",
    '''private def applyWindowResult
    (state : State) (result : Loam.Tui.ReportWindow.Result) : State :=
  clearResults { state with window := result.state, notice := result.notice }

private def resetCalendarMonth (state : State) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.resetCalendarMonth state.window)

private def cycleWindowSource (state : State) (forward : Bool) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.cycleSource state.window forward)

private def shiftCalendarMonth (state : State) (forward : Bool) : State :=
  applyWindowResult state (Loam.Tui.ReportWindow.shiftCalendarMonth state.window forward)

private def editWindowState (state : State) (edit : String → String) : State :=
  clearResults {
    state with
      window := Loam.Tui.ReportWindow.editActive state.window edit
      notice := ""
  }

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel (state : State) : String :=
  Loam.Tui.ReportWindow.sourceLabel state.window

''',
)

# The old shift implementation follows the Liquidity reset and is now owned by ReportWindow.
replace_between(
    "/-- Shift only while Calendar Month is the selected presentation source. -/\ndef shiftCalendarMonth",
    "private def selectMenuMode",
    "",
)

# Remaining direct access to the old flat window state becomes access to the one nested owner.
text = re.sub(r"(?<!\.)\bstate\.form\b", "state.window.form", text)
text = re.sub(r"(?<!\.)\bstate\.calendarAnchor\b", "state.window.calendarAnchor", text)

# Focus changes are window transitions, not flat Reports record updates.
text = text.replace(
    "form := moveFocus state.window.form false",
    "window := Loam.Tui.ReportWindow.moveFocus state.window false",
)
text = text.replace(
    "form := moveFocus state.window.form true",
    "window := Loam.Tui.ReportWindow.moveFocus state.window true",
)

# No retired flat owner may remain. Function names such as cycleWindowSource are
# intentionally retained as Reports composition helpers.
plain_residues = [
    "inductive WindowSource",
    "structure Form where",
    "windowPresets :",
    "windowSource : WindowSource",
    "state.windowSource",
]
for residue in plain_residues:
    if residue in text:
        raise SystemExit(f"retired Reports window residue remains: {residue}")
for pattern, label in [
    (r"(?<!\.)\bstate\.calendarAnchor\b", "state.calendarAnchor"),
    (r"(?<!\.)\bstate\.form\b", "state.form"),
]:
    if re.search(pattern, text):
        raise SystemExit(f"retired Reports window residue remains: {label}")

path.write_text(text)
print("updated", path)
