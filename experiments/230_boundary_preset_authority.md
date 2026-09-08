# Observation 230 — Does a saved household boundary source need canonical authority?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J at model head `915bc47f6b7fb3394c8bcd759465e3bb3ce0f2a5`; replaceable BoundaryPreset configuration is sufficient for the bounded coordinate-only report question, while explicit fact membership remains the authority stop condition**

## Pressure

Observation 228 qualified a small window-selection mechanism:

```text
selected date
+ selected boundary source
+ explicit known boundary dates
-> adjacent [start, end)
```

This supports pension, salary, card, and irregular household windows without adding retained Cycle instances.

The next temptation is to persist each named boundary source as a canonical LOAM authority merely because the household wants convenient reusable choices such as `Pension` or `Salary`.

That step is not yet justified.

LOAM already distinguishes replaceable application configuration from canonical household fact streams. `BalanceViewConfig` is an explicit example: it selects the current question, carries no historical winner semantics, and may be absent without inventing a household fact.

This observation asks:

> If downstream reports consume only the resolved `[start, end)` coordinates, can a saved boundary source remain replaceable query configuration while reproducible report runs capture the resolved coordinates? What would actually earn canonical source identity/history?

## Candidate A: replaceable query preset

A preset holds current convenience evidence:

```text
Preset identity / label
+ explicit boundary dates
```

At query time:

```text
preset + selected date
-> resolved [start, end)
-> Budget Window / Stock-Flow
```

Changing the preset may change the **next question** without changing any canonical household fact.

If historical report reproducibility matters, the report receipt can capture the coordinates actually used:

```text
resolved start
resolved endExclusive
```

Replaying that receipt need not consult the later edited preset.

## Candidate B: canonical boundary-source history

A stronger design would retain boundary-source identity and revisions as canonical household meaning.

This becomes justified only if later household facts or policies actually refer to that identity in a way that coordinates cannot replace, for example explicit fact membership in overlapping regimes.

That is intentionally modeled as a stop-condition witness, not selected by default.

## Qualified matrix

Alloy 6.2.0 / SAT4J produced the expected bounded matrix:

```text
presetEditChangesLiveWindowButReceiptStaysOld                 SAT
replaceablePresetCanChangeCurrentQuestionWithoutChangingFacts SAT
explicitFactMembershipMakesPresetIdentityObservable           SAT

CapturedReceiptReplaysOriginalCoordinateAnswer                UNSAT counterexample
SameResolvedWindowGivesSameCoordinateAnswer                    UNSAT counterexample
PresetIdentityAloneCannotChangeCoordinateAnswer                UNSAT counterexample
```

### 1. Editing a preset can change the live question while an old receipt remains stable

Two states of the same preset retain different boundary dates around the same selected date. The live adjacent window changes.

A receipt captured from the earlier state still selects the earlier coordinate answer after the preset has changed.

Result: **SAT**.

This pressures saved source configuration but does not by itself require canonical history.

### 2. Replaceable preset state can change a current query without changing household facts

The same facts exist in both worlds. Only the preset boundaries change, causing a different live window answer.

Result: **SAT**.

This is ordinary query-parameter behavior. A different answer does not automatically make the parameter a canonical household fact.

### 3. Explicit fact membership can make source identity independently observable

Two different source identities have exactly the same boundary dates, but canonical facts explicitly belong to different sources.

Result: **SAT**.

This is the stop condition. If LOAM later needs such membership, source identity becomes more than a query shortcut and stronger authority may be earned.

### 4. A captured coordinate receipt exactly replays the original coordinate answer

Result: **UNSAT counterexample**.

For this coordinate-only model, resolved endpoints are sufficient to replay the original query answer. Historical preset revision identity is not additionally observable merely for report replay.

### 5. Equal resolved windows imply equal coordinate-derived answers

Result: **UNSAT counterexample**.

Downstream report semantics depend on the resolved coordinates and canonical evidence, not the preset label used to obtain them.

### 6. Preset identity alone adds no coordinate answer

Result: **UNSAT counterexample**.

If two preset states retain the same boundary dates, changing only their identity cannot change a coordinate-derived answer.

## Finding

For the currently qualified reports, the smaller production shape is:

```text
replaceable BoundaryPreset configuration
  -> selected source
  -> explicit known boundaries
  -> resolved [start, end)
  -> existing shared report
```

and, only if reproducibility is requested:

```text
report/query receipt
  -> resolved [start, end)
```

rather than:

```text
canonical BoundarySource revision history
+ canonical Cycle identities
+ report membership authority
```

The important distinction is:

```text
saved reusable question != canonical household meaning
```

This mirrors the existing `BalanceViewConfig` boundary. Persistence for convenience does not itself earn append-only history, learned-time semantics, correction relations, or winner rules.

## Household consequence

A practical pension-cycle shortcut may therefore begin as replaceable application configuration containing explicit known pension boundaries. A salary shortcut may be another replaceable preset. Selecting either simply resolves an explicit `[start, end)` and delegates to the existing report.

Editing the pension preset changes future query selection. It does not rewrite canonical household history.

If a report run later needs a durable reproducibility receipt, capture the resolved endpoints used by that run instead of forcing every preset edit into canonical household history.

## Important limits

This observation does not decide:

- whether production should save presets at all;
- the concrete preset file format or location;
- whether a query receipt should itself be persisted;
- naming, ordering, or TUI shortcuts;
- automatic import of pension or salary boundaries;
- recurrence generation or business-day adjustment;
- rollover semantics;
- learned-time semantics for boundary edits;
- explicit fact membership in overlapping budget regimes.

It also does not say that boundary dates are unimportant. They are observable query evidence because changing them changes the selected window. The question is narrower: **does that make them canonical household facts, or merely saved query configuration?**

## Stop condition

Do not promote BoundaryPreset to canonical authority merely because it is saved and reused.

Promote stronger source identity/history only when two worlds can agree on:

- canonical household facts;
- resolved query coordinates;
- selected report semantics;

and still require different household answers because the source identity or its historical policy is independently referenced.

Explicit regime membership is the deliberate bounded example of that pressure.
