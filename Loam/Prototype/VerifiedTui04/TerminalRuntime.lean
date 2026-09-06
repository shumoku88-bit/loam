import Loam.Prototype.VerifiedTui04.Main
import Loam.Prototype.VerifiedTui04.Runtime

namespace Loam.Prototype.VerifiedTui04.TerminalRuntime

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Runtime

set_option autoImplicit false

/--
Lower one semantic dirty-row comparison to terminal output by positioning once at
the start of each changed row and then letting the terminal advance glyphs.

This is deliberately only terminal mechanics. Widget meaning, damage discovery,
and the reconstruction proof remain in the pure Kernel / Runtime layers.
-/
def emitDirtyDiff (bounds : Bounds) (top left : Nat)
    (old new : CompiledWidget) : IO Unit := do
  let mut output := ""
  for row in dirtyRows bounds top old new do
    output := output ++ Loam.Prototype.VerifiedTui04.Main.cursorTo row.val left
    match new.rowAt top row.val with
    | none => pure ()
    | some cells =>
        for cell in cells do
          output := output ++
            Loam.Prototype.VerifiedTui04.Main.ansiStyle cell.style ++
            toString cell.glyph
    output := output ++ "\x1b[0m\x1b[K"
  IO.print output
  (← IO.getStdout).flush

end Loam.Prototype.VerifiedTui04.TerminalRuntime
