# LOAM household compression status

Status: checkpoint attached to the whole-household evidence graph

This file keeps qualified observations separate from currently unqualified specimens so the research map does not silently turn expected results into established design.

## Qualified cross-capability observations

### Observation 105 — Scheduled lifecycle edge

Qualified on PR #237.

The bounded result supports a compact Scheduled lifecycle shape where completion, retirement, and replacement can be decoded from explicit lifecycle relation evidence rather than a stored mutable status. A coarse open/closed summary and even a completed/retired/superseded status set lose successor provenance.

Practical implementation remains deferred until the whole-household compression pass is complete.

### Observation 106 — Actual / Capacity movement plane

Qualified on PR #239.

One signed Effect algebra can be reused across Actual value movement and Capacity / Entitlement movement, but the semantic plane cannot be erased. Endpoint shape can derive grant / reallocation / release labels for the admitted Capacity vocabulary.

Current boundary:

```text
shared Effect algebra      yes
shared semantic meaning    no
stored operation-kind enum not required by the bounded answers
```

### Observation 107 — shared historical routing shape

Qualified on PR #240, final exact head `3fc5d3c7f5a9eb3ba4ffa85fd3ca673986a75407`.

One historical `subject -> purpose-or-none` record shape can serve Actual-side and Scheduled-side routing, but subject meaning remains necessary. Current routing alone loses historical answers. An explicit later no-purpose record can make a subject unmanaged without rewriting earlier routing.

Current boundary:

```text
shared routing history shape     yes
current-only routing table       too small
subject meaning erased           too small
history + subject meaning        sufficient for selected bounded projections
```

Observations 106 and 107 therefore expose the same wider compression pattern:

> Reuse algebra and evidence mechanics where possible, but keep the semantic partition when erasing it changes household answers.

## Unqualified specimens

### Observation 108 — Scheduled + routing -> Commitment

Draft PR #241 contains the Alloy specimen and note.

Question:

> Once Scheduled expectation, lifecycle evidence, and historical Purpose routing already survive, does practical Envelope Commitment require a separately retained Commitment fact?

The model pressures managed, explicitly-unmanaged, and unrouted commitment; overdue-open behavior; period end-exclusive horizon; and later-known terminal evidence not rewriting an earlier observation.

**No result is established yet.** New GitHub Actions workflow creation was blocked by connector safety checks and the available execution environment could not obtain Alloy 6.2.0. The PR remains Draft and unqualified.

### Observation 109 — Attention lifecycle boundary

Draft PR #242 contains the Alloy specimen and note.

Current HRA / h-kernel reality pressure says an Issue relation such as realization or continuation is append-only provenance and does not itself close the Issue. Issue lifecycle also distinguishes Resolved from Dropped and NoDueDate from DueUndetermined.

Observation 109 therefore pressures the tempting over-compression:

```text
Scheduled relation target -> lifecycle meaning
Attention relation target -> same lifecycle meaning
```

The candidate boundary is instead:

```text
shared source / target / known-through mechanics     potentially reusable
one universal target-decoded lifecycle algebra       likely too small
Attention relation provenance                         independent from closure
closed boolean                                         potentially too small
optional due date                                      potentially too small
```

**These are hypotheses, not findings, until the exact Alloy specimen is executed.**

## Current candidate minimum vocabulary

Only qualified results should constrain this list. Unqualified observations are marked as pressure, not accepted structure.

```text
quantity-bearing evidence
  Actual movement
  Capacity movement        [semantic plane required by Obs 106]
  Scheduled expectation    [lifecycle structure pressured by Obs 105]

other independently observed evidence
  Quantity basis / cut / correction
  explicit semantic relations
  historical routing       [shared shape + subject meaning, Obs 107]
  temporal coordinates
  replaceable current policy
  backing topology         [still largely unobserved]
  Attention                [distinct-plane pressure; Obs 109 pending]
```

The following remain projection candidates rather than retained fact families:

```text
balance
history windows
overdue / upcoming
consumption
fulfillment
commitment                 [Obs 108 pending]
remaining
headroom
backing position
spending pace
statement sections
calendar
home
```

## Research gate before practical Lean implementation

Do not implement Scheduled, Capacity, routing, Commitment, or Attention as a new practical ownership graph merely because a source system already has those nouns.

The next gate is:

```text
qualify Observation 108
qualify Observation 109
        |
        v
review minimum independently observable vocabulary
        |
        v
only then choose Lean ownership / persistence boundaries
```

If either pending Alloy observation produces a counterexample, update the candidate vocabulary before practical implementation rather than patching the production design afterward.
