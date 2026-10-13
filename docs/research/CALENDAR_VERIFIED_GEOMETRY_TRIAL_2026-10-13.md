# Calendar geometry: bounded proportions and verifiable whitespace (trial)

Status: **research prototype only**, 2026-10-13. No Home renderer/behavior change.
Works alongside [Week Home trial](WEEK_HOME_DESIGN_TRIAL_2026-10-12.md) and
[Home evolution #1861](https://github.com/shumoku88-bit/loam/issues/1861).

## The question

A wide terminal should not automatically stretch seven day cells into long
rectangles. A narrow terminal should not force illegible day labels or cut
amounts. Whitespace can be deliberate rather than treated as unused capacity.

## Evidence versus hypothesis

- Seven equal day columns and symmetric margins create predictable alignment:
  verifiable arithmetic rather than a claim about perception.
- [Constraint-based breakpoints (Schöttler et al., 2024)](https://arxiv.org/abs/2409.01339)
  motivate mode changes based on minimum readable element size, not merely
  the entire terminal width.
- The visually preferred rectangle proportion is **context-sensitive**.
  [Russell (2000)](https://pubmed.ncbi.nlm.nih.gov/11257965/) found no
  universal golden-section preference across the evaluated contexts;
  [McManus (1980)](https://pubmed.ncbi.nlm.nih.gov/7437674/) discusses
  stable individual differences. Treat 1:1, 3:2, and ~1.618:1 as *candidates
  to compare*, never as mathematical aesthetic truth.
- Terminal columns and rows are not square pixels. Glyph physical dimensions,
  Unicode width and line spacing affect perceived shape. Measure or configure
  those separately from the proof model.

## Geometry

For 7 day columns of width `c`, separated by a `g`-column gap:

```text
grid = 7c + 6g
spare = available - grid
left = floor(spare / 2)
right = spare - left
```

Only enter this mode when `available >= 7*minimum + 6*g` and `minimum <= maximum`.
Choose `c = min(maximum, floor((available - 6*g)/7))`.
Otherwise choose a *different* compact presentation, never a below-minimum
rendering disguised as a valid spacious grid.

The experimental Lean module `Loam/Tui/CalendarGeometry.lean` proves:

1. occupied grid + margins = available for a fitting grid;
2. left and right margins differ by at most one column;
3. the chosen seven-column width respects min/max and fits;
4. no larger width under the same cap can fit;
5. zero integer cross-product aspect penalty at an exactly matched ratio.

These theorems **do not** establish the optimal appearance, terminal pixel
geometry, actual screen integration, or complete application correctness.

## Two independent decisions

**Week strip**: test compact `min=8, max=12, gap=1` and a two-row
day/status cell. A narrower pane should use a different strip or vertical
list; don't shrink full labels below their readable width.

**Month money grid**: test `min=10..12, max=14, gap=1`, accounting for
frame/border columns separately. Preserve distinct date, positive amount,
negative amount, selected day, unknown/partial/Scheduled evidence.

The existing `Calendar.gridSlots` always returns six stable rows. Evaluate
two alternatives *before* any behavior change: (A) six-row stability;
(B) draw only the required 4–6 actual weeks but retain the overall panel
footprint by using neutral whitespace. Do not disturb selected-date focus.

**Panel split**: measure equal, 3:2, and ~golden-ratio candidate splits
*after* honoring minimum readable widths. A grid that reaches its max width
should remain bounded, with any spare width allotted to symmetric outside
margins or genuinely useful detail, not inflated calendar cells.

## Prototype review matrix

Compare terminal sizes `32x9, 48x14, 80x24, 119x20, 120x30, 150x45`,
including narrower individually resized panes. Review (a) Month and Week,
(b) 4/5/6-week months and year boundary, (c) today's selection, (d) short
and huge amount strings, (e) CJK labels, and (f) unknown/unavailable evidence.

Keep a screenshot matrix of 1:1, 3:2, golden candidate panel ratios and
alternate day-cell density at identical font size. Record subjective ratings
and task success (recognize selected day, income/outgo, unknown state)
separately. Reject any visually attractive option which misrepresents money
or creates clipping.

## Integration boundary

1. First verify proofs in CI and measure screenshots. The geometry module
   is intentionally not called by `Home` yet.
2. Keep the renderer's factual accounting and calendar projection untouched.
3. When a winner emerges, have Home *consume* the geometry output behind
   the existing responsive selection, with focused PTY resize tests.
4. Remove the unused alternatives after the trial so research does not become
   permanent product complexity.
