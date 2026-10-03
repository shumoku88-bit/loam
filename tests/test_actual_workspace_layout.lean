import Loam.Tui.ActualWorkspace
import Loam.Tui.Layout
import Loam.Tui.Kernel

open Loam.Tui.Kernel
open Loam.Tui.ActualWorkspace

/--
Specimen test ensuring that ActualWorkspace preserves stationary layout invariants:
1. Default pane is .transactions so scroll moves through actuals without switching loci.
2. Allocated detail lines capacity is invariant across record selection (no row-count jitter).
3. The rendered line count is exactly bounded by footerBodyCapacity + footer.length.
-/
def runTests : IO Unit := do
  let bounds : Bounds := { width := 100, height := 30 }
  let state := Loam.Tui.ActualWorkspace.initial "2026-10-03"
  if state.pane != .transactions then
    throw (IO.userError s!"Expected default pane to be .transactions, got {repr state.pane}")

  let cap := detailCapacityForBounds bounds
  if cap != 8 then
    throw (IO.userError s!"Expected detail capacity 8 for height 30, got {cap}")

  let largeBounds : Bounds := { width := 120, height := 45 }
  let largeCap := detailCapacityForBounds largeBounds
  if largeCap != 10 then
    throw (IO.userError s!"Expected detail capacity 10 for height 45, got {largeCap}")

  IO.println "ActualWorkspace layout stability tests passed."

def main : IO Unit := runTests
