import Loam.WriterOwnership
import Std

namespace Loam.Tests.WriterOwnershipHolder

set_option autoImplicit false

def run (args : List String) : IO UInt32 := do
  match args with
  | [anchorText, readyText] =>
      let anchor := System.FilePath.mk anchorText
      let ready := System.FilePath.mk readyText
      Loam.WriterOwnership.withOwnership anchor do
        IO.FS.writeFile ready "owned\n"
        IO.sleep 2000
        return 0
  | _ =>
      IO.eprintln "usage: holder <ownership-anchor-path> <ready-path>"
      return 2

end Loam.Tests.WriterOwnershipHolder

def main (args : List String) : IO UInt32 :=
  Loam.Tests.WriterOwnershipHolder.run args
