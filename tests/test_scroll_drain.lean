import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.SettlementWorkspace

open Loam.Tui.Terminal

def makeBytes (s : String) : ByteArray :=
  s.toUTF8

def testParseSingleWheelDown : IO Unit := do
  let packet := "\x1b[<65;15;25M"
  let bytes := makeBytes packet
  match parseSgrMousePacket? bytes 0 with
  | some (btn, nextPos) =>
      if btn != 65 then throw (IO.userError s!"Expected button 65, got {btn}")
      if nextPos != bytes.size then throw (IO.userError s!"Expected nextPos {bytes.size}, got {nextPos}")
  | none => throw (IO.userError "Failed to parse SGR mouse packet")

def testParseSingleWheelUp : IO Unit := do
  let packet := "\x1b[<64;1;1M"
  let bytes := makeBytes packet
  match parseSgrMousePacket? bytes 0 with
  | some (btn, nextPos) =>
      if btn != 64 then throw (IO.userError s!"Expected button 64, got {btn}")
      if nextPos != bytes.size then throw (IO.userError s!"Expected nextPos {bytes.size}, got {nextPos}")
  | none => throw (IO.userError "Failed to parse SGR mouse packet")

def testDrainConsecutiveWheel : IO Unit := do
  -- 4 consecutive wheel down packets
  let packet := "\x1b[<65;10;10M\x1b[<65;10;10M\x1b[<65;10;10M\x1b[<65;10;10M"
  let bytes := makeBytes packet
  let (newPos, count) := drainMatchingWheel bytes 0 65
  if count != 4 then throw (IO.userError s!"Expected count 4, got {count}")
  if newPos != bytes.size then throw (IO.userError s!"Expected newPos {bytes.size}, got {newPos}")

def testDrainStopsOnDifferentKey : IO Unit := do
  -- 2 wheel down packets, followed by a 'q'
  let packet := "\x1b[<65;10;10M\x1b[<65;10;10Mq"
  let bytes := makeBytes packet
  let (newPos, count) := drainMatchingWheel bytes 0 65
  if count != 2 then throw (IO.userError s!"Expected count 2, got {count}")
  if newPos != bytes.size - 1 then throw (IO.userError s!"Expected newPos {bytes.size - 1}, got {newPos}")
  if bytes.get! newPos != 113 then throw (IO.userError "Expected remaining byte to be 'q'")

def testDrainStopsOnDifferentDirection : IO Unit := do
  -- 2 wheel down packets, followed by 1 wheel up
  let packet := "\x1b[<65;10;10M\x1b[<65;10;10M\x1b[<64;10;10M"
  let bytes := makeBytes packet
  let (newPos, count) := drainMatchingWheel bytes 0 65
  if count != 2 then throw (IO.userError s!"Expected count 2, got {count}")
  let (nextPos, nextCount) := drainMatchingWheel bytes newPos 64
  if nextCount != 1 then throw (IO.userError s!"Expected nextCount 1, got {nextCount}")
  if nextPos != bytes.size then throw (IO.userError s!"Expected nextPos {bytes.size}, got {nextPos}")

def testReadKeyAndDrainPendingWheel : IO Unit := do
  resetInputBuffer
  let packet := "\x1b[<65;10;10M\x1b[<65;10;10M\x1b[<65;10;10M\x1b[<65;10;10M"
  inputBufferRef.set { data := makeBytes packet, pos := 0 }
  let key ← readKey
  if key != Key.down then throw (IO.userError s!"Expected Key.down, got {repr key}")
  let extra ← drainPendingWheel key
  if extra != 3 then throw (IO.userError s!"Expected extra 3, got {extra}")
  let state ← inputBufferRef.get
  if state.pos != state.data.size then throw (IO.userError "Expected inputBuffer to be fully consumed")

def testReadKeyWithRepeat : IO Unit := do
  resetInputBuffer
  let packet := "\x1b[<64;10;10M\x1b[<64;10;10M\x1b[<64;10;10M"
  inputBufferRef.set { data := makeBytes packet, pos := 0 }
  let (key, count) ← readKeyWithRepeat
  if key != Key.up then throw (IO.userError s!"Expected Key.up, got {repr key}")
  if count != 3 then throw (IO.userError s!"Expected count 3, got {count}")
  let state ← inputBufferRef.get
  if state.pos != state.data.size then throw (IO.userError "Expected inputBuffer to be fully consumed")

def testSettlementRepeat : IO Unit := do
  let makeRow (i : Nat) : Loam.SettlementReview.Row := {
    id := ⟨s!"row-{i}"⟩
    label := some s!"Row {i}"
    sourceEvent := ⟨"evt"⟩
    sourceEffect := ⟨"eff"⟩
    debtor := .household
    creditor := .external ⟨"issuer"⟩
    measure := ⟨"jpy"⟩
    committed := Loam.Core.Quantity.ofQuanta 1000
    settled := Loam.Core.Quantity.ofQuanta 0
    outstanding := Loam.Core.Quantity.ofQuanta 1000
    direct := []
    netting := []
    extinguished := Loam.Core.Quantity.ofQuanta 0
    extinguishments := []
  }
  let rows := (List.range 20).map makeRow
  let snapshot : Loam.SettlementReview.Snapshot := { rows := rows }
  let initial := Loam.Tui.SettlementWorkspace.initial snapshot
  if initial.row != 0 then throw (IO.userError "Expected initial row 0")

  -- Scroll down with repeat count 5
  let step5 := Loam.Tui.SettlementWorkspace.updateWithRepeat initial .next 5
  if step5.state.row != 5 then throw (IO.userError s!"Expected row 5, got {step5.state.row}")

  -- Scroll down with repeat count 100 (should clamp at 19)
  let stepClamped := Loam.Tui.SettlementWorkspace.updateWithRepeat step5.state .next 100
  if stepClamped.state.row != 19 then throw (IO.userError s!"Expected clamped row 19, got {stepClamped.state.row}")

  -- Scroll up with repeat count 8 (19 - 8 = 11)
  let stepUp := Loam.Tui.SettlementWorkspace.updateWithRepeat stepClamped.state .previous 8
  if stepUp.state.row != 11 then throw (IO.userError s!"Expected row 11, got {stepUp.state.row}")

  -- Scroll up with repeat count 50 (should clamp at 0)
  let stepTop := Loam.Tui.SettlementWorkspace.updateWithRepeat stepUp.state .previous 50
  if stepTop.state.row != 0 then throw (IO.userError s!"Expected clamped row 0, got {stepTop.state.row}")

def main : IO Unit := do
  testParseSingleWheelDown
  testParseSingleWheelUp
  testDrainConsecutiveWheel
  testDrainStopsOnDifferentKey
  testDrainStopsOnDifferentDirection
  testReadKeyAndDrainPendingWheel
  testReadKeyWithRepeat
  testSettlementRepeat
  IO.println "All scroll drain unit tests passed."
