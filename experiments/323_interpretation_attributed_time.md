# Observation 323 — attributed interpretation time is distinct from recording time

Status: **BOUNDED ALLOY PROBE — DO NOT PROMOTE YET**

Baseline: `48f47301374cbaaa7ce04e69ef35817cae53e249`

## Trigger

Observation 321 qualified subject attribution as independently meaningful.
Observation 322 then qualified `recordedAt` for historical as-of questions.

The remaining temporal ambiguity is different:

> When I record an interpretation now, am I saying only that I think this now,
> or am I saying that this perspective already belonged to an earlier moment?

For example:

```text
Fact:
  2026-09-20  bought a book

Note recorded:
  2026-09-24  "it may also have been a form of relief / distraction"
```

Two readings remain possible:

```text
A. I now remember that this perspective belonged to 2026-09-20.
B. I only came to this interpretation on 2026-09-24.
```

The text, subject Fact, and recording time may all be identical.

## Question

> Does the time a retained interpretation *attributes the perspective to* carry
> information independent of both the Fact time and the note's recording time?

This is not a claim that the attributed time is psychological truth.
It is only retained evidence that the human currently says the perspective
belonged to that time.

## Model boundary

Each bounded World retains:

```text
Fact occurrence time
Note text
Note -> Fact subject relation
recordedAt
candidate attributedAt
```

The two Worlds are forced to agree on every coordinate except `attributedAt`.

For this narrow retrospective experiment, `attributedAt` must lie between the
subject Fact's occurrence time and `recordedAt`.

That restriction is not proposed as a universal rule. Future plans, anticipatory
feelings, or interpretations of future possibilities may need a different model.

## Household query

The concrete query is:

> Which interpretations do I now explicitly attribute to already having belonged
> by cutoff T?

Formally:

```text
notesAttributedBy(world, fact, cutoff)
```

This query deliberately differs from Observation 322's:

```text
what had already been recorded by cutoff T?
```

One is about retained-evidence arrival. The other is about the time that the
retained evidence itself refers to.

## Expected matrix

```text
sameBaseDifferentAttribution                  SAT
contemporaneousVersusLaterExists             SAT
sameBaseDifferentAttributedAsOfAnswer         SAT

FactAndRecordingTimesDetermineAttributionView SAT counterexample
AttributedTimeDeterminesAttributionView       UNSAT counterexample
```

Interpretation:

- identical Fact/text/subject/recordedAt evidence can admit different attributed times;
- one world can say the perspective belonged at the Fact time while another says
  it belongs only at recording time;
- those worlds can answer an attributed-as-of query differently;
- Fact time and recordedAt therefore do not determine this query;
- once attributedAt is fixed, the bounded query is fixed.

## Why the text itself is not used as a timestamp

Existing EventDescription, Attention context, and PersonalSemanticMemory text are
intentionally opaque human text. Parsing phrases such as "at the time" or
"looking back now" would turn prose interpretation into hidden semantic authority.

If this coordinate survives, it should be explicit or remain unavailable. It
should not be guessed from language by default.

## What a successful result would earn

Only this information-boundary claim:

> `recordedAt` and `attributedAt` answer distinct temporal questions.

The candidate minimal shape would then be:

```text
interpretive text
  subject -> Fact
  recordedAt
  attributedAt
```

It would **not** yet earn:

- a production `Reflection` type;
- a new canonical file;
- automatic extraction from conversation;
- psychological causation semantics;
- confidence scoring;
- a rule that attributedAt must always exist;
- a rule that attributedAt must always equal the Fact time;
- real or complex coordinates.

## Next pressure if qualified

Stop adding fields temporarily.

The next question should be compression rather than another coordinate:

> Can the surviving text + subject + recordedAt + attributedAt shape be represented
> cleanly by existing LOAM Event / EventDescription machinery without importing
> correction, quantity, or Attention lifecycle semantics?

If yes, a new Reflection primitive may still be unnecessary.
