import Loam.BoundaryPresetConfig

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def expectNone {α : Type} (value : Option α) (message : String) : IO Unit := do
  match value with
  | none => pure ()
  | some _ => throw (IO.userError message)

private def expectWindow
    (preset : Loam.BoundaryPresetConfig.Preset)
    (selected start endExclusive : String) : IO Unit := do
  match Loam.BoundaryPresetConfig.windowForDate? preset selected with
  | some actual =>
      expect (actual == (start, endExclusive))
        ("unexpected preset window for " ++ selected)
  | none => throw (IO.userError ("preset window was unavailable for " ++ selected))

def main : IO Unit := do
  let valid :=
    "Pension\t2026-08-15\t2026-10-15\n" ++
    "Salary\t2026-08-25\t2026-09-25\t2026-10-25\n"
  let presets ←
    match Loam.BoundaryPresetConfig.decode? valid with
    | some presets => pure presets
    | none => throw (IO.userError "valid boundary presets did not decode")
  expect (presets.length == 2) "valid boundary preset count changed"

  let pension ←
    match presets.find? (fun preset => preset.name == "Pension") with
    | some preset => pure preset
    | none => throw (IO.userError "Pension preset was not retained")
  expectWindow pension "2026-09-08" "2026-08-15" "2026-10-15"
  expectWindow pension "2026-08-15" "2026-08-15" "2026-10-15"
  expectNone (Loam.BoundaryPresetConfig.windowForDate? pension "2026-10-15")
    "preset invented a later boundary after its explicit evidence ended"
  expectNone (Loam.BoundaryPresetConfig.windowForDate? pension "2026-08-14")
    "preset invented an earlier boundary before its explicit evidence began"

  expectNone
    (Loam.BoundaryPresetConfig.decode? "Pension\t2026-08-15\n")
    "single-boundary preset was accepted"
  expectNone
    (Loam.BoundaryPresetConfig.decode? "Pension\t2026-02-30\t2026-10-15\n")
    "non-calendar boundary date was accepted"
  expectNone
    (Loam.BoundaryPresetConfig.decode? "Pension\t2026-10-15\t2026-08-15\n")
    "descending preset boundaries were accepted"
  expectNone
    (Loam.BoundaryPresetConfig.decode?
      "Pension\t2026-08-15\t2026-10-15\nPension\t2026-10-15\t2026-12-15\n")
    "duplicate preset names were accepted"

  let tmp := System.FilePath.mk "/tmp/loam-boundary-preset-missing.tsv"
  if ← tmp.pathExists then IO.FS.removeFile tmp
  match ← Loam.BoundaryPresetConfig.load? tmp with
  | some [] => pure ()
  | _ => throw (IO.userError "missing preset file did not mean no configured presets")

  IO.println "BoundaryPresetConfig: strict decode, explicit adjacency, and no recurrence passed."
