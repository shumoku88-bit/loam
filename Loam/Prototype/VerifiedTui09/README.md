# LOAM UI Prototype 09

Prototype 09 pressure-tests one result from the HRA interaction atlas without
turning that result into production architecture.

```text
Home / Calendar
  -> Actual workspace
       browse <-> detail
```

Unlike Prototype 07, browse and detail are not independent top-level surfaces.
They are local modes of one Actual workspace.

## Question

Does the HRA-derived Home/workspace composition preserve the useful orientation
of Prototype 07 while deleting one top-level surface?

This experiment changes interaction state only. It deliberately reuses the
verified widget and sparse row-damage runtime already exercised by the preceding
prototypes.

## Orientation rules

- Left/Right moves one Home calendar day.
- Up/Down moves one Home calendar week.
- Enter on Home opens the Actual workspace for the selected day.
- Actual/Browse Up/Down selects a record.
- Enter changes the same Actual workspace to Detail mode.
- `b` from Detail returns to Browse with the exact same cursor.
- `b` from Browse returns Home on the same calendar day and caches the cursor.
- Re-entering that same day restores the cached row selection.
- Moving the Home day discards the old day cursor.
- `q` quits.

The Lean state has only two top-level `Surface` constructors:

```text
home
actual(cursor, browse | detail)
```

The local mode distinction is presentation orientation only. It is not canonical
household evidence.

## Qualified laws in this specimen

The implementation checks:

- selected calendar day remains bounded;
- selected Actual row is structurally bounded by the displayed projection;
- Enter and Back preserve the selected day;
- Detail -> Back stays in Actual and preserves the exact cursor;
- Browse -> Back returns Home while preserving that cursor as local cache;
- Browse -> Detail preserves the exact cursor;
- update remains deterministic as a pure function;
- the existing compiled sparse frame still equals the semantic screen.

These are local interaction and rendering laws. They do not prove UX quality.

## Authority path

The canonical read path is unchanged from Prototype 07:

```text
selected Movement manifest
  -> typed loadSelectedWorld?
  -> correction / ActualValidity admission
  -> ActualReview.Record
  -> selected-day projection
  -> TUI
```

There are no writes and no retired sidecar fallback.

## Deliberate omissions

- no writer entrance;
- no Scheduled workspace yet;
- no Issue workspace;
- no Report workspace;
- no generic router or command palette;
- no generic scrolling framework;
- no mouse;
- no new TUI-kernel abstraction.

The next question is human: does `Home -> Actual workspace` feel clearer than the
Prototype 07 `Calendar -> List -> Detail` top-level split?

## Run

From the LOAM repository root with the canonical sibling checkout updated:

```sh
lake build loamUiPrototype09
./.lake/build/bin/loamUiPrototype09
```

An explicit data directory can be supplied as the only argument.
