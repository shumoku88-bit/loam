# Observation 322 — interpretation recording time is an independent coordinate

Status: **BOUNDED ALLOY PROBE — DO NOT PROMOTE YET**

Baseline: `c3db12c17602df297d1a7085345478cb05b14ed7`

## Trigger

Observation 320 showed that later interpretation history can coexist with stable
Facts without requiring one mutable "current interpretation".

Observation 321 then reduced the first independently surviving distinction to a
small subject association:

```text
interpretive text -> household Fact
```

The next question is intentionally narrower than a complete Reflection model:

> If Fact, interpretive text, and subject attribution are all fixed, does LOAM
> still need to know *when the interpretation became retained evidence* in order
> to answer a household-history question?

## Household question

The concrete query is:

> By this cutoff time, which interpretations about this Fact had already been
> retained?

This is an as-of knowledge/history question, not a question about when the
underlying purchase or other household Fact occurred.

For example:

```text
Fact:
  2026-09-20  bought a book

same later interpretation:
  "it may also have been a form of relief / distraction"

World A:
  recorded on 2026-09-21

World B:
  recorded on 2026-10-10
```

At a September 30 cutoff, the two worlds should answer differently even though
the Fact, text, and subject relation are identical.

## Model boundary

Each bounded World retains:

```text
Fact occurrence time
Note text
Note -> Fact subject relation
candidate Note recordedAt
```

The two Worlds are forced to agree on every coordinate except `recordedAt`.

The model also requires that an interpretation is not recorded before the Fact
it is about. This is only a simplifying boundary for this observation. A future
model may separately study interpretations of plans or future possibilities.

No `attributedAt` coordinate is introduced here. Observation 323, if earned,
should test that distinction separately.

## Candidate query

```text
notesKnownBy(world, fact, cutoff)
```

returns only Notes about the selected Fact whose `recordedAt` lies at or before
the cutoff.

## Expected matrix

```text
laterRecordingExists                       SAT
sameBaseDifferentRecording                 SAT
sameBaseDifferentAsOfAnswer                SAT

NonRecordedEvidenceDeterminesAsOfView      SAT counterexample
RecordedTimeDeterminesAsOfView             UNSAT counterexample
```

Interpretation:

- the same Fact/text/subject evidence can admit different recording times;
- those worlds can answer an as-of interpretation query differently;
- Fact occurrence time plus text plus subject does not determine that answer;
- once `recordedAt` is also fixed, the bounded as-of answer is fixed.

## Existing LOAM time boundaries

This observation does not claim that a new time representation is needed.

LOAM already has several semantically distinct time coordinates, including
Actual validity time and Attention closure `knownOn`. The question here is only
whether interpretation-recording time carries independent meaning.

If the distinction survives, the later design question is whether an existing
time-bearing mechanism can represent it without importing the wrong authority or
lifecycle semantics.

In particular:

- the subject Fact's occurrence/validity time answers when the household Fact is
  situated, not when a later interpretation was recorded;
- Attention closure `knownOn` answers when closure evidence became known, not
  when arbitrary interpretive text was retained.

## What a successful result would earn

Only this information-boundary claim:

> For historical "what had I already written/thought about this Fact by time T?"
> queries, recording time is information independent of the subject Fact's time,
> note text, and subject attribution.

It would **not** yet earn:

- a production `Reflection` type;
- a new canonical file;
- a new clock or timestamp representation;
- automatic diary capture;
- mandatory recording time on all human notes;
- an `attributedAt` coordinate;
- real/complex-number semantics.

## Next pressure if qualified

Test `attributedAt` separately:

> Can two interpretations have the same Fact, text, subject, and recording time
> while differing only in the time the human says the remembered perspective
> belonged to, and does that change a legitimate query?

That would distinguish:

```text
when I recorded this interpretation
```

from:

```text
when I now say this perspective belonged
```

without backdating retained evidence.
