# LOAM UI Prototype 10

Prototype 10 keeps Prototype 09's interaction state unchanged and pressures only
Home presentation density.

```text
Home / Calendar
  -> selected-day Actual preview
  -> Enter opens the same Actual workspace from Prototype 09
```

The question is whether HRA's useful "move one date, see the household around that
date" interaction can return without adding another top-level surface, retained
UI state, or generic layout framework.

## Deliberate reuse

Prototype 10 imports Prototype 09's:

- `State` / `Surface` / `ActualMode`;
- pure `update`;
- day movement;
- day-local `ReviewCursor`;
- Actual browse/detail workspace;
- orientation-preservation laws.

It also retains the same canonical manifest-backed `ActualReview.Record` snapshot
and the same Prototype 04 sparse renderer.

No new canonical household fact is introduced.

## Dense Home

The 80x24 Home now uses two presentation regions directly, without introducing a
generic pane abstraction:

```text
monthly calendar    selected-day Actual preview
```

The preview shows at most five current Actual records. It is reconstructed on every
render from the same selected-day query used by `cursorForDay`; it is never cached
or persisted.

Arrow movement changes only the existing selected day. The preview therefore
follows that one temporal coordinate automatically.

## Checked local relationship

Lean compiles two small projection relationships:

```text
Home preview
  = take 5 (ActualReview.select allRecords (.day selectedDate))

Actual workspace total count
  = length of that same selected-day projection
```

These are intentionally projection laws, not a claim that visual layout quality is
formally proved.

## Deliberate omissions

- no Scheduled preview;
- no Issue preview;
- no Report workspace change;
- no new Home state;
- no generic pane / hcat / grid layout combinator;
- no scrolling framework;
- no writes;
- no complete wcwidth / grapheme-aware width model.

The right-hand preview uses conservative character clipping so ordinary canonical
Japanese rows fit the current specimen reasonably, but exact terminal display width
remains outside the proved kernel.

## Human gate

Move across several days with Left/Right and Up/Down and observe whether:

1. the right-side Actual evidence follows the selected day immediately;
2. the calendar remains easy to track while evidence changes;
3. Home now feels materially more informative without feeling more complicated;
4. Enter still opens the same day's Actual workspace;
5. Back returns to the same day;
6. responsiveness remains indistinguishable from Prototype 09 for ordinary use.

If this survives dogfood, Scheduled is the next distinct semantic-family projection
to pressure against the same selected-day coordinate.

## Run

```sh
lake build loamUiPrototype10
./.lake/build/bin/loamUiPrototype10
```
