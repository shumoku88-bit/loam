# G2-022 — Conditional Liquidity derived-summary obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + obligation DAG + production-consumer reachability**.

## Question

G2-007 already qualified the cross-reader temporal obligation for Conditional Liquidity:

```text
BalanceReview Actual observation
+
ScheduledReview Actual observation
        |
        v
same actual.loam generation
```

G2-022 asks a different, smaller question inside the already-qualified result boundary:

> Which values in `ConditionalBalancePathReview.Snapshot` are independent answer components, and which are exact functions of retained components?

Before G2-022 the snapshot retained:

```text
asOf
assumedCompleteThrough
measure
currentSelected
points
finalAtHorizon
lowWater
```

The last two values are fully determined by `currentSelected` and `points`.

## Dependency graph

Each emitted `Point.balance` is already the cumulative selected balance after one day-boundary Scheduled bucket.

Therefore:

```text
currentSelected
      |
      +------------------------------+
      |                              |
      v                              v
points = []                     points != []
      |                              |
      v                              v
finalAtHorizon              last point.balance
= currentSelected

currentSelected + every point.balance
              |
              v
             min
              |
              v
          lowWater
```

No additional authority, assumption, date rule, Scheduled fact, or ordering decision enters either summary.

## Why the retained fields were redundant

Before G2-022, callers could in principle construct a `Snapshot` such as:

```text
currentSelected = 1000
points = [700]
finalAtHorizon = 999999
lowWater = -42
```

Even though production `project` never produced that contradiction, the type represented the two summaries as independent state.

That violates the audit rule:

```text
retain independent facts
derive exact consequences
```

The repair removes `finalAtHorizon` and `lowWater` from the structure and restores them as same-named derived functions:

```text
snapshot.finalAtHorizon
snapshot.lowWater
```

Production Reports therefore keeps the same read shape while the result type loses two independent degrees of freedom.

## Empty-path obligation

An empty Scheduled path is not a special retained summary case.

```text
points = []
        |
        +--> finalAtHorizon = currentSelected
        `--> lowWater        = currentSelected
```

This follows directly from the derivations and remains covered by the existing ConditionalBalancePath regression.

## Point construction

Once the final summary is no longer retained, `buildPoints` no longer needs to return:

```text
(finalBalance, points)
```

It now returns only the chronological cumulative point list. The running balance remains local recursion state used solely to construct each next `Point.balance`.

This is implementation compression, not a new semantic distinction.

## What remains independent

G2-022 keeps:

- `asOf`, because it defines the present/future partition;
- `assumedCompleteThrough`, because it is the explicit conditional assumption;
- `measure`, because the selected balance view must be single-measure;
- `currentSelected`, because it is the retained starting answer from BalanceReview;
- `points`, because they preserve dated Scheduled change provenance and the cumulative conditional path.

Those values cannot be reconstructed from one another without losing a qualified input or visible path result.

## What does not change

G2-022 does **not** change:

- the unconditional `Forecast path: UNKNOWN` baseline;
- the conditional epistemic label;
- overdue refusal;
- same-day netting;
- inclusive assumption horizon;
- Scheduled current-open admission;
- BalanceReview selection semantics;
- G2-007 same-Actual-generation ownership;
- any canonical authority or persistence format;
- Reports presentation wording.

## Consumer reachability

Repository-wide use shows the summary values are consumed as read-only report outputs:

- `Loam/Tui/Reports.lean` renders `snapshot.finalAtHorizon` and `snapshot.lowWater`;
- `Loam/Tests/ConditionalBalancePathReview.lean` checks their arithmetic;
- `Loam/Tests/TuiReports.lean` supplies a presentation fixture.

No production consumer treats either value as an independently authoritative input.

The TUI production source does not need to change because generalized field notation resolves the same names to the derived `Snapshot` functions.

## Stop point

G2-022 does **not** attempt to remove `Point.balance` merely because it can be reconstructed from prior points and `scheduledChange`.

`Point.balance` is the visible cumulative value at that dated change point and is consumed directly by presentation. Removing it would change the point-level API and force every consumer to replay the path. No independent pressure for that larger representation change has been established here.

Likewise, no generic report-summary abstraction is added.

## Qualification

Production/audit head `5e8443e4564671d20392814741349ce1976a6c9a` passed all triggered qualification:

- Compression Audit: **SUCCESS**;
- Selected Lean Observations: **SUCCESS**;
- Production TUI: **SUCCESS**, all production verification steps passed.

The directly relevant Production TUI steps also passed:

- build conditional selected-balance path review boundary: **SUCCESS**;
- conditional selected-balance path and refusal boundaries: **SUCCESS**;
- sparse Transactions-Flow Reports interaction: **SUCCESS**;
- Reports menu, Stock-Flow, Transactions-Flow, conditional Liquidity and Budget Window surfaces: **SUCCESS**.

The existing ConditionalBalancePath regression therefore still proves chronological day-boundary points, same-day netting, final-at-horizon arithmetic, low-water arithmetic, empty-path identity, and overdue refusal. The Reports regression still renders the same summary values and epistemic labels even though the two summaries are no longer retained fields.

The DRAKON builder is committed audit instrumentation but was not independently executed during this qualification, so no generated-map runtime claim is made here.

Final verdict:

**G2-022: SIMPLIFY QUALIFIED — Conditional Liquidity retains only the independent path state; final-at-horizon and day-boundary low-water are derived from currentSelected plus points.**
