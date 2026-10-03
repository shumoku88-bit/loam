import Loam.Tui.ActualWorkspace
import Loam.Tui.SelectedDay
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.Terminal
import Loam.Tui.Kernel
import Loam.Tui.Main

open Loam.Tui.Kernel
open Loam.Tui.Terminal

def testCsiDecoding : IO Unit := do
  -- Page Up
  if decodeCsi "5" 126 != Key.pageUp then
    throw (IO.userError "Expected decodeCsi '5' ~ to be .pageUp")
  if decodeCsi "5;2" 126 != Key.pageUp then
    throw (IO.userError "Expected decodeCsi '5;2' ~ to be .pageUp")

  -- Page Down
  if decodeCsi "6" 126 != Key.pageDown then
    throw (IO.userError "Expected decodeCsi '6' ~ to be .pageDown")
  if decodeCsi "6;2" 126 != Key.pageDown then
    throw (IO.userError "Expected decodeCsi '6;2' ~ to be .pageDown")

  -- Delete
  if decodeCsi "3" 126 != Key.delete then
    throw (IO.userError "Expected decodeCsi '3' ~ to be .delete")
  if decodeCsi "3;5" 126 != Key.delete then
    throw (IO.userError "Expected decodeCsi '3;5' ~ to be .delete")

  -- Home
  if decodeCsi "" 72 != Key.home then
    throw (IO.userError "Expected decodeCsi '' 'H' to be .home")
  if decodeCsi "1" 126 != Key.home then
    throw (IO.userError "Expected decodeCsi '1' ~ to be .home")
  if decodeCsi "7" 126 != Key.home then
    throw (IO.userError "Expected decodeCsi '7' ~ to be .home")

  -- End
  if decodeCsi "" 70 != Key.«end» then
    throw (IO.userError "Expected decodeCsi '' 'F' to be .«end»")
  if decodeCsi "4" 126 != Key.«end» then
    throw (IO.userError "Expected decodeCsi '4' ~ to be .«end»")
  if decodeCsi "8" 126 != Key.«end» then
    throw (IO.userError "Expected decodeCsi '8' ~ to be .«end»")

  -- Standard arrows and shiftTab
  if decodeCsi "" 65 != Key.up then
    throw (IO.userError "Expected decodeCsi '' 'A' to be .up")
  if decodeCsi "" 66 != Key.down then
    throw (IO.userError "Expected decodeCsi '' 'B' to be .down")
  if decodeCsi "" 67 != Key.right then
    throw (IO.userError "Expected decodeCsi '' 'C' to be .right")
  if decodeCsi "" 68 != Key.left then
    throw (IO.userError "Expected decodeCsi '' 'D' to be .left")
  if decodeCsi "" 90 != Key.shiftTab then
    throw (IO.userError "Expected decodeCsi '' 'Z' to be .shiftTab")

def testActualWorkspaceNavigation : IO Unit := do
  let emptySnapshot : Loam.Tui.Main.Snapshot := {
    actual := {
      today := "2026-10-03"
      allRecords := []
    }
    scheduled := .error "unavailable"
  }
  let initial := Loam.Tui.ActualWorkspace.initial "2026-10-03"
  -- Navigation on empty list should be safe and clamp to 0
  let step1 := Loam.Tui.ActualWorkspace.update emptySnapshot initial .pageDown
  if step1.state.transactionRow != 0 then
    throw (IO.userError "PageDown on empty actuals should keep row 0")

  let step2 := Loam.Tui.ActualWorkspace.update emptySnapshot initial .pageUp
  if step2.state.transactionRow != 0 then
    throw (IO.userError "PageUp on empty actuals should keep row 0")

  let step3 := Loam.Tui.ActualWorkspace.update emptySnapshot initial .home
  if step3.state.transactionRow != 0 then
    throw (IO.userError "Home on empty actuals should keep row 0")

  let step4 := Loam.Tui.ActualWorkspace.update emptySnapshot initial .«end»
  if step4.state.transactionRow != 0 then
    throw (IO.userError "End on empty actuals should keep row 0")

def testSelectedDayNavigation : IO Unit := do
  let emptySnapshot : Loam.Tui.Main.Snapshot := {
    actual := {
      today := "2026-10-03"
      allRecords := []
    }
    scheduled := .error "unavailable"
  }
  let initial := Loam.Tui.SelectedDay.initial "2026-10-03"
  let step1 := Loam.Tui.SelectedDay.update emptySnapshot initial .pageDown
  if step1.state.actualRow != 0 then
    throw (IO.userError "PageDown on empty selected day should keep row 0")

  let step2 := Loam.Tui.SelectedDay.update emptySnapshot initial .pageUp
  if step2.state.actualRow != 0 then
    throw (IO.userError "PageUp on empty selected day should keep row 0")

  let step3 := Loam.Tui.SelectedDay.update emptySnapshot initial .home
  if step3.state.actualRow != 0 then
    throw (IO.userError "Home on empty selected day should keep row 0")

  let step4 := Loam.Tui.SelectedDay.update emptySnapshot initial .«end»
  if step4.state.actualRow != 0 then
    throw (IO.userError "End on empty selected day should keep row 0")

def main : IO Unit := do
  testCsiDecoding
  testActualWorkspaceNavigation
  testSelectedDayNavigation
  IO.println "Terminal navigation keys and decoding tests passed."
