import Lean
open Lean

-- Qualification inventory only; serialization/replay stays in the official tools.
def main : IO Unit := do
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := `Loam.DurableProofs }] {}
  let modules := env.allImportedModuleNames
  IO.println <| Json.compress <| Json.mkObj [
    ("modules", toJson (modules.filter ((`Loam).isPrefixOf ·) |>.qsort Name.lt |>.map Name.toString))]
  for (name, info) in env.constants.toList.mergeSort (fun a b => Name.lt a.1 b.1) do
    if let some idx := env.getModuleIdxFor? name then
      let owner := modules[idx.toNat]!
      if (`Loam).isPrefixOf owner then
        IO.println <| Json.compress <| Json.mkObj [
          ("name", toJson name.toString), ("owner", toJson owner.toString),
          ("theorem", toJson info.isTheorem), ("unsafe", toJson info.isUnsafe),
          ("partial", toJson info.isPartial)]
