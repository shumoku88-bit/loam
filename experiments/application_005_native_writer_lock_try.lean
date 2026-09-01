import Std

namespace Loam.Experiments.Application005.Try

set_option autoImplicit false

private def lockPath : System.FilePath :=
  System.FilePath.mk "application-005-writer.lock"

def run : IO UInt32 := do
  let handle ← IO.FS.Handle.mk lockPath .readWrite
  let acquired ← IO.FS.Handle.tryLock handle
  IO.println ("exclusive_trylock_acquired=" ++ toString acquired)
  if acquired then
    IO.FS.Handle.unlock handle
  return 0

end Loam.Experiments.Application005.Try

def main : IO UInt32 :=
  Loam.Experiments.Application005.Try.run
