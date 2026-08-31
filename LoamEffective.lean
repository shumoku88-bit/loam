import Loam.EffectiveCli


def main (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath, correctionPath] =>
      Loam.EffectiveCli.showEffectiveQuantities memoryPath correctionPath
  | _ => do
      IO.eprintln "usage: loam-effective MEMORY_FILE CORRECTION_FILE"
      return 2
