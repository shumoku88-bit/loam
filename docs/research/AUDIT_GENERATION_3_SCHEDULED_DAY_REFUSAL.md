# Generation 3 — Scheduled exact-day refusal fanout

Status: **QUALIFIED REVIEW-BOUNDARY EXPERIMENT**

## Question

Should TUI and CLI surfaces understand detailed Scheduled lifecycle failure
constructors in order to answer one exact-day household question?

## Discovery

`Application.CurrentScheduledDayEvidenceResult` deliberately preserves seven
inspection outcomes:

```text
valid answer:
  due
  unknown

invalid lifecycle:
  unknown completion target
  unknown retirement target
  unknown replacement target
  invalid replacement graph
  conflicting terminal evidence
```

That low-level vocabulary is useful for qualification: malformed lifecycle
evidence must never collapse into ordinary open-world `unknown`.

However, `ScheduledReview.dayEvidence` previously re-exported the Application
type unchanged. As a result, four presentation paths independently translated the
same five invalid states into refusal:

- Home;
- HraScheduled;
- SelectedDay;
- ScheduledDayEvidenceCli.

The surfaces differed mainly in wording, not in semantic policy.

## Existing owner

`ScheduledReview.currentOpenRecords` already owns the production mapping from the
same five lifecycle failures to fail-closed `Except String`.

Exact-day Review therefore does not need a second copy of that refusal mapping.

## Experiment

Make the Review answer intentionally smaller:

```text
ScheduledReview.DayEvidence =
  Due(first, rest)
  | Unknown

ScheduledReview.dayEvidence :
  EvidenceSnapshot -> date -> Except String DayEvidence
```

Implementation:

1. pass through `currentOpenRecords`, reusing its lifecycle admission/refusal;
2. filter admitted current-open rows for the requested date;
3. return non-empty `Due` or open-world `Unknown`.

Home, HraScheduled, SelectedDay and CLI now consume only:

```text
.error refusal
.ok Unknown
.ok Due
```

They no longer know the five low-level lifecycle failure constructors.

## Preservation of diagnostic power

This does **not** delete the detailed Application result.

`ScheduledOpenWorldInspection` and its focused tests still preserve and inspect
the individual invalid lifecycle constructors. The compression happens only when
crossing into the shared household Review boundary.

A Review regression constructs an unknown replacement endpoint and checks that
`dayEvidence` returns the same qualified fail-closed message already owned by
`currentOpenRecords`.

## Boundary meaning

`Unknown` remains specifically:

> no explicit current-open Scheduled occurrence is retained for this queried day.

It is never `NotDue`.

`error` means the Scheduled lifecycle cannot justify a day answer at all.

## Tool choice

This is a typed ownership/refusal question.

- cross-surface code search found repeated translation;
- the existing Application type preserves detailed inspection evidence;
- the existing Review current-open boundary already owns refusal text;
- D2 records the before/after fanout;
- Lean build and executable publisher/TUI/CLI tests qualify the refactor.

No Alloy/TLA+/SPIN model is added because no new possibility or temporal rule is
introduced.

## Stack relationship

This audit is intentionally based on PR #1221 because both slices touch
`ScheduledReview`.

#1221 owns deterministic current-open **ordering**.
This slice owns exact-day **refusal qualification**.

They are separate responsibilities and should remain separate reviewable changes.

## Decision rule

Keep this boundary if Scheduled publisher, TUI, CLI and open-world qualification
stay green.

If a presentation later genuinely needs to distinguish an unknown replacement
target from an invalid replacement graph, it should request an explicit diagnostic
view rather than weakening the ordinary household day-answer type.
