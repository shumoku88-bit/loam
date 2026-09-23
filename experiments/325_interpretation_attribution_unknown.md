# Observation 325 — missing attributed time is meaningful

Status: **BOUNDED ALLOY PROBE — DO NOT PROMOTE YET**

Baseline: `0e793585d345ebc783f510932dbe73545612dd5c`

## Trigger

Observations 321–324 left a small interpretation shape:

```text
interpretive text
  subject -> Fact
  recordedAt
  attributedAt
```

Before treating `attributedAt` as required input, test the ordinary case where
the human does **not know** whether the present interpretation already belonged
to the earlier moment.

Example:

```text
2026-09-20  bought a book
2026-09-24  "it may also have been relief / distraction"

but:
  "I do not know whether I already felt that on 9/20,
   or whether I only see it that way now."
```

## Question

> Is missing attribution meaningfully distinct from explicitly attributing the
> perspective to Fact time or to recording time?

## Model boundary

`attributedAt` is now optional (`lone Moment`).

When present, it remains constrained between the subject Fact time and
`recordedAt` for this retrospective probe.

When absent, the model makes no substitute claim.

## Expected matrix

```text
unknownVersusFactTimeExists                    SAT
unknownVersusRecordedTimeExists                SAT
unknownChangesExplicitAsOfAnswer               SAT
defaultToFactCollapsesDistinctMeaning          SAT
defaultToRecordedCollapsesDistinctMeaning      SAT

BaseEvidenceDeterminesAttributionPresence      SAT counterexample
EqualOptionalAttributionDeterminesExplicitAsOfView  UNSAT counterexample
```

## Intended conclusion if qualified

These states must remain distinct:

```text
attributedAt = unknown
attributedAt = Fact time
attributedAt = recordedAt
```

Therefore a writer must not silently fill missing attribution from either
neighboring time coordinate.

This protects the low-input workflow:

- text is required only when the person chooses to reflect;
- subject is explicit;
- recordedAt can be captured by the writer;
- attributedAt may remain absent.

## What this does not earn

- production persistence;
- mandatory diary prompts;
- AI inference of attributedAt;
- psychological truth claims;
- a production Reflection object.

## Next pressure

If qualified, freeze field discovery and test the smallest implementation
boundary:

> reuse zero-effect Event + EventDescription for identity/text, and add only
> explicit interpretation metadata for subject, recordedAt, and optional
> attributedAt.

The next observation should test whether that split representation is lossless
for the qualified queries and whether it can fail closed on orphan subjects or
missing note Events.
