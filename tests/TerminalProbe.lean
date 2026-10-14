import Loam.Tui.Terminal
import Loam.Tui.ModalSurface

open Loam.Tui.Kernel Loam.Tui.Runtime Loam.Tui.Terminal

private def line (text : String) : Widget := .row [span text]

private def frameFor (bounds : Bounds) : CompiledWidget :=
  compileWidget <| .column <|
    [line s!"geometry {bounds.width}x{bounds.height}"] ++
    List.replicate (bounds.height - 2) (line "日本語 body") ++
    [line "footer [q] back"]

private def regionFrame : CompiledWidget :=
  compileWidget <| .column [line "a日本", line "日本語", line "unseen"]

private def blankFrame : CompiledWidget :=
  compileWidget (.row [])

private def expect (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw (IO.userError message)

/-- Pure boundary specimens complement live ioctl/ANSI checks in the PTY driver. -/
private def checkRegionBounds : IO Unit := do
  let bounds : Bounds := { width := 32, height := 9 }
  for (top, left, width) in
      [(0, 40, 20), (0, 31, 20), (0, 32, 20), (0, 0, 0),
       (9, 0, 20), (40, 0, 20)] do
    expect (dirtyRegionAnsi bounds top left width blankFrame regionFrame == "")
      s!"offscreen or zero-width region emitted ANSI: {top}/{left}/{width}"
  for bounds in
      [{ width := 0, height := 9 : Bounds }, { width := 32, height := 0 }] do
    expect (dirtyRegionAnsi bounds 0 0 20 blankFrame regionFrame == "")
      "zero-sized terminal region emitted ANSI"
    expect (directFrameAnsi bounds (.row [span "text"]) == "")
      "zero-sized direct frame emitted ANSI"
  expect
    (dirtyRegionAnsi bounds 7 27 20 blankFrame regionFrame ==
      "\x1b[8;28H\x1b[0ma日\x1b[0m " ++
      "\x1b[9;28H\x1b[0m日本\x1b[0m")
    "partially clipped region changed origin, CJK clipping, padding, or height"
  expect
    (dirtyRegionAnsi bounds 8 27 2 blankFrame regionFrame ==
      "\x1b[9;28H\x1b[0ma\x1b[0m ")
    "region's own width did not bound CJK clipping and padding"
  expect
    (dirtyRegionAnsi bounds 8 27 20 regionFrame blankFrame ==
      "\x1b[9;28H\x1b[0m    ")
    "shortened region did not erase exactly its visible width"
  expect (dirtyRegionAnsi bounds 7 27 20 regionFrame regionFrame == "")
    "unchanged region emitted ANSI"
  expect
    (dirtyRegionAnsi { width := 1, height := 1 } 0 0 1 blankFrame
      (compileWidget (line "ab")) == "\x1b[1;1H\x1b[0ma\x1b[0m")
    "one-column terminal lost its existing clipping convention"

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
  | "regions" =>
      let _ ← readKey
      checkRegionBounds
      IO.print "regions-ok"
  | "output-bounds" =>
      let _ ← readKey
      let active ← currentBounds
      -- Origins are stale/offscreen even though the supplied bounds are larger.
      emitDirtyRegion bounds 0 (active.width + 8) 20 blankFrame regionFrame
      emitDirtyRegion bounds active.height 0 20 blankFrame regionFrame
      emitDirtyRegion bounds 0 0 0 blankFrame regionFrame
      emitDirtyRegion { width := 0, height := bounds.height }
        0 0 20 blankFrame regionFrame
      emitDirtyDiff bounds 0 (active.width + 8) blankFrame regionFrame
      emitDirtyDiff bounds active.height 0 blankFrame regionFrame
      emitDirtyDiff { width := 0, height := bounds.height }
        0 0 blankFrame regionFrame
      IO.print "offscreen-done"
      emitDirtyRegion bounds (active.height - 2) (active.width - 5)
        20 blankFrame regionFrame
      IO.print "region-done"
      emitDirtyDiff bounds (active.height - 2) (active.width - 5)
        blankFrame regionFrame
  | "cursor" =>
      let _ ← readKey
      emitDirtyDiff bounds 0 0 blankFrame (frameFor bounds)
      IO.print "painted"
      (← IO.getStdout).flush
      -- The PTY driver shrinks the tty only after observing the completed paint.
      let _ ← readKey
      placeCursor (bounds.height - 1) (bounds.width - 1)
  | "text-caret" =>
      let _ ← readKey
      let selected := compileWidget (.row [span "日本" .selected, span " "])
      let region : Loam.Tui.ModalSurface.Rectangle :=
        { top := 2, left := 3, width := 20, height := 4 }
      try
        Loam.Tui.ModalSurface.withTextCaret do
          Loam.Tui.ModalSurface.placeTextCaret bounds (some region) true selected
          throw (IO.userError "synthetic editor failure")
      catch _ => IO.print "caught"
      -- The pane moved outside the live tty: hide instead of snapping to parent.
      Loam.Tui.ModalSurface.placeTextCaret bounds
        (some { region with left := bounds.width + 4 }) true selected
  | _ => throw (IO.userError "unknown terminal probe mode")
