# Observation 374 — settlement commitment version identity boundary

Status: **BOUNDED SEMANTIC OBSERVATION — test whether a separate logical commitment identity is forced**

Baseline:

```text
#1434  Observation 373 — plain untyped cancel collapse falsified
main   c3cf3f00af225080b8a9be62a8fc802b822c295b
```

## Trigger

Observation 373 established that commitment lifecycle cannot be represented by one untyped terminal cancel operation.

It preserved two separate semantic planes:

```text
evidence-side
  correction / retraction

real-world-side
  settlement / non-settlement extinguishment
```

One identity question remained open before production correction can be added:

> If a commitment row is corrected append-only, must LOAM introduce a stable logical commitment identity plus separate version identity, or can the existing SettlementCommitmentId become version-capable and let explicit replacement edges carry continuity?

This matters because current settlement evidence already targets SettlementCommitmentId:

```text
SettlementEffectCorrespondence.target
SettlementNettingMember.target
```

A correction design must say what happens to those retained historical targets.

## Candidate A — separate logical identity

Conceptually:

```text
LogicalCommitmentId
CommitmentVersionId

version -> logical commitment
correspondence/member -> logical commitment
current version selected separately
```

This is explicit, but adds another identity namespace and another mapping that must itself become retained authority.

## Candidate B — version-capable existing identity

Conceptually:

```text
SettlementCommitmentId = retained row/version identity

old-id --CommitmentRevision--> new-id
```

Existing dependent evidence keeps its original target:

```text
correspondence -> old-id
member         -> old-id
```

Current projection resolves that historical target through the admitted replacement frontier:

```text
old-id -> ... -> terminal current commitment id
```

The replacement edge itself is the explicit claim that the two rows are versions of the same corrected commitment evidence.

No implicit equality by payload is introduced.

## Root question

> Is a separate logical commitment identity already required for the selected current settlement queries, or can replacement-chain target resolution provide the needed continuity?

Observation 374 tests only positive correction chains.

Retraction and real-world extinguishment remain separate questions from Observation 373 and are deliberately not collapsed into this model.

## Model vocabulary

```text
CommitmentVersion
  exact positive quantity

CommitmentRevision
  target version
  replacement version

SettlementUse
  historical target version
  exact quantity

LogicalCommitment
  model-only candidate extra identity

World
  retained versions
  retained revisions
  retained settlement uses
  optional logical labels
```

The model uses one-to-one acyclic replacement chains, matching the structural contract already supplied by LOAM's generic ReplacementFrontier.

## Current target resolution

For every retained commitment version:

```text
terminal target
=
reachable replacement-chain node
that is not superseded
```

A retained settlement use is projected onto that terminal target.

So:

```text
use -> old version
old -> corrected version
```

can still contribute to the corrected current commitment without rewriting the old use row.

This is a current projection rule only. The retained use continues to name the historical version it originally targeted.

## Witness 1 — benign correction carries prior use

```text
old commitment quantity 8
  |
  +-- settlement use 3

old --revision--> corrected quantity 10
```

Direct-only targeting sees:

```text
current settled = 0
current outstanding = 10
```

Replacement-chain target resolution sees:

```text
current settled = 3
current outstanding = 7
```

The second answer preserves the meaning that the earlier settlement use belongs to the commitment being corrected.

Expected result: **SAT**.

## Witness 2 — multi-step correction

```text
v1 quantity 6
  |
  +-- use 4

v1 -> v2 quantity 8 -> v3 quantity 10
```

The old retained use reaches the unique terminal version:

```text
v1 -> v3
current outstanding = 6
```

Expected result: **SAT**.

This checks that the design is not limited to one correction hop.

## Witness 3 — downward correction fails closed

```text
old quantity 10
  |
  +-- retained use 3

old -> corrected quantity 2
```

The replacement graph itself is structurally valid.

But carrying the historical use to the corrected current version would imply:

```text
settled 3 > commitment 2
```

That must not be silently clipped, ignored, or detached.

The candidate semantic admission therefore rejects the current projection.

Expected:

```text
structurally admissible
semantic admission fails
```

Expected result: **SAT**.

This is important because automatic target chasing is safe only when followed by the existing family conservation laws.

## Witness 4 — equal payload does not create identity

Two independent commitment rows may both have quantity 5.

Without an explicit replacement edge:

```text
5      5
|      |
self   self
```

They remain separate current commitments.

Expected result: **SAT**.

So the candidate does not infer logical identity from equal payload. Continuity comes only from explicit correction authority.

## Witness 5 — logical labels are not forced by current projection

Two worlds retain exactly the same:

```text
versions
revision edges
settlement uses
```

but assign different model-only LogicalCommitment atoms.

Their selected current outstanding answer remains identical.

Expected result: **SAT**.

This tests whether the extra logical identity currently carries any information needed by the selected projection.

## Assertions

### Admitted chase never over-settles

For a semantically admitted world:

```text
chased settled <= current commitment quantity
```

Expected: **UNSAT counterexample**.

### Direct target equals chased target

This deliberately too-strong claim says a current projection may ignore replacement ancestry.

The benign correction witness refutes it.

Expected: **SAT counterexample**.

### Current projection independent of logical labels

If retained operational evidence is identical, changing model-only logical labels cannot alter the selected current outstanding projection.

Expected: **UNSAT counterexample**.

### Operational evidence determines logical labels

This deliberately too-strong claim says replacement/version evidence uniquely determines a separate logical identity relation.

The same-operational/different-label witness refutes it.

Expected: **SAT counterexample**.

## Expected Alloy matrix

```text
benignCorrectionCarriesUse                    SAT
multiStepCorrectionCarriesUse                 SAT
unsafeCarryRawWitness                         SAT
equalPayloadIndependentVersionsRemainDistinct SAT
sameOperationalDifferentLogicalLabels         SAT

AdmittedChaseNeverOverSettles                 UNSAT counterexample
DirectTargetingEqualsChasedTargeting          SAT counterexample
CurrentProjectionIndependentOfLogicalLabels   UNSAT counterexample
OperationalEvidenceDeterminesLogicalLabels    SAT counterexample
```

## Provisional judgment if the matrix holds

A separate LogicalCommitmentId is **not yet earned** merely to support append-only commitment correction and current settlement projection.

The smaller candidate is:

```text
SettlementCommitmentId
  version-capable retained row identity

SettlementCommitmentRevision
  target SettlementCommitmentId
  replacement SettlementCommitmentId

current dependent target
  resolve historical target through commitment replacement frontier
```

This reuses the repository's existing rule:

> share structural replacement mechanics, preserve family-specific semantic authority.

## Important safety condition

Target chasing must never mean:

```text
replacement wins, therefore old settlement evidence is always accepted
```

Instead:

```text
resolve historical target to current version
then
run the full current settlement admission/conservation laws
```

A correction that makes earlier settlement evidence impossible must fail closed.

This keeps correction continuity and semantic validity separate.

## What this does not decide

Observation 374 does not yet select production code.

It does not answer:

- the retained representation of commitment retraction;
- the retained representation of non-settlement extinguishment;
- whether a retracted commitment makes dependent settlement rows inert or requires explicit dependent correction;
- whether current correspondence/member rows may target superseded commitment versions directly in the wire grammar;
- whether commitment revision should be introduced before or together with extinguishment;
- historical/as-recorded query semantics across commitment corrections.

It also does not prove that a logical identity can never be useful.

A future workflow could earn one if it needs a stable identity independent of the correction chain itself.

## Stop condition

If the matrix holds:

1. do not add LogicalCommitmentId;
2. promote only the idea that current target resolution may follow explicit commitment correction ancestry;
3. retain fail-closed settlement admission after resolution;
4. isolate retraction/dependent-row behavior as the next semantic question.

That gives the production design a smaller identity surface while preserving append-only provenance.
