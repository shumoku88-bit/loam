# LOAM UI Prototype 11

Prototype 11 keeps Prototype 10's interaction state unchanged and pressures one
new question:

```text
SelectedDay
  +-- current Actual
  +-- open-world Scheduled day evidence
```

Can two distinct household evidence families follow one temporal coordinate on
Home without introducing another Home state, dashboard model, or generic router?

## Canonical read boundary

Actual remains the same manifest-backed, correction-aware `ActualReview` snapshot.

Scheduled is loaded through `Loam.ScheduledReview`, but the day answer itself is
the production open-world Application contract qualified by Observation 211 / PR
#475:

```text
scheduled.loam
+ scheduled completion / retirement / replacement evidence
+ Event identity from the selected Movement manifest generation
        |
        v
Application.currentScheduledDayEvidenceWithReplacement(..., SelectedDay)
        |
        +-- explicit current-open occurrence(s) -> Due + evidence
        |
        +-- no explicit current-open occurrence -> Unknown
```

`Unknown` is deliberately not `NotDue`. LOAM has no qualified completeness horizon,
Recurrence, Cadence, Series, or future-materialization policy from which absence
could be promoted into a negative household claim.

Lifecycle evidence is still admitted before raw terminal mode begins. Unknown
Scheduled identities, invalid replacement topology, and conflicting terminal
evidence therefore refuse startup rather than appearing as an ordinary `Unknown`
day.

The stacked Prototype 11 branch predates the #475 main merge, so it temporarily
carries the exact production `ScheduledOpenWorldInspection` module from current
main. This is stack plumbing, not a fork of the semantics; it should collapse away
when the prototype stack is later rebased or merged onto that production revision.

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
                    Scheduled: Due + explicit rows
                               or Unknown
```

Actual shows at most three rows. A `Due` Scheduled answer shows at most two
explicit rows. `Unknown` shows no fabricated empty collection and is labeled as
Unknown. Those bounds are only presentation pressure. No pagination, scrolling
framework, pane abstraction, or retained dashboard state is introduced.

## Checked local relationships

Lean checks that:

```text
Home Actual preview
  = take 3 (current Actual selected by SelectedDay)

Home Scheduled evidence
  = Application.currentScheduledDayEvidenceWithReplacement(..., SelectedDay)

Home Scheduled preview
  = take 2 (explicit rows carried by that Due answer)
```

The existing Actual workspace count relationship and Enter-preserves-day law are
also retained through the imported interaction model.

These are semantic projection/orientation checks, not proofs of visual quality.

## Deliberate omissions

- no Scheduled workspace yet;
- no Scheduled writer entrance;
- no Issue or Report preview;
- no completeness horizon;
- no Recurrence / Cadence / Series;
- no attention markers;
- no final journal-style amount layout or semantic colors;
- no generic pane / dashboard / router abstraction;
- no new canonical fact;
- no complete wcwidth / grapheme-aware layout model.

## Human gate

Move across September and observe whether:

1. Actual and Scheduled both follow one selected day immediately;
2. days without explicit Scheduled evidence visibly say `Unknown`, without feeling
   like a false warning or a false `none` claim;
3. a day carrying explicit current-open Scheduled evidence shows `Due` and the real
   movement evidence without another command;
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
