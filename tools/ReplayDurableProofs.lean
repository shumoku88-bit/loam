import LeanChecker

open Lean

namespace DurableReplay

private def eligible (info : ConstantInfo) : Bool :=
  !info.isUnsafe && !info.isPartial

/-- Select compiled owners, reconcile private module data, then use stock Lean replay. -/
unsafe def run : IO Unit := do
  initSearchPath (← findSysroot)
  let start ← IO.monoMsNow
  IO.println s!"durable-replay: Lean {versionString} ({githash})"
  let env ← importModules #[{ module := `Loam.DurableProofs }] {}
  let imported := env.allImportedModuleNames
  let modules := imported.filter ((`Loam).isPrefixOf ·) |>.qsort Name.lt
  let expected := env.constants.toList.filterMap fun (name, info) => do
    let idx ← env.getModuleIdxFor? name
    if (`Loam).isPrefixOf imported[idx.toNat]! && eligible info then some name else none
  if expected.isEmpty then
    throw <| IO.userError "durable-replay: empty logical scope (import-only umbrella)"
  let mut scopes : Array (Name × Array (ModuleData × CompactedRegion)) := #[]
  let mut selected := #[]
  let mut theoremCount := 0
  let mut skippedUnsafe := 0
  let mut skippedPartial := 0
  for module in modules do
    let file ← findOLean module
    let mut files := #[file]
    let server := OLeanLevel.server.adjustFileName file
    if ← server.pathExists then
      files := files.push server
      let privateFile := OLeanLevel.private.adjustFileName file
      if ← privateFile.pathExists then files := files.push privateFile
    let parts ← readModuleDataParts files
    -- The most-private part subsumes the others, exactly as replayFromImports uses it.
    let some (data, _) := parts.back?
      | throw <| IO.userError s!"durable-replay: no module data for {module}"
    let logical := data.constants.filter eligible
    selected := selected ++ logical.map (·.name)
    theoremCount := theoremCount + (logical.filter (·.isTheorem)).size
    skippedUnsafe := skippedUnsafe + (data.constants.filter (·.isUnsafe)).size
    skippedPartial := skippedPartial + (data.constants.filter (·.isPartial)).size
    scopes := scopes.push (module, parts)
  if selected.toList.mergeSort Name.lt != expected.mergeSort Name.lt then
    throw <| IO.userError "durable-replay: scope mismatch between imported owners and selected private declarations"
  if theoremCount == 0 then throw <| IO.userError "durable-replay: scope contains no theorems"
  let replayStart ← IO.monoMsNow
  IO.println s!"durable-replay: selected {modules.size} defining modules, {selected.size} logical declarations, {theoremCount} theorem entries"
  for (module, parts) in scopes do
    let some (data, _) := parts.back?
      | throw <| IO.userError s!"durable-replay: no module data for {module}"
    let logical := data.constants.filter eligible
    let moduleStart ← IO.monoMsNow
    IO.println s!"durable-replay: checking module {module}"
    replayFromImports module
    IO.println s!"durable-replay: module {module}: logical={logical.size}, theorems={(logical.filter (·.isTheorem)).size}, replay_ms={(← IO.monoMsNow) - moduleStart}"
    for info in logical.qsort (fun a b => Name.lt a.name b.name) do
      IO.println s!"durable-replay: checked {module} {if info.isTheorem then "theorem" else "constant"} {info.name}"
  let stop ← IO.monoMsNow
  IO.println s!"durable-replay: ACCEPT modules={modules.size} logical={selected.size} theorems={theoremCount} skipped_unsafe={skippedUnsafe} skipped_partial={skippedPartial} scope_ms={replayStart - start} replay_ms={stop - replayStart} elapsed_ms={stop - start}"

end DurableReplay

#eval DurableReplay.run
