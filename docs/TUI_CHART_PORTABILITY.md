# Portable TUI chart boundary

LOAM's chart presentation targets ordinary modern text terminals without making
household semantics depend on one terminal emulator.

## Required terminal contract

The primary chart path uses only:

- ordinary UTF-8 text cells;
- single-column Braille / block / ASCII glyphs;
- ANSI styling already used by the rest of the TUI;
- SGR mouse coordinates already normalized by `Loam.Tui.Terminal`;
- terminal width/height reported by the existing tty geometry boundary.

It deliberately does **not** require:

- kitty graphics;
- iTerm2 inline images;
- sixel;
- terminal-specific JavaScript or RPC;
- emulator-name branching.

The initial portability targets are iTerm2, WezTerm, and Ghostty. The code should
remain useful in other xterm-compatible terminals when the same small contract
is available.

## Renderer fallback

The logical series, selection index, pointer hit-testing, and crosshair are
independent of glyph choice.

```text
braille -> block -> ascii -> braille
```

Braille is the default because one terminal cell can represent a 2×4 subpixel
grid. If a font or terminal renders Braille poorly, the user can switch the
Trend surface with `r` without changing the selected data point or report
answer.

Block and ASCII are not separate accounting views. They are presentation
fallbacks for the same values.

## Pointer contract

The terminal boundary preserves explicit pointer presses and pointer motion as
different normalized inputs.

Single-Locus Trend enables all-pointer-motion reporting while that surface is
active, so keyboard Left/Right, click, and hover can converge on the same
selection state.

Trend Compare deliberately keeps ordinary button reporting only. A click selects
the nearest visible period, but later mouse movement does not move the shared
comparison cursor. Dragging is never required.

## Resize contract

Reports re-read terminal geometry after the next keyboard input. Pointer-motion
events deliberately do not spawn a tty-size subprocess, so hover remains a cheap
pure selection path. When keyboard interaction observes changed geometry, the
current report is re-rendered from a blank frame using the new bounds. No
household data is reclassified or mutated.

The chart renderer itself is a pure width/height projection and is qualified at
multiple geometries.

## Qualification boundary

CI can qualify deterministic properties such as:

- each chart renderer preserves requested terminal width and height;
- Braille, block, crosshair, and ASCII chart glyphs occupy one LOAM terminal
  column under the shared width model;
- pointer hit-testing is renderer-independent;
- renderer fallback preserves the logical series;
- narrow and wide geometry reflow without changing report semantics;
- SGR pointer packets normalize to the same zero-based coordinate type.

CI does **not** prove that a user's chosen font draws every Unicode glyph
beautifully in every emulator. Manual visual checks remain useful on iTerm2,
WezTerm, and Ghostty. A terminal-specific workaround should be added only when
the generic fallback cannot solve a demonstrated problem.
