# Relation / Discharge — D/P/R obligation scaffold

Status: **focused audit — KEEP CURRENT BOUNDARIES**

Date: 2026-09-19

Baseline:

```text
50df6aa3353573bc2e34661a04021f448ce44211
fix(merchant): make expense coverage query-relative (#1084)
```

Method: `docs/OBLIGATION_SCAFFOLD_METHOD.md`

## Root question

After the recent Relation / Discharge hardening, does production still need more
cross-family checks, proof-carrying structure, or reader semantics, or are the
remaining unanswered questions correctly outside the current production
surface?

The root decomposes into:

```text
Relation / Discharge
    |
    +--> O1 Relation source identity resolves exactly
    |
    +--> O2 Relation shape and quantity remain bounded
    |
    +--> O3 aggregate Relation coverage remains bounded per source Effect
    |
    +--> O4 Discharge resolves one current Relation target
    |
    +--> O5 Discharge quantity remains positive and aggregate-bounded
    |
    +--> O6 pre-Event discharge residue remains inert at the low-level frontier
    |
    +--> O7 canonical Actual retains only same-generation closed evidence
    |
    +--> O8 Correction / Reversal do not invent Relation mutation semantics
    |
    +--> O9 absence is not promoted to known-none without completeness
    |
    +--> O10 "later Event" does not silently acquire calendar-order meaning
    |
    +--> O11 no production reader claims current outstanding across
              unqualified Correction / Reversal overlap
```

## D — deterministic closure

### D1 — RelationUnit admission

`OpenRelationFrontier.admitRelationUnit?` deterministically requires:

- exact `(sourceEvent, sourceEffect)` resolution;
- one Household endpoint and one external endpoint;
- strictly positive Relation quantity;
- Relation quantity no larger than the absolute source-Effect magnitude.

The collection frontier separately requires:

- unique `RelationUnitId`;
- all current units source-admissible;
- aggregate Relation coverage on one source Effect no larger than that source
  magnitude.

No new theorem is needed merely to restate these executable checks.

### D2 — source-local relation projection

`currentRelationState?` does not turn uncovered clean absence into known
absence.

The result remains:

```text
knownPositive
knownNone      only when caller supplies completeAt
unknown        when completeness is not available
outer none     malformed / conflicting queried evidence
```

Repository reachability finds no production consumer that converts `unknown`
into a semantic `knownNone`.

### D3 — target-local discharge admission

`RelationDischargeFrontier` resolves one target through the already-qualified
Relation frontier and then admits only active discharge rows for that target.

For an activated row it requires:

- referenced Event exists;
- target RelationUnit resolves;
- discharge Event is not the Relation source Event;
- quantity is strictly positive;
- one row cannot exceed the target quantity;
- one active discharge Event per target;
- aggregate discharge does not exceed target quantity.

Rows for other RelationUnits remain irrelevant to the target-local answer.

### D4 — outstanding quantity is derived, not retained

`relationOutstandingQuantity?` is exactly:

```text
RelationUnit.quantity
-
sum(admitted activated discharge quantities)
```

There is no independently persisted Outstanding balance to synchronize.

### D5 — current production reachability

Repository code search at this baseline finds
`relationOutstandingQuantity?` only in:

- its Application definition;
- focused tests;
- normalized-persistence qualification;
- research documentation.

It has no TUI, report, or other user-facing production consumer.

Likewise, `currentRelationState?` is used by admission/publication machinery
and focused tests, not by a user-facing "no relation" presentation.

Therefore no current product surface is silently publishing an unqualified
cross-family current-outstanding answer.

## P — previously earned boundaries

### P1 — Event / Relation / Discharge factorization

Observations 165, 166, 172–178 and 182 already earned these distinctions:

```text
physical Event
!= open Relation meaning
!= Discharge provenance
!= stored outstanding state
```

Exact Discharge quantity is independent evidence. It is not inferred from
movement amount, date, endpoint, or sign.

### P2 — normalized Actual re-admission

Canonical normalized Actual owns same-generation reference closure.

On load / publication it rechecks:

- whole Relation frontier;
- every Discharge Event reference;
- every Discharge target Relation reference;
- target-local discharge admission for every retained RelationUnit.

The lower-level frontier's pre-Event crash-residue tolerance is therefore not a
license for canonical Actual to retain dangling selected-generation references.

### P3 — Correction / Reversal mutation guards

Recent writer hardening qualifies the four current mutation cases as
writer-local refusals:

| Retained provenance on Event | New operation | Current writer |
| --- | --- | --- |
| Relation source | Correction | refuse |
| Relation source | Reversal | refuse |
| RelationDischarge Event | Correction | refuse |
| RelationDischarge Event | Reversal | refuse |

These guards are intentionally not promoted into canonical decode rejection.
Historical retained families remain independently representable.

That distinction is already pinned by publisher regressions and normalized
persistence tests.

### P4 — Actual date remains an independent coordinate

Current Relation and Discharge semantics are identity-scoped, not ordered by the
current Actual occurrence date.

Date correction is allowed without rewriting Relation / Discharge provenance.
Observations 178 and 182 did not earn a calendar-order invariant for discharge.

Therefore the word "later" means the discharge occurrence Event in the semantic
correspondence, not a retained proof that its current `validOn` is later than the
source Event's current `validOn`.

## R — residuals

### R1 / semantic — current outstanding across Correction / Reversal overlap

Canonical history may represent independent Correction / Reversal and
Relation / Discharge provenance combinations that current practical writers
would refuse to create.

The low-level Relation outstanding projection intentionally does not consume
Correction or Reversal evidence.

Therefore this question remains unqualified:

> What should "current outstanding" mean if retained Relation or Discharge
> provenance participates in a historical Correction / Reversal overlap?

This is a real semantic residual, but there is currently no user-facing
production reader asking that question.

**Decision: KEEP RESIDUAL.**

Do not solve it pre-emptively by:

- deleting historical Relation / Discharge provenance;
- making normalized Actual reject independently retainable history;
- silently following Correction to a replacement Event;
- silently cancelling Relation / Discharge on Reversal;
- expanding `relationOutstandingQuantity?` to consume every Actual family.

Reopen only when a production query actually needs an answer.

### R2 / policy — Relation absence completeness

There is no promoted concrete completeness authority that can generally prove
that a queried source has no Relation evidence.

Accordingly `unknown` remains distinct from `knownNone`.

No current production surface requires a stronger answer.

**Decision: KEEP UNKNOWN.**

### R3 / terminology — "later Event"

The implementation and research prose frequently call the discharge endpoint a
"later Event". No calendar ordering is checked or required.

To avoid accidentally promoting prose into a future invariant, production
comments should state this explicitly.

This is documentation clarification only, not a semantic or runtime change.

### R4 / empirical — repeated relation admission inside canonical load

Normalized Actual admission first qualifies the whole Relation frontier and then
asks the target-local Discharge frontier once for every retained RelationUnit.

The target-local call deliberately rechecks Relation currentness because it is a
standalone Application boundary. Therefore canonical loading repeats some
Relation work after whole-family admission has already succeeded.

This is a plausible optimization seam, not a semantic gap.

Removing the repeated work cleanly would require either:

- a batch Relation/Discharge admission boundary; or
- a trusted way to consume an already-admitted Relation target without turning
  the current plain `AdmittedRelationUnit` read view into a forgeable capability
  entrance.

No measured production performance pressure currently justifies either
abstraction.

**Decision: MEASURE BEFORE OPTIMIZING.**

## D/P/R result

```text
D
├─ exact Relation source resolution
├─ endpoint / quantity / aggregate Relation bounds
├─ target-local Discharge activation
├─ positive / unique / aggregate Discharge bounds
├─ derived outstanding quantity
└─ no user-facing current-outstanding consumer

P
├─ Event / Relation / Discharge factorization
├─ normalized Actual same-generation re-admission
├─ writer-local Correction / Reversal refusal
└─ date-coordinate independence

R
├─ semantic: outstanding across historical Correction/Reversal overlap
│    -> no production consumer, keep unresolved
├─ policy: general Relation known-none completeness
│    -> no completeness authority, keep unknown
├─ terminology: "later" is not calendar ordering
│    -> clarify comments only
└─ empirical: canonical load repeats some Relation admission work
     -> measure before adding a batch/trusted-target abstraction
```

## Verdict

**KEEP CURRENT BOUNDARIES.**

The scaffold does not justify another proof field, another cross-family runtime
check, a generic Relation mutation framework, a batch admission abstraction
without measured pressure, or a user-facing outstanding-debt feature.

This is a useful negative result: the recent hardening did not leave an obvious
production semantic gap, and the remaining unanswered questions have no current
consumer that requires them to be settled.

## Stop point

Do not:

- add `DischargeId` without a correction/reversal operation that needs row
  identity;
- infer Relation absence from missing rows;
- add calendar ordering merely because prose says "later";
- promote writer-local mutation refusal into global persistence rejection;
- make Relation / Discharge proof-carrying types merely because their constructors
  are public;
- expose `relationOutstandingQuantity?` as a current household answer until
  cross-family answerability is explicitly qualified.
