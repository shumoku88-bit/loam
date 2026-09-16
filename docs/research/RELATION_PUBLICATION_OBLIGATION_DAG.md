# G2-011 — Relation opening / discharge publication obligation DAG

Status: **Generation-2 audit evidence — qualification pending**

Primary instruments: **DRAKONview + production-bound obligation DAG + regression qualification**.

## Question

Record Movement can append two relation-shaped evidence families inside one newly admitted Event:

- `RelationUnit`, opening a positive relation against one keyed source Effect;
- `RelationDischarge`, discharging an already-current `RelationUnit` from the new Event.

The two families deliberately remain semantically different. The Generation-2 question is narrower:

> after sparse Effect identity canonicalization, does open-relation publication still need a separate pass proving that every retained Effect key has a resolvable relation source, in addition to proving that every newly materialized RelationUnit reaches `knownPositive`?

## Production topology

```text
raw Movement draft
        |
        v
canonicalizeDraft
  earned EffectKeys = RelationDraft.sourceEffect
        |
        v
Event.ofEffects?
  retained keys unique
        |
        +-------------------------------+
        |                               |
        v                               v
materialize RelationUnits       materialize Discharges
        |                               |
        v                               v
append to candidate world       append to candidate world
        |                               |
        v                               v
open-relation admission         discharge admission
        |                               |
        v                               v
one admitted Movement world or fail closed
```

`SparseEffectIdentity.canonicalizeEffects` erases every collector-local Effect key except a key appearing in the RelationDraft source list. Therefore a retained key in the admitted Event is not an independent input fact: it exists precisely because relation evidence requested durable addressability.

## Open-relation obligations before G2-011

`relationPublicationAdmissible` currently contains two gates:

```text
O1  every Event Effect
      anonymous -> accepted
      retained key -> currentRelationState?.isSome

O2  every newly materialized RelationUnit
      currentRelationState? = knownPositive
```

The construction path gives the dependency:

```text
retained EffectKey k
        |
        | canonicalizeDraft keeps k only if
        v
some RelationDraft.sourceEffect = k
        |
        | materializeRelationUnits preserves sourceEffect
        v
some new RelationUnit.sourceEffect = k
        |
        | O2 requires this unit's source state to be knownPositive
        v
currentRelationState?(event, k).isSome
        |
        v
O1 for k
```

Anonymous Effects already make O1 true by definition.

Therefore, on the only production entrance that calls this helper:

```text
O2  ->  O1
```

The first whole-Event source-resolution pass is derived from the stronger new-Relation positive-frontier obligation plus sparse identity canonicalization.

## Counterexample pressure

The simplification must **not** weaken these failures:

- RelationDraft names a source key absent from the Event;
- relation endpoints are not Household/external in an admitted direction;
- relation quantity is zero or negative;
- one relation exceeds the source magnitude;
- several current units exceed aggregate source coverage;
- RelationUnit identity is ambiguous.

All of these are already rejected by `currentRelationState?` / `knownPositive` admission for the newly materialized RelationUnit. Removing O1 must not bypass O2.

The existing sparse-publication regression also fixes the positive construction law: only Relation-referenced Effect keys survive canonicalization; unreferenced collector keys become anonymous.

## Discharge obligations

Discharge is **not** the same obligation and is not simplified by this finding.

For each newly materialized discharge, production asks `admittedRelationDischargesFor?` on its target and requires the exact new `(event, target, quantity)` row to appear in the admitted target-local result.

That frontier independently owns:

- target RelationUnit currentness;
- later-Event activation;
- source-Event self-discharge refusal;
- positive discharge quantity;
- per-row and aggregate target bounds;
- one active discharge Event per target;
- inert pre-Event crash residue.

These distinctions have independent tests and are not consequences of sparse Effect identity.

## Candidate production change

Delete only the derived open-relation gate:

```text
event.effects.all relationSourceResolved?
```

and retire the now-private-unused `relationSourceResolved?` helper.

Keep:

```text
newRelations.all relationSourcePositive?
```

unchanged.

No generic Relation publisher, no merged opening/discharge frontier, no new Core vocabulary, and no new persistence authority is proposed.

## Expected verdict

```text
Open relation source-resolved pass   SIMPLIFY candidate
Open relation knownPositive gate     KEEP
RelationDischarge frontier            KEEP
Opening / discharge distinction       KEEP
```

Qualification should require the production relation regressions and the broader compression / practical Movement checks to remain green.