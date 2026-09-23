import Loam.Tui.Cli

/-- Compatibility executable entry for the standalone production TUI target. -/
def main (args : List String) : IO UInt32 :=
  Loam.Tui.Cli.run args
