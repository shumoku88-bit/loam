# LOAM UI Prototype 12

Prototype 12 starts from Prototype 11's surviving result:

```text
SelectedDay
  +-- Actual evidence
  +-- open-world Scheduled evidence
```

Prototype 11 showed that two distinct evidence families can share one temporal
coordinate on Home without being collapsed into one semantic type.

Prototype 12 pressures the next independent question:

> Does Scheduled earn a dedicated read-only workspace under that same SelectedDay,
> and if so, how much interaction structure must actually be shared with Actual?

## Smallest new interaction

Prototype 12 deliberately avoids adding a Home target/focus state just to run this
experiment.

```text
Enter      existing Actual workspace
Tab        provisional Scheduled workspace shortcut
```

`Tab` is experiment plumbing, not a proposed final navigation design.

Actual still uses the already-qualified Prototype 09/10/11 Browse / Detail state
and update path unchanged.

Scheduled adds one read-only workspace surface. It deliberately does **not** copy
Actual's cursor, browse/detail mode, or row-selection machinery yet. That omission
is part of the experiment: if real Scheduled use demands those mechanics, the
pressure should become visible before they are abstracted.

## Scheduled workspace semantics

The workspace consumes exactly the same open-world selected-day answer that Home
already displays:

```text
Application.currentScheduledDayEvidenceWithReplacement(..., SelectedDay)
```

So:

- explicit current-open occurrence(s) -> `Due` plus retained evidence;
- no explicit current-open occurrence -> `Unknown`;
- `Unknown` is not `NotDue`;
- no recurrence, cadence, series, completeness horizon, or future materialization
  is inferred.

A `Due` workspace shows the explicit retained occurrences for that date.

An `Unknown` workspace explains the open-world meaning directly instead of
fabricating an empty scheduled collection.

## State boundary

Prototype 12 wraps Prototype 11 state rather than replacing it.

```text
Surface
  +-- base Prototype11 state/surface
  +-- Scheduled workspace carrying the exact Home state it opened from
```

There is no new retained Home selection or target state.

Carrying the Home state means Back restores the same SelectedDay exactly.

Lean checks that:

- Scheduled workspace evidence is exactly the production open-world day query for
  the retained SelectedDay;
- Back from Scheduled restores the exact Home state;
- therefore Back preserves the same day coordinate.

## What this intentionally does not add

- no Home target/focus state;
- no generic router;
- no generic workspace abstraction;
- no pane/grid framework;
- no shared Actual/Scheduled cursor type;
- no Scheduled detail mode;
- no writer entrance;
- no Record Actual action;
- no recurrence/cadence/series model;
- no new canonical fact;
- no final semantic colors or journal-style amount layout.

## Human gate

On a day with explicit Scheduled evidence, such as the current GPT Plus specimen:

1. press Tab from Home;
2. confirm the workspace feels like a useful semantic place rather than a redundant
   expanded preview;
3. confirm the retained occurrence is immediately understandable as expectation
   evidence rather than Actual evidence;
4. Back and confirm the exact selected date is restored.

On a day with no explicit Scheduled evidence:

1. press Tab from Home;
2. confirm the `Unknown` workspace feels informative rather than alarm-like or
   pointless;
3. decide whether an Unknown-only workspace earns its existence at all.

The key design result is not whether the temporary Tab shortcut survives. The
question is whether Scheduled itself earns a workspace and whether concrete use
creates pressure for shared Browse/Detail mechanics.

## Run

```sh
lake build loamUiPrototype12
./.lake/build/bin/loamUiPrototype12
```
