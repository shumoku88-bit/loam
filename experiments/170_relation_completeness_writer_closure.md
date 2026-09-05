# Observation 170 — Relation completeness writer closure

Observation 169 found a compact candidate for ordinary known-none relation state:

```text
covered valid-time
+ no positive relation fact
+ qualified completeness contract
-> known-none
```

That compression is sound only if every canonical path capable of making an Event current in the covered valid-time region is relation-complete or fails closed.

This observation audits the actual production entrances on current main before any relation-plane implementation is proposed.

## Current production surface audit

The executable list in `lakefile.lean` and direct persistence call-site search give a finite mutation surface.

### EventMemory publishers

Production calls to `saveEventMemory?` occur in:

1. `Loam/Cli.lean`
   - low-level `event-memory add`;
2. `Loam/Cli/MovementCli.lean`
   - practical balanced movement publication;
3. `Loam/Cli/CorrectionCli.lean`
   - replacement Event publication;
4. `Loam/Cli/ScheduledCli.lean`
   - Scheduled completion Actual publication.

The one-time `HistoricalPublisher` commits a sealed EventMemory candidate by approved-byte publication rather than by calling `saveEventMemory?` directly.

### ActualValidity publishers

Production calls to `saveActualValidityHistory?` occur in:

1. `MovementCli`;
2. `ActualValidityCorrectionCli`;
3. `CorrectionCli`;
4. `ScheduledCli`.

The historical publisher again publishes a sealed candidate stream directly.

This second list matters because valid-time completeness can be crossed without creating a new Event. `correct-date` can attach the first date to a previously undated Event or move an existing current validity frontier to a different date.

### Non-canonical observers

The shadow/query family does not publish canonical EventMemory. For example `ShadowQuantityCli` creates run-local identities only, writes no LOAM persistence, and discards them on exit. Such read-only paths do not threaten a canonical completeness cutover.

`HistoricalPrepare` is staging/qualification input. The authoritative historical mutation is the separately locked/sealed `HistoricalPublisher`.

## Pressure 1 — fresh practical writers are not relation-complete today

`MovementCli` and Scheduled completion already have strong publication shapes:

```text
supporting evidence first
-> Event last as authority commit
```

and both use existing writer ownership.

That is promising because future positive relation evidence could be admitted before the Event commit without inventing a second transaction framework.

But current code does not yet collect, validate, or publish relation meaning. Therefore a completeness cutover cannot be declared over their covered dates today.

The Alloy probes `blindMovementBreaksCutover` and `blindScheduledCompletionBreaksCutover` model exactly this gap.

## Pressure 2 — replacement Event needs its own relation qualification

`CorrectionCli` creates a fresh replacement EventId. When the target has a current occurrence date, the writer explicitly carries that date to the replacement because EventCorrection itself does not imply equal dates.

Relation evidence from Observations 166–169 is likewise anchored to source Event/Effect identity. A target relation therefore does not automatically attach to a replacement Event.

The dangerous shape is:

```text
target Event
  positive relation edge
  covered valid-time
        |
        | EventCorrection
        v
replacement Event
  same covered valid-time
  no replacement relation evidence
```

If the correction publisher is not independently relation-complete, Observation 169's absence rule would misread the replacement as known-none.

So the minimum rule is not `qualified original -> qualified replacement`.

It is:

```text
replacement publication
-> carry / translate / re-ask relation meaning as needed
-> qualify replacement independently
```

The observation does not decide whether practical correction should preserve, edit, or explicitly re-confirm relation meaning. It only says silence cannot inherit authority.

## Pressure 3 — date correction can cross the cutover without Event publication

`ActualValidityCorrectionCli` can:

- add the first validity fact to an older undated Event;
- move an Event from one current valid date to another.

Therefore this sequence is currently possible in shape:

```text
low-level EventMemory add
  relation meaning unqualified / unknown
        |
        | later correct-date
        v
covered valid-time
```

No EventMemory publication occurs at the boundary crossing itself.

A valid-time cutover is therefore unsound unless `correct-date` also becomes relation-complete whenever its operation would move an Event into the covered region.

The same applies to a dated legacy Event whose date correction crosses from the legacy region into the covered region.

## Pressure 4 — low-level add is not itself the whole problem

A generic undated Event in EventMemory is not yet a covered Actual merely because it exists.

The risk appears when another canonical path gives it covered Actual validity.

So Observation 170 does not require deleting generic low-level Event construction merely to protect the cutover. A smaller boundary is possible:

```text
low-level Event may exist undated
+
covered-validity admission must be relation-complete
```

However, any low-level route that can publish both Event and covered validity without the qualified gate would have to be removed, guarded, or kept outside supported production operation.

## Pressure 5 — historical publisher can stay outside the cutover

The historical publisher is explicit one-time authority-cutover machinery, not a permanent import framework.

If the relation completeness boundary is chosen strictly after the maximum valid-time admitted by the sealed historical publication, historical Events remain in the legacy region:

```text
historical covered by old source migration
-> relation absence remains unknown
```

No historical negative-relation backfill is required.

If historical publication were ever allowed to introduce Events whose valid-time lies inside the completeness-covered region, then that publisher would also need relation qualification. The cutover date does not exempt a writer merely because it is called historical.

## Alloy abstraction

The bounded model deliberately collapses Effect detail to representative Event meaning. Observation 166 already established the finer production anchor pressure. Observation 170 asks only whether the gate that makes a record current in the covered valid-time region is qualified.

Observation-local coverage gates are:

- Movement;
- Scheduled completion;
- movement correction replacement;
- date correction / first-date admission;
- historical publication.

A gate is `qualified` when, for covered valid-time, it emits positive relation evidence exactly when the retained meaning is a directed edge. This does not require a stored negative fact.

Expected probes:

```text
blindMovementBreaksCutover                    SAT
blindScheduledCompletionBreaksCutover         SAT
correctionReplacementNeedsOwnQualification    SAT
lowLevelThenDateCorrectionCanCrossCutover     SAT
dateCorrectionQualificationIsIndependentOfSource SAT
historicalPublisherCanRemainOutsideCoveredRegion SAT
historicalPublisherWouldNeedQualificationIfCovered SAT

QualifiedCoveredAbsenceMeansNoEdge            UNSAT counterexample
ClosedCoveredFrontierIsSound                  UNSAT counterexample
LegacyAbsenceMeansNoEdge                      SAT counterexample
```

## Candidate writer-closure rule

For a valid-time completeness cutover to become production truth:

```text
for every operation that can establish current covered Actual validity:
  either
    relation-complete gate
  or
    fail closed / impossible in that region
```

On the current executable surface this means qualifying, or deliberately excluding from covered admission:

1. practical movement publication;
2. Scheduled completion Actual publication;
3. movement correction replacement publication;
4. first-date/date-correction publication;
5. historical publication if it can reach the covered region.

Read-only shadows and queries are outside this closure because they do not mutate canonical state.

## Architectural consequence

The interesting pressure is toward one shared **Actual admission capability**, not toward a universal Relation framework.

Current writers already converge on two useful facts:

- EventMemory writer ownership is a shared serialization boundary;
- Event is commonly published after supporting evidence as the authority commit.

A future small refactor could make relation completeness one requirement of the same admission capability, rather than duplicating policy across every UI.

But this observation does **not** yet earn:

- production RelationFact types;
- a generic transaction manager;
- per-Event completeness receipts;
- admission-generation metadata;
- a global ordered history;
- automatic relation inheritance across EventCorrection;
- negative relation facts;
- a concrete cutover date.

The immediate result is narrower:

> The cutover is implementable only after writer closure. Current main has a finite, auditable set of relevant mutation paths, but that set is not relation-complete yet.
