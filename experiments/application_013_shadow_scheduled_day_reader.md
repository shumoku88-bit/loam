# Application 013 — Stateless scheduled-day reader

## Question

Application 012 showed that one recorded Actual day can be read from a journal-shaped canonical source without importing the source ontology into LOAM Core.

The next household-facing question is narrower than the full Planned Payments report:

> Which still-open scheduled occurrences belong to one selected day, using only evidence visible through a known-through horizon?

This is the same question exercised by a calendar/home-style day view. It is deliberately not a recurrence engine, a complete Plan model, or a full report of overdue/upcoming obligations.

## Existing evidence

Observation 063 already established that Plan-to-Actual realization cannot be inferred from matching date, amount, description, or physical shape. Application 013 therefore does not repeat that experiment. It treats explicit source completion identity as required evidence.

The source-pressure shape used here is:

```text
scheduled identity + scheduled day + neutral Effects
                         +
          explicit completion / retirement evidence
                         +
                  known-through horizon
                         ↓
                       open?
                         ↓
              scheduled day = selected day
```

## Boundary

`Loam/ShadowScheduledDayCli.lean` is a read-only adapter. It does not add a Plan type to LOAM Core.

The adapter retains only the distinctions observed by this question:

- one source-stable scheduled identity, used only to resolve explicit completion evidence;
- one scheduled day;
- human context for presentation;
- neutral LOAM `Event` / `Effect` quantity shape with run-local identity;
- optional cancellation or supersession date;
- explicit Actual-side completion identity and its recorded day;
- a caller-supplied known-through horizon and selected day.

The adapter deliberately ignores recurrence classification, Series membership, cashflow classification, AccountType, account declarations, schedule generation, and report policy. Those source distinctions remain available to future question-specific adapters if a later operation actually observes them.

## Open-at-horizon law

A scheduled occurrence is visible in the selected-day result when:

```text
scheduled day = selected day
and
no explicit completion is visible through known-through
and
no cancellation / supersession is visible through known-through
```

An explicit completion after the known-through horizon does not close the occurrence at the earlier horizon. The same is true for later retirement evidence.

The adapter refuses completion for an unknown scheduled identity, duplicate completion for one identity, duplicate scheduled identity, or simultaneous completion and retirement evidence. It never reconstructs completion from content matching.

## Why this does not import HRA ontology

The application asks one semantic question and retains only the evidence that changes that answer.

In particular:

```text
source AccountType       -> not imported
source recurrence        -> not imported
source Series            -> not imported
source Plan report roles -> not imported
LOAM Core Date           -> not introduced
LOAM Core Plan           -> not introduced
LOAM persistence         -> not introduced
```

The source-specific adapter can be removed without changing LOAM Core.

## Deliberate limits

Application 013 does not establish:

- a canonical LOAM Plan fact family;
- recurrence generation;
- Series semantics;
- partial, split, or merged realization;
- a full overdue / due-today / upcoming report;
- Account-based payment classification;
- include traversal;
- write authority over the canonical source;
- lossless import.

Source `include` directives are reported but not followed. Both source files remain byte-for-byte unchanged and no LOAM persistence is written.

## Result sought

If the synthetic qualification succeeds, the useful compression is:

```text
calendar scheduled-day question
        !=
full planning subsystem
```

A day view can depend on stable scheduled identity plus explicit terminal evidence without forcing the wider source ontology into the neutral LOAM Core.
