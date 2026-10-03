import Loam.Tui.Terminal

/-- PTY driver: no household data, no terminal-mode or geometry subprocesses. -/
def main : IO Unit := do
  IO.println "ready"
  (← IO.getStdout).flush
  for _ in List.range 5 do
    let key ← Loam.Tui.Terminal.readKey
    IO.println s!"key:{repr key}"
    (← IO.getStdout).flush
