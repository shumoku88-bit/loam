import Loam.Tui.ActualWorkspace
import Loam.Tui.SelectedDay
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.Balances
import Loam.Tui.SettlementWorkspace
import Loam.Tui.Terminal
import Loam.Tui.Kernel
import Loam.Tui.Runtime

open Loam.Tui.Kernel
open Loam.Tui.Runtime

def testCleanTextExtraction : IO Unit := do
  let w : Widget := .column [
    .row [span "  Header line with spaces      "],
    .row [span "First column | Second column   "],
    .row [span "                               "],
    .row [span "Bottom footer text             "],
    .row [span "                               "],
    .row [span "                               "]
  ]
  let frame := compileWidget w
  let text := Loam.Tui.Terminal.compiledWidgetToCleanText frame
  let lines := text.splitOn "\n"
  if lines.length != 4 then
    throw (IO.userError s!"Expected 4 lines after dropping trailing blanks, got {lines.length}")
  if lines[0]? != some "  Header line with spaces" then
    throw (IO.userError s!"Expected trimmed header line, got {repr lines[0]?}")
  if lines[1]? != some "First column | Second column" then
    throw (IO.userError s!"Expected trimmed table line, got {repr lines[1]?}")
  if lines[2]? != some "" then
    throw (IO.userError s!"Expected preserved intermediate blank line, got {repr lines[2]?}")
  if lines[3]? != some "Bottom footer text" then
    throw (IO.userError s!"Expected trimmed footer line, got {repr lines[3]?}")

def testTallScreenCapacities : IO Unit := do
  let standardBounds : Bounds := { width := 80, height := 24 }
  let mediumBounds : Bounds := { width := 100, height := 36 }
  let tallBounds : Bounds := { width := 120, height := 60 }

  -- ActualWorkspace detail capacity
  if Loam.Tui.ActualWorkspace.detailCapacityForBounds standardBounds != 8 then
    throw (IO.userError "ActualWorkspace detail capacity at 24 should be 8")
  if Loam.Tui.ActualWorkspace.detailCapacityForBounds mediumBounds != 10 then
    throw (IO.userError "ActualWorkspace detail capacity at 36 should be 10")
  if Loam.Tui.ActualWorkspace.detailCapacityForBounds tallBounds != 12 then
    throw (IO.userError "ActualWorkspace detail capacity at 60 should be 12")

  -- SelectedDay detail capacity
  if Loam.Tui.SelectedDay.detailCapacityForBounds standardBounds != 6 then
    throw (IO.userError "SelectedDay detail capacity at 24 should be 6")
  if Loam.Tui.SelectedDay.detailCapacityForBounds mediumBounds != 8 then
    throw (IO.userError "SelectedDay detail capacity at 36 should be 8")
  if Loam.Tui.SelectedDay.detailCapacityForBounds tallBounds != 10 then
    throw (IO.userError "SelectedDay detail capacity at 60 should be 10")

  -- ScheduledWorkspace detail capacity
  if Loam.Tui.ScheduledWorkspace.detailCapacityForBounds standardBounds != 6 then
    throw (IO.userError "ScheduledWorkspace detail capacity at 24 should be 6")
  if Loam.Tui.ScheduledWorkspace.detailCapacityForBounds mediumBounds != 8 then
    throw (IO.userError "ScheduledWorkspace detail capacity at 36 should be 8")
  if Loam.Tui.ScheduledWorkspace.detailCapacityForBounds tallBounds != 10 then
    throw (IO.userError "ScheduledWorkspace detail capacity at 60 should be 10")

def main : IO Unit := do
  testCleanTextExtraction
  testTallScreenCapacities
  IO.println "Screen yank and tall display adaptation tests passed."
