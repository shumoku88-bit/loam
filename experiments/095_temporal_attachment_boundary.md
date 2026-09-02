# Observation 095 — Does valid time have to live inside Event?

## Question

Observation 094 found that temporal granularity is query-relative: a calendar-day validity coordinate can answer day-bucket questions, while an Event-relative origin query may need an additional local `Before / At / After` distinction.

The next question is about logical ownership rather than granularity:

> Must a valid-day observation be an intrinsic field of Event, or can the same temporal meaning be carried by a later typed fact attached to stable Event identity?

This is deliberately narrower than choosing a production schema.

## Pressure case

Suppose LOAM already retains two Events with stable identities and payloads:

```text
E0
E1
```

At one knowledge point, LOAM knows a valid day only for `E1`:

```text
E1 -> D1
E0 -> Unknown
```

Later, it learns:

```text
E0 -> D0
```

The practical question is whether learning `E0`'s valid day must require rewriting the retained Event itself.

## Two representational shapes

The Alloy model compares two shapes for the selected temporal vocabulary.

### Embedded

```text
Event -> validDay
```

### Attached

```text
TemporalFact
  target : Event
  day    : Day
```

The attached form uses stable Event identity and keeps at most one selected temporal fact per Event in each experiment-local store.

No production `TemporalFact`, `Date`, `Time`, or Event field is introduced.

## Selected queries

The experiment observes only:

```text
valid day of Event E

Events valid on Day D
```

It does not expose physical storage topology as part of the query vocabulary.

## Observed Alloy result

Alloy 6.2.0 with Sat4j produced the intended bounded result set:

```text
equivalentEncodingWitness                    SAT
lateTemporalLearningWitness                  SAT
sameCoreDifferentTemporalAnswer              SAT
unknownTimeRetainsEventWitness               SAT
EqualTemporalRelationGivesEqualDayProjection UNSAT counterexample
AttachmentPreservesKnownTemporalAnswers      UNSAT counterexample
EventCoreDeterminesTemporalAnswer             SAT counterexample
MissingAttachmentInventsNoDay                UNSAT counterexample
```

The witnesses show all of the following can coexist in the bounded model:

1. an embedded relation and an attached relation encode the same Event-to-Day mapping;
2. stable Event core coexists with different temporal answers;
3. `E0` remains a retained Event while its valid day is unknown;
4. a later attachment makes `E0` known without changing its Event payload;
5. the already-known `E1 -> D1` answer survives that extension.

The assertions found no counterexample to these selected laws:

```text
same Event->Day relation
  -> same day projection

preserved attachment for an already-known Event
  -> preserved temporal answer

missing attachment
  -> no invented valid day
```

## Interpretation boundary

The bounded result supports this qualified separation:

```text
Event core
  does not determine valid-day knowledge

EventId + temporal evidence
  can determine valid-day projection
```

For the selected query vocabulary, physical embedding is not observable once the derived Event-to-Day relation is the same. So the query does not force valid time to live inside Event.

The result also shows a retained Event can move from temporal `Unknown` to a known valid day by extending an attachment layer while its Event payload remains unchanged in the model.

This connects naturally to Application 006's conservative typed-fact extension result: later canonical information may be added without retroactively changing the meaning of existing Event/Correction facts or old projections.

But this observation does **not** prove that an external fact family is universally better. An embedded representation may still be valid for a different vocabulary or implementation boundary.

The experiment establishes only that embedding is not semantically forced by the selected queries.

## Important boundary

The model does not yet include correction of a mistaken valid day.

That is intentional. If valid-day evidence can be attached independently, the next pressure is whether temporal evidence itself can remain append-only when later corrected:

```text
first learned: E0 -> D1
later learned: actually E0 -> D0
```

That question should reconnect the time chapter with LOAM's correction/frontier work rather than being smuggled into this observation.

## Non-goals

Observation 095 does not earn:

- a production Event `validDay` field;
- a production temporal fact type;
- a separate persistence stream;
- a universal metadata framework;
- temporal correction semantics;
- learned-time persistence;
- timestamps, timezones, or total chronology;
- CurrentQuantity, CLI, or wire-format changes;
- any rewrite of existing Event meaning.

## Practical Core impact

None.
