import Loam.Tui.Terminal

open Loam.Tui.Kernel Loam.Tui.Runtime Loam.Tui.Terminal

private def line (text : String) : Widget := .row [span text]

private def frameFor (bounds : Bounds) : CompiledWidget :=
  compileWidget <| .column <|
    [line s!"geometry {bounds.width}x{bounds.height}"] ++
    List.replicate (bounds.height - 2) (line "日本語 body") ++
    [line "footer [y] copy screen"]

/-- Compiled native-mechanics driver: no household data or publication path. -/
def main (args : List String) : IO Unit := do
  let bounds ← currentBounds
  IO.println "ready"
  (← IO.getStdout).flush
  match args.headD "keys" with
  | "keys" =>
      for _ in List.range 5 do
        let (key, count) ← readKeyWithRepeat
        IO.println s!"key:{repr key} count:{count}"
        (← IO.getStdout).flush
  | "wheel" =>
      for _ in List.range 4 do
        let (key, count) ← readKeyWithRepeat
        IO.println s!"key:{repr key} count:{count}"
        (← IO.getStdout).flush
  | "resize" =>
      let _ ← readKey
      let (active, frame) ← refreshFrame bounds (frameFor bounds) frameFor
      -- Also exercise clipping a stale large frame after a resize race.
      emitDirtyDiff bounds 0 0 (compileWidget (.row [])) (frameFor bounds)
      redrawFromBlank active frame
  | _ => throw (IO.userError "unknown terminal probe mode")
