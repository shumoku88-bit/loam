# LOAM UI Prototype 11

Prototype 11 keeps Prototype 10's interaction state unchanged and pressures one
new question:

```text
SelectedDay
  +-- current Actual
  +-- current-open Scheduled
```

Can two distinct household evidence families follow one temporal coordinate on
Home without introducing another Home state, dashboard model, or generic router?

## Canonical read boundary

Actual remains the same manifest-backed, correction-aware `ActualReview` snapshot.

Scheduled is loaded through `Loam.ScheduledReview`:

```text
scheduled.loam
+ scheduled completion / retirement / replacement evidence
+ Event identity from the selected Movement manifest generation
        |
        v
Application.currentOpenScheduledWithReplacement
        |
        v
current-open Scheduled snapshot
        |
        v
filter scheduledOn = SelectedDay
```

The Scheduled projection refuses the whole answer when lifecycle evidence refers
to unknown Scheduled identities, replacement topology is invalid, or terminal
evidence conflicts. It does not infer completion from date or hide past-due open
occurrences merely because they are in the past.

## Reused interaction

Prototype 11 imports Prototype 10 / Prototype 09 interaction unchanged:

- Home and one Actual workspace remain the only top-level surfaces in this
  specimen;
- Actual browse/detail remain local workspace modes;
- Left/Right move one day;
- Up/Down move one week;
- Enter opens Actual for the same selected day;
- Back preserves temporal and row orientation.

Scheduled is preview-only here. A Scheduled workspace is deliberately not added in
the same step, so this experiment isolates shared-coordinate composition from
workspace-navigation pressure.

## Home presentation

The current 80x24 specimen directly composes:

```text
monthly calendar    selected-day evidence
                    Actual preview
                    Scheduled preview
```

Actual shows at most three rows and Scheduled at most two. Those bounds are only
presentation pressure. No pagination, scrolling framework, pane abstraction, or
retained dashboard state is introduced.

The canonical Scheduled stream currently gives useful future-day witnesses such
as September 8, 10, 15, 18, 24, and 29, so moving the calendar should make the
Scheduled section visibly appear and disappear without another command.

## Checked local relationships

Lean checks that:

```text
Home Actual preview
  = take 3 (current Actual selected by SelectedDay)

Home Scheduled preview
  = take 2 (current-open Scheduled selected by the same SelectedDay)
```

The existing Actual workspace count relationship and Enter-preserves-day law are
also retained through the imported interaction model.

These are semantic projection/orientation checks, not proofs of visual quality.

## Deliberate omissions

- no Scheduled workspace yet;
- no Scheduled writer entrance;
- no Issue or Report preview;
- no attention markers;
- no final journal-style amount layout or semantic colors;
- no generic pane / dashboard / router abstraction;
- no new canonical fact;
- no complete wcwidth / grapheme-aware layout model.

## Human gate

Move from September 6 toward the known Scheduled dates and observe whether:

1. Actual and Scheduled both follow one selected day immediately;
2. days without Scheduled evidence remain visually quiet rather than confusing;
3. a day such as September 8 exposes its open Scheduled movement without opening a
   second screen;
4. Enter still opens the same day's Actual workspace and Back returns to the same
   date;
5. the Home feels richer but not conceptually heavier;
6. responsiveness remains good.

If this survives, the next question is whether Scheduled earns its own HRA-style
workspace while preserving the same Home coordinate, not whether Home needs more
presentation decoration yet.

## Run

```sh
lake build loamUiPrototype11
./.lake/build/bin/loamUiPrototype11
```
