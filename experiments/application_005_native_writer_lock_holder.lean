import Std

namespace Loam.Experiments.Application005.Holder

set_option autoImplicit false

private def lockPath : System.FilePath :=
  System.FilePath.mk "application-005-writer.lock"

private def readyPath : System.FilePath :=
  System.FilePath.mk "application-005-holder-ready"

def run : IO UInt32 := do
  let handle ← IO.FS.Handle.mk lockPath .readWrite
  IO.FS.Handle.lock handle
  IO.FS.writeFile readyPath "locked\n"
  -- The qualification harness kills this process while the kernel-managed lock
  -- is still held. If the process is not killed, bound the experiment anyway.
  IO.sleep 60000
  IO.FS.Handle.unlock handle
  return 0

end Loam.Experiments.Application005.Holder

def main : IO UInt32 :=
  Loam.Experiments.Application005.Holder.run
