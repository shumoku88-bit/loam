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

## Expected boundaries

The experiment asks whether Alloy can show:

1. an embedded relation and an attached relation can encode the same Event-to-Day mapping;
2. when the relation is the same, the selected day query is the same;
3. stable Event payload does not by itself determine the temporal answer;
4. an Event may remain retained while its valid day is still unknown;
5. a later attached fact can move one Event from `Unknown` to a known day while preserving an already-known temporal answer for another Event;
6. missing attachment remains `Unknown` rather than inventing a day.

## Interpretation boundary

If those results hold, the selected temporal vocabulary does not force valid time to be physically embedded inside Event.

That would support this qualified statement:

```text
Event core
  does not determine valid-day knowledge

EventId + temporal evidence
  can determine valid-day projection
```

It would also connect naturally to Application 006's conservative typed-fact extension result: later canonical information may be added without retroactively changing the meaning of existing Event/Correction facts or old projections.

But this observation does **not** prove that an external fact family is universally better. An embedded representation may still be valid for a different vocabulary or implementation boundary.

The experiment asks only whether embedding is semantically forced by the selected queries.

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
