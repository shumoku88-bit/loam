# Observation 146 — Which historical-admission identities are structural, and which are migration debt?

## Question

Historical admission produced durable opaque identities under migration-shaped spellings such as:

```text
hpev-...
hpef-...
hpvf-...
```

The concrete spelling is easy to dislike, but deleting identity just because a migration issued it would risk erasing previously earned provenance laws.

This observation therefore asks a narrower question:

> Which identity is independently required by LOAM semantics, and which identity is only being allocated eagerly because of the current persistence shape?

The observation separates:

1. Event identity;
2. Effect identity;
3. Actual-validity fact identity.

It does **not** rewrite canonical household data or change production Core/Persistence.

## Existing boundaries

### Event identity predates historical admission

`EventId` and `EventMemory` were already practical Core concepts before historical migration. Later evidence families use Event identity as a join/reference boundary, including:

- ActualValidity;
- EventDescription;
- EventCorrection;
- Scheduled completion identity.

Historical admission therefore did not create the need for Event identity. It only issued a particular batch of destination-side opaque EventId values.

### Effect identity also predates historical admission

Observation 052 separated Effect identity from `(Locus, Measure)` coordinates, and Observation 067 later showed why that distinction matters under disposal-provenance pressure: two acquisition-specific Effects can share the same aggregate coordinate while a later relation still needs to refer to one specific Effect.

Historical admission again issued concrete destination-side EffectKey values; it did not create the already-earned identity boundary.

### ActualValidityFactId is different

The first practical date retention used an Event-keyed occurrence coordinate. Append-only date correction later introduced identified `ActualValidityFact` nodes so correction relations could target one retained temporal claim without using list order as authority.

The current shape therefore pays for one `ActualValidityFactId` even when an Event's occurrence date is never corrected.

Observation 146 asks whether that eager allocation is necessary.

## Candidate: Event-rooted temporal history

Instead of representing the first occurrence date as an independently identified fact:

```text
ValidityFactId -> Event -> Date
```

the candidate uses the Event itself as the root temporal node:

```text
Event -> initial Date
```

Only when a later correction exists does LOAM allocate a separate temporal revision identity:

```text
Event
  -> Revision 1
  -> Revision 2
  -> ...
```

The correction relation still defines authority. List/file order does not.

A revision retains:

- one owning Event;
- one replacement date;
- stable identity because later correction may need to target that exact retained revision.

This is **identity on correction**, not last-write-wins.

## Alloy model

`146_migration_identity_retirement.als` compares the relevant distinctions.

The bounded model contains:

- distinct Events that may share the same payload and occurrence date;
- distinct Effects that may share the same owner/coordinate/value;
- Event correction targeting;
- Effect provenance targeting;
- Event-rooted temporal revision paths;
- a competing date-value-only correction graph.

The rooted temporal admission keeps the same conservative shape used elsewhere in LOAM:

- one target has at most one replacement;
- one replacement has at most one predecessor;
- corrections stay within one Event;
- cycles are rejected;
- every retained revision is reachable from its Event root;
- one admitted terminal/current temporal node exists per Event.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced:

```text
sameEventShapeDifferentCorrectionRole          SAT
sameEffectCoordinatesDifferentProvenanceRole  SAT
uncorrectedEventNeedsNoRevision                SAT
returnToOriginalDateWithOnDemandRevisions      SAT
identityFreeReturnToOriginalDate               UNSAT
siblingRootedCorrectionsRefused                SAT
RootedAdmissibleDeterminesOneCurrentTime       UNSAT counterexample
RootedNoCorrectionReturnsBaseTime              UNSAT counterexample
```

The expected-result checker passed on the exact observation head after one syntax-only fix that renamed a witness variable which shadowed the `replacement` field. The semantic hypotheses did not change.

## Result 1: Event identity remains structural

Alloy found two distinct Events with the same payload and the same occurrence date where one Event is the target of a correction and the other is not.

Observed: **SAT**.

Therefore:

```text
Event content + date
    !=
Event identity
```

If the two Events were collapsed by content/date, the later correction could not say which occurrence it corrects.

So Observation 146 does **not** earn removal of EventId.

What it does say about historical admission is narrower:

> the `hpev-...` spelling and long opaque payload are migration-issued representation; the need for stable Event identity is not migration debt.

A future compact re-keying would be an identity-preserving rewrite problem, not an EventId deletion.

## Result 2: Effect identity remains structural

Alloy found two distinct Effects inside the same Event with identical selected coordinates/value where one Effect is the source of a provenance relation and the other is not.

Observed: **SAT**.

Therefore:

```text
Effect coordinate/value
    !=
Effect identity
```

This agrees with Observations 052 and 067.

So Observation 146 does **not** earn removal of EffectKey.

Again the concrete historical spelling is separate:

> the `hpef-...` spelling and long opaque payload are migration-issued representation; stable Effect identity remains independently earned.

This observation also does not weaken the current convention that EffectKey may be used directly as a later relation endpoint. Any attempt to reduce its namespace or scope needs a separate endpoint audit.

## Result 3: the initial ActualValidityFactId can be avoided

The Event-rooted model admits an uncorrected Event with:

```text
Event -> base date
Revision identities: 0
```

Observed: **SAT**.

The no-correction assertion also found no counterexample: in every admitted no-correction case, the current date is exactly the Event's base date.

Therefore an independently identified temporal fact is **not required merely to retain the first date**.

This is the strongest compression result of Observation 146.

## Result 4: temporal identity cannot disappear completely

A tempting stronger design would identify temporal claims only by `(Event, Date)` and never allocate a revision identity.

That fails a simple real correction history:

```text
A -> B -> A
```

For example, an Event may first be recorded on date A, corrected to B, then later corrected back to A. Those are three retained claims even though the first and third carry the same date value.

If date value itself is node identity, the history collapses to:

```text
A -> B -> A
```

which is a cycle and cannot distinguish the first A claim from the later A claim.

Alloy result:

```text
identityFreeReturnToOriginalDate  UNSAT
```

But the Event-rooted/on-demand model represents the same history as:

```text
Event(base A) -> Revision(B) -> Revision(A)
```

without a cycle.

Observed: **SAT**.

Therefore the selected boundary is:

```text
identity for every initial date fact
    not required

identity for later correction revisions
    still required
```

## Result 5: identity-on-correction does not reintroduce arrival-order authority

The model deliberately permits a raw sibling shape to be constructed and checks that the rooted admission rejects it rather than choosing the later/list-last branch.

Observed sibling witness: **SAT**, with `rootedAdmissible` false.

For admitted rooted histories, Alloy found no counterexample to:

- exactly one current temporal answer per Event;
- the base date being current when no correction exists.

So the smaller candidate does not require last-write-wins or list position to decide currentness.

## Classification

| Historical-admission shape | Observation 146 classification | Why |
|---|---|---|
| `hpev-...` concrete token spelling | rewrite / re-key candidate | spelling and long random-looking payload are migration representation |
| EventId concept | **retain** | separate evidence and corrections need a stable occurrence reference |
| `hpef-...` concrete token spelling | rewrite / re-key candidate | spelling and payload are migration representation |
| EffectKey concept | **retain** | coordinate/value can collide while later provenance distinguishes Effects |
| `hpvf-...` concrete token spelling | **rewrite candidate** | migration-specific spelling is not semantic |
| one ActualValidityFactId for every initial date | **compression candidate** | Event itself can be the temporal root when uncorrected |
| identity for later date revisions | **retain on demand** | repeated equal date values need distinct retained claims |

## Important distinction: deleting a token versus re-keying identity

The model does **not** earn arbitrary replacement of existing canonical identity strings.

Stable identity is observable by:

- cross-stream joins;
- correction endpoints;
- description/date attachment;
- any external or future retained reference.

Therefore removing the migration-shaped spelling from existing canonical data would require one exact, all-references re-keying operation or a persistence rewrite with an explicitly qualified authority boundary.

Observation 078's run-local identity-renaming result does not authorize that persistent rewrite: it applies only to queries already proved invariant under identity renaming and explicitly excludes persistent relation targets/continuity.

## What this observation earns

It earns a narrower next design question:

> Can production ActualValidity be rewritten so the Event carries/anchors the initial occurrence-valid coordinate while only corrected replacements receive explicit revision identity, without changing current household answers or weakening append-only/fail-closed correction semantics?

It also justifies treating the concrete `hpev-`, `hpef-`, and `hpvf-` spellings as migration residue rather than domain vocabulary.

## What this observation does not earn

- no canonical-data rewrite;
- no deletion of EventId;
- no deletion of EffectKey;
- no removal of temporal revision identity;
- no last-write-wins date semantics;
- no mutation/deletion of retained correction evidence;
- no assumption that identity strings can be changed independently of all references;
- no retirement of the historical admission snapshot or receipt;
- no change to migration publisher/recovery code.

## Production impact

None.

```text
Core changes:              0
Persistence changes:       0
Canonical household writes:0
Migration retirement:      not yet
```

Observation 146 is a compression qualification, not the cleanup operation itself.
