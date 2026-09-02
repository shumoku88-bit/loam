# Observation 094 — Does valid time need one universal granularity?

## Question

Observation 092 found that a coarse temporal coordinate with ties is not sufficient to derive one Event-relative origin cut, while an explicit `Before / At / After` cut is sufficient in the bounded model.

Observation 093 then separated valid time from learned time for retrospective admission.

The new question is narrower and practical:

> If household queries naturally use calendar-day validity, must every retained Event nevertheless receive a finer universal timestamp merely because first-event current needs an intra-day origin boundary?

## Pressure case

Suppose three Events are valid on the same calendar day:

```text
X       before Origin
Origin  at the selected first-event boundary
Y       after Origin
```

A day-oriented query only asks:

```text
which Events are valid on this day?
```

For that query, all three belong to the same bucket.

The first-event current query asks something different:

```text
which Events are at or after Origin?
```

For that query, `X` must be excluded while `Origin` and `Y` are included.

So the experiment compares whether one validity representation must serve both vocabularies by itself.

## Model

`094_valid_time_granularity.als` keeps only:

- three stable Event identities: `Origin`, `X`, and `Y`;
- two abstract calendar days;
- a strict total order used only as bounded ground truth;
- one `validDay` coordinate per Event;
- one origin-relative `Before / At / After` cut per Event.

Across different days, the ground-truth order must respect day order. Within one day, multiple Event orders remain possible.

No wall-clock type, timezone, duration, interval, learned time, correction, quantity arithmetic, persistence, or production Event field is introduced.

## Two query vocabularies

The model derives:

```text
dayMembers(world, day)
  = Events whose validDay equals day

postOrigin(world)
  = Origin plus Events after Origin

postByCut(world)
  = Events marked At or After
```

## Expected boundaries

The experiment asks for these results:

1. A same-day witness can place one Event before and one Event after Origin.
2. The same `validDay` assignment can coexist with different post-origin sets.
3. The same `validDay + cut` can coexist with different global orders among Events on the same side of Origin.
4. `validDay` alone determines the day-bucket query.
5. `validDay` alone does not determine the Event-relative post-origin query.
6. The explicit cut agrees with the Event-relative scope.
7. `validDay + cut` determines both selected queries in the bounded model.

## Interpretation boundary

If the expected receipt holds, the observation supports a query-relative view of temporal granularity:

```text
calendar-day validity
  sufficient for day-bucket questions

calendar-day validity alone
  insufficient for an intra-day Event-origin question

calendar-day validity + local origin-relative cut
  sufficient for both selected questions
```

The intended consequence is not that production should store both fields immediately.

It is that one query needing a finer distinction does not by itself justify refining every Event into one universal exact timestamp or total chronology.

A coarse coordinate can remain meaningful for the vocabulary that consumes it, while a more local temporal distinction carries only the extra information another query needs.

## Relation to household use

This matters for ordinary retrospective entry. A household Event may naturally be known as:

```text
valid on 2026-09-02
```

without the human knowing or caring whether it occurred at `10:03:14`.

If a particular first-event origin on that same date needs a before/after distinction, forcing invented precision into every Event would preserve more order than the human actually observed.

The experiment therefore asks whether LOAM can avoid converting uncertainty into fake timestamp precision.

## Non-goals

Observation 094 does not earn:

- a production `Date` type;
- a production Event `validDay` field;
- a production `Before / At / After` fact;
- exact timestamps;
- timezones;
- duration or interval semantics;
- a global Event chronology;
- automatic inference of same-day order;
- changes to CurrentQuantity, Persistence, CLI, or private household data.

## Practical Core impact

None.
