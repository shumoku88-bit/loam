# Observation 105 — Can scheduled lifecycle collapse into one edge shape?

## Question

The household capability inventory puts scheduled occurrence lifecycle before recurrence, Envelope, Issue, and report work.

LOAM already has several pieces of evidence around this boundary:

- Observation 063 showed that scheduled/Plan content and Actual/Event content do not determine which Actual realizes which expectation. Explicit realization linkage carries independent information.
- Observation 064 showed that recurrence fields do not determine Series grouping.
- Application 013 showed that a selected-day scheduled view can stay much smaller than a full planning subsystem: stable scheduled identity + day + neutral Effects + explicit completion/retirement evidence + a known-through horizon are enough for the question it asks.

The next compression question is therefore not whether LOAM should copy a `Plan` object or mutable `Plan.status`.

It is:

> Can completion, cancellation, and reschedule/supersession share one generic lifecycle-evidence shape, with user-facing lifecycle states derived as projections?

## Candidate compression

The experiment keeps only these endpoint kinds:

```text
Scheduled
Movement
```

and one lifecycle evidence shape:

```text
LifecycleEdge
  source  : Scheduled
  target  : optional Endpoint
  knownOn : Day
```

The meaning is induced by the target shape:

```text
target = Movement
    -> completed / realized

target = Scheduled
    -> superseded / rescheduled

target = none
    -> retired / cancelled
```

There is no stored lifecycle status enum and no stored operation kind such as `postpone`, `advance`, or `edit`.

For the first bounded model, one scheduled identity has at most one terminal lifecycle edge. Completion remains one-to-one with Movement, matching the current pressure retained in Observation 063. Replacement is also one-to-one and acyclic. Those are boundaries, not permanent claims.

## Derived views

From visible lifecycle evidence through `knownThrough`, the model derives:

```text
completed
retired
superseded
terminal
live scheduled
selected-day open
overdue
due today
upcoming
postponed
advanced
same-day replacement
```

`postponed` and `advanced` are not operation tags. They are simply the direction of the scheduled-day change across a replacement edge.

The model also keeps `knownOn` separate from the scheduled day. Therefore terminal evidence that exists globally but is learned after the query horizon does not close the occurrence at the earlier horizon.

## Why Alloy

This is a bounded structural question:

- can the same compact edge vocabulary express representative lifecycle outcomes?
- is an open/closed summary sufficient to recover lifecycle meaning?
- is even a completed/retired/superseded status classification sufficient to recover replacement provenance?
- once the decoded relations are fixed, are the selected lifecycle views fixed?

No concurrent protocol or transition interleaving is required yet. TLA+ would be premature. Lean should wait unless a reusable law survives this structural pressure.

## Probes

### 1. Representative lifecycle can coexist

The model asks one world to contain:

- a completed scheduled occurrence;
- a cancelled/retired occurrence;
- an occurrence replaced by another scheduled occurrence;
- the replacement still open;
- one overdue open occurrence;
- one upcoming open occurrence.

Expected: **SAT**.

### 2. Future-known evidence leaves the earlier view open

A lifecycle edge can exist but have `knownOn > knownThrough`. Its source should still be open in the earlier query view.

Expected: **SAT**.

### 3. Same open/closed set can hide different terminal meaning

Two worlds keep the same open set and same terminal set while disagreeing about whether a terminal occurrence was completed, retired, or superseded.

Expected: **SAT**.

This tests whether a mutable `open/closed` bit would be too coarse.

### 4. Same status kinds can still lose successor provenance

Two worlds keep the same sets of completed, retired, superseded, and open identities while using different `Scheduled -> Scheduled` successor relations.

Expected: **SAT**.

This tests whether even an enum-like status projection is enough when the household later asks which occurrence replaced which one.

### 5. Postpone and advance need no stored operation kind

One world contains both a replacement whose new day is later and another whose new day is earlier.

Expected: **SAT**.

The distinction is derived from the replacement relation plus scheduled days.

## Checks

The expected checks are:

```text
ClosedSummaryDeterminesLifecycleMeaning          SAT counterexample
StatusKindsDetermineSuccessorProvenance          SAT counterexample
DecodedLifecycleDeterminesSelectedViews          UNSAT counterexample
TerminalKindsPartitionTerminal                   UNSAT counterexample
TemporalViewsPartitionOpen                       UNSAT counterexample
```

The first two are deliberately false candidate compression laws. The last three are expected to hold in the bounded model.

## What a successful observation would mean

If all expected witnesses and checks hold, the useful compression is:

```text
mutable Plan lifecycle state
        is not required for these views

one generic lifecycle evidence shape
        + endpoint kind / absence
        + scheduled day
        + known-through horizon
        -> selected lifecycle projections
```

It would also show that two tempting smaller summaries are too small:

```text
open / closed
    loses terminal meaning

completed / retired / superseded status sets
    can still lose successor provenance
```

So the compact boundary would not be "store status". It would be "retain the relation that future questions actually observe, then derive status from it."

## Important boundaries

Observation 105 does not establish:

- that `LifecycleEdge` belongs in Practical Core;
- a persistence format;
- a practical scheduled writer;
- recurrence generation or Series lifecycle;
- partial or many-to-many realization;
- split or merged rescheduling;
- multiple competing lifecycle edges for one occurrence;
- correction of lifecycle evidence;
- separate valid-time and learned-time semantics beyond the one `knownOn` pressure used here;
- amount, description, or Effect changes across replacement;
- that cancellation and retirement must be permanently synonymous;
- that every successor day change should be presented to the user as `postpone` or `advance`.

Those distinctions should be earned by later household questions rather than folded into this experiment in advance.

## Next pressure if this survives

The natural follow-up is practical rather than ontological:

> Is `scheduled identity + day + neutral Effects + one lifecycle-evidence family` sufficient to implement the ordinary scheduled operations we actually need: create, complete as Movement, reschedule/edit, cancel, and overdue/upcoming projection?

Only after that should recurrence generation or Envelope commitment depend on the result.
