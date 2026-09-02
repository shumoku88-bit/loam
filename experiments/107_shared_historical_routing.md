# Observation 107: Can Actual and Scheduled questions share one historical routing shape?

## Question

The whole-household evidence map exposes routing as one of the highest-degree seams between HRA / h-kernel capabilities.

Current household behavior uses routing in at least two semantically different places:

```text
Actual-side subject @ effective day
    -> Purpose / unmanaged
    -> Consumption

Scheduled identity @ effective day
    -> Purpose / not-fulfillment
    -> Fulfillment and Commitment
```

The source systems keep distinct routing machinery because the subjects and downstream questions differ.

Before LOAM copies that split, the bounded question is:

> Can both use one time-indexed `subject -> purpose-or-none` evidence shape while retaining the subject meaning that distinguishes Actual-side and Scheduled-side questions?

This is not an attempt to create a universal metadata relation.

## Candidate compression

The model has one routing evidence type:

```text
RoutingEvidence
  subject
  effectiveOn
  purpose?
```

A missing `purpose` on an explicit evidence record means the subject is explicitly unmanaged / not routed from that effective day.

Each world also retains a semantic subject kind:

```text
ActualKind
ScheduledKind
```

The shared route history is read by subject kind to obtain two question-specific projections:

```text
actualRoutingAt
scheduledRoutingAt
```

The subject-kind distinction is deliberately separate from the routing record shape.

## Historical reading

At a query day, routing comes from the latest routing evidence visible on or before that day.

This means current routing does not automatically rewrite the past.

The model also admits an explicit later `purpose = none` record so that a subject can move from managed to unmanaged without deleting its earlier routing history.

## Probes

### 1. Shared routing history can serve both subject kinds

One world contains current routing for both an Actual-kind subject and a Scheduled-kind subject, plus at least one subject whose route changes across days.

Expected: **SAT**.

### 2. Current routing alone can hide different historical answers

Two worlds have the same current route projection at the final day and the same subject kinds, but disagree at an earlier day.

Expected: **SAT**.

This pressures retention of routing history rather than only a current classification table.

### 3. The same routing evidence can mean different downstream ownership when subject kind changes

Two worlds keep exactly the same routing evidence but classify subjects differently as Actual or Scheduled.

Expected: **SAT**.

This pressures an explicit subject distinction even if routing storage shape is shared.

### 4. Managed can become explicitly unmanaged append-only

A subject is routed to a Purpose at an earlier day and has no routed Purpose at a later day because the latest evidence explicitly carries no Purpose.

Expected: **SAT**.

## Checks

Expected results:

```text
CurrentRoutingDeterminesHistoricalRouting                       SAT counterexample
SharedRoutingEvidenceDeterminesTypedAnswersWithoutSubjectKind   SAT counterexample
ExplicitHistoryAndSubjectKindDetermineTypedAnswers              UNSAT counterexample
LatestRouteIsUnique                                             UNSAT counterexample
```

The first two candidate compression laws are deliberately too small.

The third asks whether one shared historical routing relation plus explicit subject meaning is sufficient for the selected bounded projections.

## Alloy result

Alloy 6.2.0 with Sat4j produced exactly the expected boundary:

```text
representativeSharedHistory                                     SAT
sameCurrentRoutingDifferentHistory                              SAT
sameRoutingEvidenceDifferentSubjectMeaning                      SAT
managedThenExplicitlyUnmanaged                                  SAT
CurrentRoutingDeterminesHistoricalRouting                       SAT counterexample
SharedRoutingEvidenceDeterminesTypedAnswersWithoutSubjectKind   SAT counterexample
ExplicitHistoryAndSubjectKindDetermineTypedAnswers              UNSAT counterexample
LatestRouteIsUnique                                             UNSAT counterexample
```

The first CI attempt did not reach the solver because the specimen used Alloy temporal keywords as local identifiers. Renaming those locals changed no modeled relation or expected result. The corrected exact-head run executed the Alloy model and the expected-result qualification successfully.

The result preserves two distinct pieces of information:

```text
historical route evidence
subject meaning
```

Neither the current route alone nor route history with the subject meaning erased is sufficient for the selected answers.

## Observed compression boundary

The bounded observation supports this smaller shape:

```text
shared time-indexed routing evidence
    yes

current-only routing table
    no

subject meaning erased
    no

separate routing algebra for each subject kind
    not required by these bounded answers
```

So Actual Consumption routing and Scheduled Fulfillment / Commitment routing can share an implementation shape without becoming the same semantic relation.

This repeats the boundary seen in Observation 106: reuse the small structure, but retain the independently observable semantic distinction.

## Important boundaries

Observation 107 does not establish:

- a Practical Core routing type;
- a Purpose registry;
- how Actual-side routing subjects are selected from neutral Effects;
- how Scheduled identities are stored practically;
- Commitment arithmetic;
- Consumption or Fulfillment quantity calculation;
- routing correction identity;
- valid-time distinct from learned-time for routing publication;
- concurrent routing publication;
- a generic metadata / tag / property framework.

Existing LOAM temporal observations already show that valid and learned coordinates can matter independently. This experiment keeps only the effective-day pressure needed for the cross-capability routing question.

## Next pressure

The next high-value cross-capability question is now concrete:

> Once an open Scheduled occurrence and its historical Purpose routing are retained, does Envelope Commitment require any additional canonical commitment fact?

That test can reuse the earlier commitment observations without reopening whether intention is derivable from physical history.
