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

The terminal boundary preserves explicit pointer presses, primary-button drag,
and passive pointer motion as different normalized inputs. Vertical wheel input
maps to Up/Down; horizontal wheel input maps to Left/Right.

Unified Trend uses button-motion reporting only. Click and primary-button
drag scrub the nearest visible period, and wheel motion moves one active period
at a time. Passive hover is inert, so the shared Trend cursor does not keep
following the mouse after release. One through five exact Locus series use the
same pointer contract.

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
