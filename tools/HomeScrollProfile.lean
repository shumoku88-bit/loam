import Loam.Tui.Cli

/- Manual native phase probe for an immutable synthetic Household fixture.
Compile/link as documented in TUI_YEAR_SCROLL_2026-10-10.md; stdout is ANSI output.
Pure work is deferred through a thunk until after the clock starts. -/

open Loam.Tui.Kernel Loam.Tui.Main

private def requireOk {α : Type} : Except String α → IO α
  | .ok value => pure value
  | .error message => throw (IO.userError message)

private def phase {α : Type} (label : String) (action : Unit → IO α) : IO α := do
  let start ← IO.monoMsNow
  let value ← action ()
  IO.eprintln s!"{label}: {(← IO.monoMsNow) - start}ms"
  return value

private def navigate (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (layout : Option Loam.Tui.Home.DetailLayout) : Array State := Id.run do
  let mut states := #[]
  let mut state := state
  for _ in List.range 20 do
    state := (Loam.Tui.Home.navigationKey bounds snapshot state (.input 'j') 1 layout).getD state
    states := states.push state
  return states

def main (args : List String) : IO UInt32 := do
  let [root] := args | throw (IO.userError "expected an explicit synthetic fixture directory")
  let some today ← Loam.ActualDate.todayIso? | throw (IO.userError "date unavailable")
  let observed ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
  let snapshot ← requireOk (← Loam.Tui.Cli.loadSnapshotFromActualImage root today
    observed.image (some observed.generation))
  let bounds : Bounds := {width := 160, height := 48}
  let state : State := {selectedDate := today, zoomLevel := .year, activePane := .detail}
  let layout ← phase "prepare rows/positions/overview/pending" fun _ =>
    pure (Loam.Tui.Home.prepareDetail bounds snapshot state)
  IO.eprintln s!"selected-year records: {layout.records.size}; rows: {layout.rows.size}"
  let cold ← phase "20 navigation calls without reuse" fun _ =>
    pure (navigate bounds snapshot state none)
  let warm ← phase "20 navigation calls with reuse" fun _ =>
    pure (navigate bounds snapshot state (some layout))
  unless cold.map State.detailScroll == warm.map State.detailScroll do
    throw (IO.userError "projection changed viewport geometry")
  let frames ← phase "20 bounded Home frames with reuse" fun _ =>
    pure (warm.map fun next => Loam.Tui.Cli.compiledFrameFor bounds snapshot next (some layout))
  let initial := Loam.Tui.Cli.compiledFrameFor bounds snapshot state (some layout)
  phase "20 dirty diff/output calls (redirected stdout, not PTY latency)" fun _ => do
    let mut previous := initial
    for frame in frames do
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 previous frame
      previous := frame
  IO.eprintln s!"final cursor: {(warm.back?).map State.detailCursor}"
  return 0
