# LOAM UI Prototype 07

Prototype 07 composes the two interaction shapes that survived separate pressure:

```text
Calendar
  -> selected-day canonical Actual list
  -> Actual detail
```

It is still a read-only interaction experiment, not the production TUI.

## What this pressure asks

Prototype 04 qualified a responsive month-grid interaction kernel. Prototype 05
showed the same sparse runtime could support a differently shaped list/detail
surface. Prototype 06 connected that list/detail surface to the real fail-closed
Actual review projection and survived canonical Unicode dogfood.

Prototype 07 asks whether those pieces form one coherent LOAM interaction without
inventing a navigation framework or another accounting authority.

## Orientation rules

- Left/Right moves one calendar day.
- Up/Down moves one calendar week.
- Enter on Calendar opens current Actual records for the selected day.
- Up/Down selects a record in the day list.
- Enter opens detail.
- `b` from detail returns to the same row.
- `b` from the day list returns to the same calendar day.
- Re-entering that same day restores the cached row selection.
- Moving the calendar day discards the old day-list cache.
- `q` quits.

The cached list cursor is presentation state only. It is never persisted and has
no writer authority.

## Authority path

```text
selected Movement manifest
  -> typed loadSelectedWorld?
  -> correction / ActualValidity admission
  -> ActualReview.Record
  -> day projection
  -> TUI
```

There is no retired sidecar fallback on the canonical path and no CLI-output
parsing.

## Deliberate omissions

- no writes;
- no Scheduled surface;
- no generic router;
- no scrolling framework;
- no search box;
- no mouse;
- no complete wcwidth / grapheme layout model.

A day page remains bounded to ten records, matching the preceding review
specimen. Further machinery must be earned by dogfood rather than added in
advance.

## Run

From the LOAM repository root with the canonical sibling checkout updated:

```sh
lake build loamUiPrototype07
./.lake/build/bin/loamUiPrototype07
```

An explicit data directory can be supplied as the only argument.
