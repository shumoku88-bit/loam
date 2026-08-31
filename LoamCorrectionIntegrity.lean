import Loam.CorrectionIntegrityCli


def main (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath, correctionPath] =>
      Loam.CorrectionIntegrityCli.showCorrectionIntegrity memoryPath correctionPath
  | _ => do
      IO.eprintln "usage: loam-correction-integrity MEMORY_FILE CORRECTION_FILE"
      return 2
