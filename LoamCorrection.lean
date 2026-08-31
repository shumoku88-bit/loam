import Loam.CorrectionCli


def main (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath, correctionPath] =>
      Loam.CorrectionCli.correctSpend memoryPath correctionPath
  | _ => do
      IO.eprintln "usage: loamCorrection MEMORY_FILE CORRECTION_FILE"
      return 2
