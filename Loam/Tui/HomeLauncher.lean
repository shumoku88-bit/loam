import Loam.Tui.Layout

namespace Loam.Tui.HomeLauncher

open Loam.Tui.Kernel
set_option autoImplicit false

/-! Opt-in, presentation-only start page. No household reads or derived totals. -/

private def spaces (n : Nat) : String := String.ofList (List.replicate n ' ')

/-- Hand-drawn, fixed bonsai: no generator, animation or runtime dependency. -/
private def bonsai : List String :=
  [ "               .:;;;:."
  , "          .:;;;;;::;;;;:."
  , "       .:;;;:. '\\|/ '::;'"
  , "   .:;;;;;;:..  |"
  , "    '::;;::'\\   /"
  , "            \\_/"
  , "            / \\"
  , "      .----/---\\----."
  , "       \\___________/"
  ]

/-- Only the leaf texture is green; branches stay normal and the pot muted. -/
private def bonsaiRow (width index : Nat) (line : String) : Widget :=
  let cells := (Loam.Tui.Layout.padRight width line).toList.map fun char =>
    let style := if index >= 7 then Style.muted
      else if char == ':' || char == ';' then Style.series4
      else Style.normal
    span (String.singleton char) style
  .row cells

private def entrances : List (String × String) :=
  [("r", "Record"), ("s", "Scheduled"), ("g", "Calendar"),
   ("a", "Actual"), ("b", "Balances"), ("d", "Daily Pace")]

private def centered (width : Nat) (row : Widget) : Widget :=
  let cells := row.lines.flatten
  let columns := cells.foldl (fun n cell => n + Loam.Tui.Layout.charWidth cell.glyph) 0
  .row ([span (spaces ((width - columns) / 2))] ++
    cells.map (fun cell => span (String.singleton cell.glyph) cell.style))

/-- Fixed footer and a bounded, optically raised central composition. Decoration
    disappears before entrances; no figures imply household completeness. -/
def view (bounds : Bounds) (focusDate notice : String) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let operations :=
    [ mutedLine (if width >= 48 then " [Enter] calendar   [i] attention" else " [Enter] calendar  [i] attention")
    , mutedLine (if width >= 48 then " [Space] commands   [q] quit" else " [Space] commands  [q] quit") ]
  let feedback := if notice.isEmpty then [blankLine] else
    (Loam.Tui.Layout.wrapColumns (width - 1) notice).map (fun line => plainLine (" " ++ line))
  let footer := Loam.Tui.Layout.boundFeedbackFooter bounds (feedback ++ operations)
  let capacity := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let treeWidth := bonsai.foldl (fun n line => max n (Loam.Tui.Layout.displayWidth line)) 0
  -- Reserve the whole tree, its blank/name rows, date spacing and six entrances.
  let art := width >= treeWidth && capacity >= bonsai.length + 11
  let roomy := capacity >= 13
  let heading := if art then
      bonsai.zipIdx.map (fun (line, index) => bonsaiRow treeWidth index line) ++
        [blankLine, plainLine "loam"]
    else [plainLine "loam"]
  let date := if roomy then [blankLine, mutedLine focusDate, blankLine] else [mutedLine focusDate]
  let menu := if capacity >= 8 then
      entrances.map fun (key, label) =>
        Widget.row [span "  ", span key .series1, span "   ", span (Loam.Tui.Layout.padRight 14 label)]
    else
      let compact := ["r Record     s Scheduled", "g Calendar   a Actual", "b Balances   d Daily Pace"]
      let columns := compact.foldl (fun n line => max n (Loam.Tui.Layout.displayWidth line)) 0
      compact.map (fun line => mutedLine (Loam.Tui.Layout.padRight columns line))
  let body := heading ++ date ++ menu
  let body := body.map (centered width)
  let top := (capacity - body.length) / 3
  .column ((Loam.Tui.Layout.fitWithFooter bounds (List.replicate top blankLine ++ body) footer).map
    (Loam.Tui.Layout.clipWidgetRow width))

end Loam.Tui.HomeLauncher
