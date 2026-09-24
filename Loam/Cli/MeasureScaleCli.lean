import Loam.HouseholdCommand

namespace Loam.MeasureScaleCli

set_option autoImplicit false

private def usage : String :=
  "usage: loam measure-scale DATA_ROOT MEASURE SCALE"

def run (args : List String) : IO UInt32 := do
  match args with
  | [rootText, measureToken, scaleText] =>
      if rootText.isEmpty then
        IO.eprintln "loam: data directory must not be empty"
        return 2
      let some scale := scaleText.toNat?
        | IO.eprintln "loam: Measure presentation scale must be an integer between 0 and 9"
          return 2
      match ←
          Loam.HouseholdCommand.setMeasureScale
            (System.FilePath.mk rootText) ⟨measureToken⟩ scale with
      | .ok () =>
          IO.println
            ("Measure presentation scale accepted: " ++ measureToken ++
              " -> " ++ toString scale)
          return 0
      | .error message =>
          IO.eprintln message
          return 2
  | _ =>
      IO.eprintln usage
      return 2

end Loam.MeasureScaleCli
