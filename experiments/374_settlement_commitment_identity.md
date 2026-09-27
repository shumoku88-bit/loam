# Observation 374 — settlement commitment replacement lineage as identity

Status: **BOUNDED IDENTITY QUESTION — test whether a separately stored logical commitment ID is earned**

Baseline:

```text
#1434  Observation 373 — plain untyped cancel collapse falsified
main   c3cf3f00af225080b8a9be62a8fc802b822c295b
```

## Trigger

Observation 373 separated:

```text
evidence-side correction / retraction
!=
physical settlement
!=
non-settlement extinguishment
```

The next unresolved production problem is identity.

Current production rows use:

```text
SettlementCommitmentId
```

and both:

```text
SettlementEffectCorrespondence.target
SettlementNettingMember.target
```

point directly to that identifier.

If commitment correction is represented by retaining a replacement row with a
new ID, existing settlement evidence still points to the old row.

One tempting repair is to introduce two identities immediately:

```text
LogicalCommitmentId
CommitmentVersionId
```

Before widening Core, this observation tests a smaller alternative.

## Candidate

Treat each retained commitment row ID as version identity and let the qualified
one-to-one replacement chain itself define logical lineage:

```text
v1 -> v2 -> v3
```

Then a settlement reference may keep its exact historical target:

```text
reference.target = v1
```

while current projection resolves it through the chain:

```text
current target = v3
```

No separately persisted logical ID is required if this relation is sufficient.

This candidate depends on the same structural premises already owned by
`ReplacementFrontier`:

```text
unique source
unique successor
acyclic
closed endpoints
```

A merge:

```text
v1 -+
    +-> v3
v2 -+
```

is therefore not admitted.

## Retraction

Observation 373 requires retraction to remain distinct from replacement.

This model therefore represents terminal retraction separately:

```text
v1 -> v2 -> v3
           retract v3
```

In that world the whole lineage has no current commitment.

The model does not claim generic `ReplacementFrontier` should absorb
retraction. It only checks whether lineage identity itself still requires an
extra stored logical ID.

## Questions

The bounded model asks whether all of these can coexist without a stored logical
identifier:

1. an old settlement reference follows a correction to the current row;
2. references recorded before and after correction coalesce on one current row;
3. multi-step correction remains unambiguous;
4. terminal retraction closes references to any historical version;
5. independent lineages remain separate;
6. merge and cycle shapes are rejected;
7. exact-target-only projection is shown insufficient.

## Important projection distinction

Two candidate read strategies are compared.

### Exact target only

```text
keep reference iff reference.target itself is current
```

This loses pre-correction settlement evidence.

### Lineage resolution

```text
reference.target
-> follow replacement chain
-> current terminal version
```

This preserves historical target provenance while projecting current meaning.

The model deliberately tests that these projections can differ.

## Expected matrix

```text
oldReferenceFollowsCorrectionWitness          SAT
mixedVersionReferencesCoalesceWitness         SAT
multiStepLineageWitness                       SAT
correctedThenRetractedWitness                 SAT
independentLineagesStayDistinctWitness        SAT
exactTargetProjectionDropsOldReferenceWitness SAT

mergeWouldAmbiguateLineage                    UNSAT
cycleWouldDestroyCurrentIdentity              UNSAT

CurrentVersionIsUnique                        UNSAT counterexample
SameLineageSharesCurrentProjection             UNSAT counterexample
ReferenceResolutionPreservesLineage            UNSAT counterexample

ExactTargetProjectionIsEnough                  SAT counterexample
```

## Interpretation if the matrix holds

A second stored logical commitment ID is **not yet earned** merely to preserve
identity across one-to-one append-only corrections.

The smaller candidate is:

```text
SettlementCommitmentId
  becomes version-capable retained row identity

SettlementCommitmentRevision
  target -> replacement

current logical lineage
  derived from revision chain

existing correspondence/member target
  remains exact historical target
  current projection resolves through commitment lineage
```

This would mirror the existing LOAM rule:

> share structural mechanics, preserve semantic authority.

The generic frontier can own chain mechanics. Settlement-specific code must own
what it means to resolve a historical target into current commitment semantics.

## What this does not prove

Even if identity works, semantic compatibility still needs a separate
observation.

Example:

```text
old commitment quantity = 10
existing settlement attribution = 6

correction says commitment quantity = 5
```

Lineage identity can say the settlement reference belongs to the same corrected
commitment.

It does **not** make `6 <= 5` valid.

Production admission should fail closed unless the dependent settlement evidence
is also corrected or otherwise re-explained.

Therefore:

```text
identity propagation
!=
semantic compatibility
```

This distinction is critical.

## Possible production consequence, not yet selected

If the bounded identity result holds, the next semantic observation should test:

> After commitment correction, should dependent correspondence/member evidence be
> automatically reinterpreted against the current commitment and rejected if
> incompatible, or must every dependent row be explicitly revised?

Only after that question should production commitment revision types be added.

## Stop condition

Do not add `LogicalCommitmentId` merely for convenience.

If replacement lineage gives unique current identity under the already-qualified
one-to-one graph, carry forward the smaller representation and test semantic
compatibility next.
