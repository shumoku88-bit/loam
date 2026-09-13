# Observation 247 — Actual Consumption value vs classification closure

Status: **QUALIFIED — selected CurrentCoverage value and Actual classification closure are distinct in the executable witness**

Baseline:

```text
3e3c96e72d46368b68d8f61aaa0785dd34728d8c
feat(tui): observe current quantity anchors (#826)
```

Current household pressure:

```text
loam-data 9aca13c98dd8a479b3817478d603976b9aa32ac4
```

## Question

Observation 111 deliberately retained three historical Actual routing states at an Event's valid coordinate:

```text
managed Purpose
explicitly unmanaged
unrouted
```

Current Consumption answers only the selected Purpose quantity. An Effect contributes when the route visible at the containing Event's valid coordinate is `managed queriedPurpose`; all other routing states contribute zero to that selected value.

The bounded question is therefore:

> Can the selected CurrentCoverage quantity be answerable while the classification of eligible Actual Expense evidence is still open?

Equivalently:

> If two worlds return the same managed Consumption but one contains explicit no-Purpose evidence and the other contains no route evidence, does the numeric projection alone preserve enough information to claim complete Purpose classification?

## Production path under test

The executable witness calls the existing production-compatible composition path directly:

```text
currentCoverageAtCorrectionFrontierEffectiveRouting?

Capacity + effective coordinates
Actual Event + correction frontier
ActualValidity
historical Actual routing with INITIAL / dated coordinates
Scheduled lifecycle + ScheduledRouting + AccountingRole
    -> CurrentCoverageView
```

No observation-local replacement arithmetic or proposed production `Answerability` type is used.

## Four routing worlds

One balanced Actual Event is valid at coordinate 2:

```text
cash    -30 jpy
expense +30 jpy
```

`expense` has explicit `AccountingRole.expense` evidence. Food Capacity is 100 jpy and Scheduled evidence is empty, so managed Commitment is zero.

The witness compares:

```text
A  expense -> food       visible before Event.validOn
B  expense -> general    visible before Event.validOn
C  expense -> unmanaged  visible before Event.validOn
D  no routing evidence visible at Event.validOn
```

Observed CurrentCoverage answers for queried Purpose `food`:

```text
A  Consumption 30   Remaining 70   Headroom 70
B  Consumption  0   Remaining 100  Headroom 100
C  Consumption  0   Remaining 100  Headroom 100
D  Consumption  0   Remaining 100  Headroom 100
```

The selected numeric answer therefore intentionally collapses B, C and D even though their routing states differ.

That collapse is correct for the narrow query:

```text
How much Actual quantity is managed to food?
```

It is not by itself enough to answer the stronger query:

```text
Is the food-related Actual classification complete?
```

## Late-route control

A fifth world adds:

```text
expense -> food @ dated 3
Event.validOn = 2
```

The route is visible at coordinate 3 but not at the Event's own valid coordinate. Observation 111 already established that current routing must not be applied backward. The Lean witness confirms that this late-routed world produces the same CurrentCoverage answer as the unrouted world.

## Information witness

The critical pair is C vs D:

```text
C
  selected food Consumption = 0
  routing status = explicitly unmanaged

D
  selected food Consumption = 0
  routing status = unrouted
```

Their CurrentCoverage values are equal, but the retained evidence is not equivalent.

Then compare D with A while holding the Actual Event fixed. Adding route evidence visible at the Event-valid coordinate changes:

```text
Consumption  0 -> 30
Remaining  100 -> 70
Headroom   100 -> 70
```

So an unrouted Actual can be numerically silent in the current selected answer while later qualifying evidence can change downstream CurrentCoverage arithmetic.

## Executed witness

The dedicated Observation 247 workflow completed successfully on the first executable witness head:

```text
head:     700e793cb7ef7fa2b91be3fb9df2f77197bf67d6
run:      34758303830
job:      103726462276
result:   SUCCESS
Lean:     4.33.1
```

The current CurrentCoverage boundary built successfully, and the witness printed:

```text
Observation 247 witness: selected value and Actual classification closure are distinct.
```

No production module was changed to obtain this result.

## Real household witness

The current household data contains the same shape.

These Expense Loci are routed only from 2026-09-12:

```text
shipping  -> 一般生活
snacks    -> 食費
rent      -> 固定費予定
utilities -> 固定費予定
```

But retained Actual includes earlier occurrences, including:

```text
2026-08-15  rent       64000 jpy
2026-08-15  utilities  20854 jpy
2026-09-05  shipping     720 jpy
2026-09-06  snacks       354 jpy
```

Total selected positive Expense quantity in these four examples:

```text
85928 jpy
```

This does **not** justify retroactively assigning those occurrences to the later Purpose routes. It is evidence that real CurrentCoverage can contain numerically silent Event-valid `unrouted` Expense coordinates.

The existing 2026-09-08 real-data CurrentCoverage checkpoint predates the 2026-09-12 routes and therefore qualifies managed-value arithmetic, not classification closure.

## Candidate interpretation

The observation qualifies a distinction between two questions, not two stored facts:

```text
value answerability
  Is the selected managed Consumption value determined?

classification closure
  Is every relevant Actual Expense coordinate resolved as
  managed-somewhere or explicitly unmanaged at its own valid coordinate?
```

A numeric CurrentCoverage row can answer the first while leaving the second open.

## Why AccountingRole matters only as a candidate boundary

Not every unrouted Actual Locus should block a Purpose-completeness question. Asset coordinates such as cash/payment loci may legitimately remain unrouted on the Capacity Consumption surface.

The smallest candidate frontier therefore begins only with Actual coordinates that are already explicitly classified as `AccountingRole.expense` and fall inside the selected window/Measure.

Observation 247 does not yet prove that this is the final production frontier. It only rejects the stronger claim that the existing managed numeric value alone establishes complete classification.

## Qualified executable properties

`experiments/247_actual_consumption_classification_closure.lean` establishes the bounded witnesses that:

1. managed-other, explicitly unmanaged and unrouted worlds can return identical selected CurrentCoverage values;
2. those worlds retain distinct historical routing status at the Event-valid coordinate;
3. routing that becomes visible only after the Event does not rewrite the earlier answer;
4. adding managed evidence visible at the Event-valid coordinate can change Consumption, Remaining and Headroom without changing the Actual Event.

## Stop rules

```text
Do not reinterpret a later route as retroactive evidence.
Do not turn every unrouted Locus into a blocker.
Do not add retained ConsumptionComplete state.
Do not add a generic Answerability framework from this witness alone.
Do not mutate loam-data from the bounded result.
Do not replace the existing managed Consumption projection.
```

## Production gate

The next question is narrower than a new answerability subsystem:

> Can CurrentCoverage expose a pure derived list of in-window Expense Actual coordinates that were `unrouted` at their own valid coordinate, reusing the same correction frontier, validity selection and historical routing semantics as Consumption?

Only after that derived frontier demonstrates practical value should a Review/TUI answerability surface be considered.

## Verdict

**QUALIFIED for the bounded distinction; production change is not yet earned.**

The selected managed numeric answer and the completeness of its underlying Actual classification are observably different questions. Observation 247 qualifies that distinction using the current production composition path without adding new production vocabulary.
