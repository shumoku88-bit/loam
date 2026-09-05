# Observation 175: relation retraction and absence authority

Status: bounded Alloy observation stacked on Observation 174.

Observations 172-174 narrowed the positive open-relation shape substantially:

```text
source: (EventId, EffectKey)
relation identity
opaque endpoint identity
explicit debtor / creditor
exact positive magnitude
```

Observation 169 had already established a separate completeness rule:

```text
covered source + no current positive relation evidence
-> known-none
```

while uncovered absence remains unknown.

One important correction case remained unresolved:

> What does it mean when a previously retained positive relation is later found to be wrong?

The tempting answer is to delete the relation and call the resulting absence `none`. That would collapse two distinct meanings:

```text
this particular positive relation was retracted
```

and

```text
this source Effect is known to have no open relation at all
```

Observation 175 tests whether those meanings must remain separate after Observation 173 allowed multiple independent relation units on one Effect.

## Observation-local model

This observation intentionally does not reopen endpoint, direction, or quantity representation. Each positive relation is represented only by an identity and its source Effect.

The model keeps:

```text
RelationUnit
  source Effect
```

and an append-only family-specific revision:

```text
RelationRevision
  target: RelationUnit
  replacement: optional RelationUnit
```

with the intended observation-local reading:

```text
replacement present
  -> positive relation replacement

replacement absent
  -> explicit retraction of the target positive relation
```

The target relation unit remains retained history. `replacement = none` is therefore not silent deletion. The revision itself is explicit negative authority over that relation-unit identity.

The model also keeps an exceptional source-level negative evidence form:

```text
ExplicitNoneEvidence
  source Effect
```

This means something stronger than retraction:

```text
this source Effect is positively known to have no open relation
```

It is not intended as routine baseline bookkeeping. Observation 169's qualified completeness boundary still compresses ordinary covered known-none by absence.

## Why retraction and known-none differ

Observation 173 permits multiple current relation units on one Effect.

Therefore:

```text
Effect E
  relation A
  relation B

retract A
```

must leave `B` current. Retraction is local to one relation-unit identity.

Even when the retracted unit was the last recorded positive relation, the result depends on completeness coverage.

### Covered source

```text
covered Effect
+ last current positive relation explicitly retracted
+ no current positives remain
-> known-none
```

The negative conclusion comes from two pieces together:

```text
explicit retraction authority
+ qualified completeness
```

No separate baseline `NoRelation` fact is needed.

### Uncovered / historical source

```text
legacy Effect
+ last recorded positive relation explicitly retracted
+ no current positives remain
-> unknown
```

Why not known-none? Because the retraction only says that one retained relation unit was wrong. Outside the completeness boundary, absence still cannot prove that no other relation existed.

If the historical source is positively known to have no relation at all, an exceptional source-level none assertion can establish that stronger fact:

```text
legacy Effect
+ retraction of old positive relation
+ ExplicitNoneEvidence
-> known-none
```

## Revision shape pressure

The observation also asks whether retraction necessarily needs a physically separate `Retraction` record type.

A single family-specific revision relation with an optional replacement can express both:

```text
target -> replacement
```

and

```text
target -> no replacement
```

while retaining explicit revision identity/provenance.

If the bounded matrix holds, this means the **semantic operation of retraction is earned**, but a dedicated production `RelationRetractionId` / `RelationRetraction` type is not yet forced. A future representation could use a family-specific correction/revision outcome instead.

This observation deliberately does not generalize that shape into a universal revision framework.

## Expected witnesses

1. `coveredRetractionBecomesKnownNone` — SAT
   - retracting the last current positive in a covered region lets completeness derive known-none.

2. `legacyRetractionRemainsUnknown` — SAT
   - the same retraction outside completeness yields unknown.

3. `legacyExplicitNoneAfterRetractionKnownNone` — SAT
   - exceptional explicit source-level none evidence can establish historical known-none.

4. `retractOneOfSeveralLeavesPositive` — SAT
   - retracting one relation unit does not erase another current relation on the same Effect.

5. `revisionCanReplacePositive` — SAT
   - the same revision relation can express ordinary positive-to-positive replacement.

6. `retractionPreservesHistoricalPositive` — SAT
   - the retracted positive relation remains retained provenance.

7. `explicitNoneConflictsWithCurrentPositive` — SAT
   - source-level none evidence and a current positive relation can conflict and must not be resolved by list order.

## Expected checks

8. `RetractionOfLastPositiveAlwaysKnownNone` — SAT counterexample
   - false for uncovered sources without explicit none evidence.

9. `CoveredNoCurrentMeansKnownNone` — UNSAT counterexample
   - retained completeness law.

10. `LegacyNoCurrentMeansKnownNone` — SAT counterexample
   - uncovered absence remains unknown.

11. `EveryRevisionNeedsPositiveReplacement` — SAT counterexample
   - explicit no-replacement retraction is possible.

12. `RetractingOneRelationEliminatesAllCurrentRelations` — SAT counterexample
   - multiple relation units may coexist.

13. `NoCurrentMeansNoRetainedRelationHistory` — SAT counterexample
   - current absence does not imply physical deletion of historical positives.

14. `ExplicitNoneAndCurrentPositiveNeverConflict` — SAT counterexample
   - contradictory authorities are possible and require fail-closed treatment.

## Candidate boundary

If the matrix holds, the smallest currently qualified distinction becomes:

```text
positive relation unit
  identity-bearing directed quantity evidence

relation revision
  target positive relation unit
  optional positive replacement
  no replacement = explicit retraction of that unit

source-level none authority
  separate exceptional evidence when historical/uncovered known-none
  must be asserted explicitly

covered ordinary none
  derived by qualified completeness from no current positives
```

The key result would be:

```text
retraction != known-none
```

Retraction changes which positive relation units remain current. Completeness or explicit source-level absence authority determines whether zero current positives means known-none rather than unknown.

## Production pressure

If qualified, Observation 175 earns semantic pressure for:

- append-only explicit retraction authority over a retained relation-unit identity;
- preserving the retracted positive unit as provenance;
- keeping retraction local to one relation unit;
- distinguishing uncovered unknown from source-level known-none;
- fail-closed handling when explicit none evidence conflicts with a current positive relation.

It does **not** yet earn:

- a dedicated production `Retraction` type;
- a universal optional-replacement correction abstraction;
- routine `NoRelation` facts for every covered Effect;
- silent deletion of relation facts;
- treating retraction of one relation as proof that an Effect has no others;
- deriving historical known-none from absence;
- relation persistence wire format;
- the concrete completeness cutover date;
- writer qualification changes;
- CLI/TUI or historical backfill.

## Stack

This observation is stacked on Observation 174 / PR #357 at exact head:

`a7a710ce085278b4e805d4a80f37aac7d8089626`

PR #355, #356, and #357 remain unmerged by this observation.
