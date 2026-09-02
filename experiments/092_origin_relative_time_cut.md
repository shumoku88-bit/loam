# Observation 092 — How much temporal order does one origin need?

## Question

Observation 091 showed that application-start basis and first-event admission can share exact

```text
origin quantity + scoped activity
```

arithmetic, but first-event current still needs activity already scoped to its origin.

The Core deliberately gives neither Event storage order nor `EventId` a temporal meaning.

So the next question is narrower than “should Event have a timestamp?”:

> For one selected first-event origin, what temporal information is sufficient to decide which retained Events belong before, at, or after that origin?

## Existing time observations

LOAM has already observed richer temporal questions elsewhere:

- Observation 034 introduced an explicit time coordinate for relation history;
- Observation 035 separated valid time from learned time;
- Observation 038 showed that selected historical views can be preserved by sparse change points;
- Observation 039 factored a sparse temporal index from a separate explanation graph.

Observation 092 does not reopen those conclusions. It asks only about the new quantity-origin pressure exposed by Observation 091.

## Candidate memories

The Alloy model gives every bounded world three retained Events:

```text
Origin
X
Y
```

and an underlying strict total order used only as the experiment's reference temporal meaning.

It compares five information shapes.

### A. Unordered retained snapshot

```text
origin Event identity
+ retained Event set
```

This is close to what Observation 091 currently has available.

### B. Coarse time coordinate

Every Event receives an ordered `Moment`, but several Events may share the same Moment.

This stands for information shaped like a day, second, timestamp bucket, or any other non-injective temporal coordinate.

The coordinate is required not to run backward relative to the reference order, but ties are allowed.

### C. Injective monotone time coordinate

The same scalar coordinate becomes unique per Event.

In this bounded model, an injective monotone coordinate carries enough information to reconstruct the strict Event order.

This is intentionally a strong premise. Observation 092 does not assume real timestamps are globally unique or that their authority/meaning has already been earned.

### D. Origin-relative cut

Instead of ordering every Event against every other Event, retain only its relation to the selected origin:

```text
Before
At
After
```

The experiment asks whether this smaller relation is sufficient for the selected post-origin scope.

### E. Global total chronology

The experiment's reference order fully orders every Event pair.

This is sufficient by construction, but may preserve distinctions irrelevant to the one-origin current query.

## Derived query

The selected quantity scope is:

```text
postOrigin(origin)
  = origin Event
  + every Event strictly after it
```

The origin-relative candidate instead derives:

```text
postByCut(origin)
  = every Event classified At or After
```

No quantity arithmetic is needed here. Observation 091 already exposed the arithmetic boundary. Observation 092 isolates only Event membership in the scoped activity set.

## Expected Alloy witnesses

The model asks for these positive witnesses:

```text
injectiveTimeWitness
sameUnorderedSnapshotDifferentPostOrigin
sameCoarseTimeDifferentPostOrigin
sameCutDifferentGlobalOrder
```

The important intended shapes are:

```text
same retained Events
same origin Event
    but different post-origin set
```

and:

```text
same coarse time coordinates
one Event tied with Origin
    but different post-origin set
```

The second witness tests the boundary that a timestamp-like coordinate with ties cannot necessarily decide which tied Event is before or after the origin.

The final witness asks whether two worlds can have the same origin-relative cut while disagreeing about the order of `X` and `Y` on the same side of the origin. If SAT, global chronology carries more information than this one query consumes.

## Expected assertions

The model checks:

```text
UnorderedSnapshotDeterminesPostOrigin
CoarseTimeDeterminesPostOrigin
InjectiveMonotoneTimeDeterminesPostOrigin
OriginRelativeCutMatchesScope
OriginRelativeCutDeterminesPostOrigin
```

The intended boundary is:

```text
unordered retained Events
    -/-> post-origin scope

coarse temporal coordinate with ties
    -/-> post-origin scope

injective monotone temporal coordinate
    -> post-origin scope        [bounded, strong premise]

origin-relative before/at/after cut
    -> post-origin scope        [bounded]
```

while:

```text
origin-relative cut
    -/-> one global total chronology
```

## Why Alloy is earned here

This is a static information-sufficiency question over alternative relation shapes:

- can two worlds share one retained representation while requiring different scoped answers;
- does one candidate representation rule those collisions out;
- can a weaker representation preserve the selected answer while allowing unrelated chronology to vary?

Alloy is smaller than a transition model for those questions.

TLA+ may be earned later when admission, late recording, correction, or clock movement changes the temporal evidence through time.

## Important interpretation boundary

Even if the bounded result favors an origin-relative cut for this one query, it does **not** imply dates or times are unnecessary for LOAM.

Human-facing questions such as:

```text
what happened on 2026-09-02?
monthly activity
as-of a date
late-entered event valid yesterday
when did I learn this?
```

can require temporal coordinates that this one-origin cut cannot answer.

The question here is deliberately smaller:

> Must the first-event current projection itself force a global timestamp or total chronology into Event?

## Non-goals

Observation 092 does not earn:

- a production Event timestamp/date field;
- storage order as chronology;
- a production global total Event order;
- a production `Before/At/After` field;
- a generic Time type in Core;
- a choice between valid time and learned time for household Events;
- first-event Admission persistence;
- correction semantics for temporal evidence;
- a CurrentQuantity production change.

## Practical Core impact

None.

- no Core change;
- no Application production change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private household values committed.
