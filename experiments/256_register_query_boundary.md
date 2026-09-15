# Observation 256 — concrete register/history query granularity

Status: **EXPERIMENT — Lean qualification pending**

Baseline:

```text
shumoku88-bit/loam
main: 7f8bc9bed426a2e80c20b19c79d298b9c626ff43
Observation 255 / PR #929 merged
```

## Trigger

Observation 254 showed that balance and Event-indexed aggregate views are lossy projections of retained history. Observation 255 then proved directly against current Lean Core that optional `EffectKey` can be erased while preserving Event identity, Effect multiplicity, and all physical `LocusId × MeasureId` quantity projections.

The next question should therefore be asked in terms of concrete household queries rather than a predesigned Register ontology:

```text
Q1  Show every physical Effect of this Event.
Q2  Show the exact Effect referenced by this RelationUnit.
Q3  Which Effect after correction is the same Effect as one before correction?
Q4  Reconstruct a useful household register/history list.
```

Observation 256 measures the minimum retained evidence for those questions.

## Existing production surfaces

The current repository already contains two important read boundaries.

`ActualReview.Record` exposes:

```text
Event
date : Option String
description
replacement : Option EventId
isCurrent
```

and retains the Event's complete Effect list. `ActualReview` is explicitly correction-aware and occurrence-date-aware. Its review ordering is derived from retained occurrence date and Event identity, not from EventMemory storage position.

`OpenRelationFrontier.relationSourceEffect?` resolves one RelationUnit source through exactly:

```text
sourceEvent : EventId
sourceEffect : EffectKey
```

No new lookup vocabulary is needed for Q2.

## O256-1 — physical Event/register rows should not require EffectKey

The Lean observation defines a research-only `RegisterRow` projected from `ActualReview.Record`:

```text
EventId
occurrence date
description
replacement EventId
currentness
List (LocusId, MeasureId, Quantity)
```

Expected theorem:

```text
registerRow (erase EffectKeys record) = registerRow record
```

This is stronger than saying balances survive. It asks whether a useful per-Event physical register row, including Effect multiplicity, remains identical.

Expected: **PROVED**.

If qualified, Q1 and the physical part of Q4 sit below the Effect identity boundary.

## O256-2 — Relation source inspection should require EffectKey

A concrete keyed source Event and RelationUnit are constructed.

Expected:

```text
relationSourceEffect? keyedMemory relation = some exactSource
```

After erasing only optional Effect identity from the source Event:

```text
relationSourceEffect? erasedMemory relation = none
```

Expected: **PROVED**.

This is the concrete query class that pays for `(EventId, EffectKey)`.

## O256-3 — EventCorrection must not be mistaken for Effect continuity

Current `EventCorrection` retains only:

```text
target : EventId
replacement : EventId
```

The observation constructs one original Event and two alternative replacement worlds.

Both replacement Events have:

- the same replacement `EventId`;
- the same cash quantity;
- the same goods quantity;
- the same two local EffectKeys;
- the same Event-level correction edge.

They differ only in which replacement Effect owns which local key.

`Aligned`:

```text
leftKey  -> cash
rightKey -> goods
```

`Swapped`:

```text
rightKey -> cash
leftKey  -> goods
```

Expected Lean witnesses:

```text
same physical cash quantity
same physical goods quantity
same EventCorrection projects in both worlds
leftKey names cash in Aligned
leftKey names goods in Swapped
```

If qualified, the answer to Q3 is:

> EventCorrection plus Event-local EffectKey reuse does not define cross-Event Effect continuity.

A future query that genuinely needs "this exact Effect became that exact Effect" would need independently retained correspondence evidence. It would not justify pretending that equal local keys already carry that meaning.

## O256-4 — what kind of register is already reconstructible?

The current `ActualReview.Record` already supports a useful correction-aware, occurrence-date-aware household register surface:

```text
Event identity
physical Effects
date
description
correction replacement/currentness
```

This does **not** imply that LOAM retains capture/arrival chronology. `EventMemory` explicitly states that list position is representation only and carries no temporal or posting-order semantics.

So Q4 splits cleanly:

```text
household review register
    reconstructible from existing evidence

exact capture/entry order
    not represented merely by EventMemory list order
```

No new chronology field is earned by this observation.

## Intended query matrix

| Query | Minimum retained evidence | EffectKey needed? | Expected verdict |
| --- | --- | --- | --- |
| Q1 Event physical Effects | Event + Effect physical data | no | closes now |
| Q2 Relation source Effect | EventId + EffectKey | yes | closes now |
| Q3 same Effect across correction | explicit cross-Event Effect correspondence | current evidence insufficient | do not infer |
| Q4 correction-aware review register | ActualReview evidence | no for physical rows | closes now |
| exact arrival/posting chronology | independently retained chronology | not currently present | do not invent |

## Stop condition

Do not add a production `Register`, global `EffectId`, mandatory Effect keys, cross-correction Effect lineage, or posting-order timestamp merely because such queries can be imagined.

The important result is the boundary itself:

```text
physical review               existing evidence
exact Relation provenance     sparse Effect identity
cross-correction Effect sameness
                              not currently retained
entry chronology              not currently retained
```

Only a real household question that needs one of the last two should earn new retained evidence.
