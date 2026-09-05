# Observation 166: Should burden / open-relation evidence attach to Event or Effect identity?

Status: bounded Alloy observation after Observations 163–165 exposed burden allocation, directional open relations, and explicit discharge provenance as separate semantic axes.

Observations 163–165 remain open and are not code dependencies of this branch. Observation 166 is based directly on current `main`.

## Existing Core pressure

LOAM already has two useful identity layers:

```text
EventId
Event.effects : List Effect
Effect.key : EffectKey
```

`EffectKey` exists specifically so later overlays can refer back to one effect without using list position or locus/measure projection as identity. Its current uniqueness law is intentionally local to one Event.

That leaves a concrete question before any new household fact is added:

> If burden allocation or an obligation-like origin must eventually be retained, is Event identity precise enough, or does the existing `(EventId, EffectKey)` coordinate already provide the smallest safe anchor?

A second question is kept separate:

> Does the later discharge occurrence itself also need Effect-level anchoring, or can an explicit `Event -> claim quantity` correspondence remain sufficient until a stronger query appears?

## Observation-local model

The Alloy model mirrors the existing identity shape:

```text
Event
Key
Effect { event, key }
```

with the law:

```text
within one Event, Effect keys are unique
```

but the same Key may occur under different Events.

Each observation-local quantity Unit has one source Effect. A World can independently retain:

```text
incurred Units
burden assignment
open directional claim Units
debtor / creditor direction
Event -> claim-unit discharge correspondence
```

No production `Claim`, `Obligation`, `Burden`, `EffectRef`, or `Settlement` type is proposed.

## Probe 1: one Event can contain mixed burden meaning

One Event contains two Effects. One source Unit is household-borne; another is outside-borne and remains expected back.

Expected: **SAT**.

An Event-wide bearer classification would erase this distinction.

## Probe 2: equal Event aggregates can hide different Effect meaning

Two worlds have the same source Event, the same two source Effects, and identical Event-level totals:

```text
household burden count = 1
outside outstanding count = 1
```

but they disagree about which Effect carries the outside-borne outstanding Unit.

Expected: **SAT**.

Therefore Event-level totals do not reconstruct Effect-specific burden / claim provenance.

## Probe 3: Event identity alone does not identify an Effect

One Event may contain more than one Effect.

Expected: **SAT**.

This is already allowed by the Practical Core and prevents `EventId` alone from serving as a precise Effect endpoint.

## Probe 4: EffectKey alone does not identify an Effect globally

Two Effects under different Events may reuse the same observation-local Key while satisfying the current per-Event uniqueness law.

Expected: **SAT**.

So promoting `EffectKey` into a globally unique identity would add a stronger law than the Core currently owns.

## Check 1: Event + Key identifies one Effect

Under the existing per-Event key uniqueness law:

```text
same Event
+ same Key
=> same Effect
```

Expected check: **UNSAT counterexample**.

This is the candidate minimum reference coordinate:

```text
(EventId, EffectKey)
```

No new globally unique `EffectId` is required merely to name an existing Effect.

## Probe 5: discharge can remain Event-scoped

A later payment Event contains multiple Effects, yet an explicit:

```text
payment Event -> claim Unit
```

correspondence still determines that the claim is discharged without selecting one payment Effect.

Expected: **SAT**.

This is a stop condition against eagerly requiring Effect-level identity on both ends of every relation.

If a later real query asks exactly *which movement Effect inside the payment Event* discharged a claim, that would create new pressure. Observation 166 does not assume that query yet.

## Check 2: claim + discharge correspondence determines outstanding

If two worlds retain the same claim Units, Events, and discharge correspondence, outstanding cannot differ.

Expected check: **UNSAT counterexample**.

This preserves the Observation 165 result that outstanding is a projection rather than stored state.

## Candidate finding

If the matrix holds, the useful boundary is asymmetric:

```text
source meaning
  burden / open-relation origin
  -> may need Effect precision
     (EventId, EffectKey)

later discharge occurrence
  -> EventId may remain sufficient
     when explicit Event -> claim quantity provenance is retained
```

This would fit LOAM's current architecture unusually well. The Core already retained Effect identity before this household pressure appeared, so the new semantics may be able to reuse an earned coordinate rather than introduce a new Cost, TransactionLine, Posting, ClaimOrigin, or global EffectId ontology.

## Why Event-wide anchoring is risky

A single household occurrence can contain multiple exact Effects. If only the Event is remembered as the semantic anchor, later queries can know the Event-level total while losing which Effect carried:

```text
household burden
outside burden
open claim provenance
```

That loss is observable whenever one Event contains mixed semantics.

## What this does not earn

Observation 166 does **not** yet earn:

- production burden-allocation evidence;
- production obligation / claim evidence;
- an `EffectRef` structure;
- a globally unique `EffectId`;
- Effect-level discharge endpoints;
- a Party / Person registry;
- stored outstanding balances;
- a universal relation framework;
- changes to Event or Effect structure;
- persistence, CLI, TUI, wire-format, or historical-data changes.

## Implementation threshold

If a real household operation finally requires retaining burden or open-relation provenance, first attempt the already-earned coordinate:

```text
EventId + EffectKey
```

before inventing a new source entity.

For discharge, retain the coarser Event endpoint until a real question cannot be answered from:

```text
Event identity
+ explicit discharge correspondence
```

This keeps granularity driven by questions rather than symmetry.
