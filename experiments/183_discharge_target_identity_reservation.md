# Observation 183: discharge target identity reservation

## Context

Observation 182 qualified fresh Movement discharge publication with Event-last activation. Raw `RelationDischarge` persistence intentionally retains rows whose later Event or target `RelationUnit` is missing. Missing-later-Event rows remain inert until Event authority appears.

The practical Movement writer now reserves every retained raw discharge `event : EventId` while allocating fresh Event identity. That prevents crash residue from becoming active merely because an unrelated later Movement reuses the same Event token.

The corresponding `RelationUnitId` allocator is narrower. It currently excludes only identities already owned by retained `RelationUnit` rows.

But raw discharge persistence also retains missing relation targets:

```text
RelationDischarge
  event  = existing Event E
  target = relation-1
  quantity = 200

RelationUnit relation-1
  absent
```

At this point the raw discharge cannot resolve a target and therefore contributes no admitted discharge meaning.

## Question

May a later unrelated Movement allocate `relation-1` as a fresh `RelationUnitId` merely because no retained RelationUnit currently owns that token?

If so, the new relation can accidentally satisfy the old raw discharge reference:

```text
retained raw discharge(target = relation-1)
-> target absent, row inert
-> unrelated Movement allocates relation-1
-> new RelationUnit relation-1 appears
-> old raw discharge now resolves that target
```

No new discharge decision occurred at the activation edge. Identity reuse alone changed the semantic reach of retained provenance.

## Candidate safety law

For the practical Movement allocator, a fresh `RelationUnitId` should avoid both currently owned identities and identities already mentioned as retained raw discharge targets:

```text
fresh RelationUnitId
  not in retained RelationUnit.id
  not in retained RelationDischarge.target
```

This is intentionally a narrow operational reservation law. It does not create a Relation registry, global identity service, Settlement entity, DischargeId, or generic reference framework.

## SPIN models

### Safe candidate

`183_discharge_target_identity_safe.pml`

A retained orphan discharge targets `relation-1`. The safe allocator treats that token as reserved even though no RelationUnit currently owns it, and allocates `relation-2` to the unrelated writer.

Assertions require that the newly allocated relation identity differs from the orphan target and that the old discharge never becomes active merely through allocation.

Expected: **0 errors**.

### Unsafe current-style allocator

`183_discharge_target_identity_unsafe_reuse.pml`

The allocator excludes only identities already held by RelationUnit rows. Since `relation-1` is absent from that collection, it is selected as fresh despite being named by retained discharge provenance.

The old discharge then becomes connected to the newly created unrelated RelationUnit.

Expected: **assertion violation**.

## Why this is distinct from Observation 182

Observation 182 qualified the later Event as the activation edge for one newly published discharge and therefore required retained discharge EventIds to reserve Event identity after an interrupted Event-last write.

Observation 183 asks the dual reference question on the target side:

```text
Observation 182
  raw discharge.event
  -> must not bind to an unrelated future Event

Observation 183
  raw discharge.target
  -> must not bind to an unrelated future RelationUnit
```

The two identities have different semantic roles, so this observation does not infer one rule from the other without a model. It checks the target-side pressure directly.

## Candidate consequence if qualified

The smallest practical change would be to make fresh RelationUnit allocation reserve:

```text
retained RelationUnit ids
+ retained raw RelationDischarge target ids
```

No Application admission rule needs to be weakened. Missing-target raw rows may continue to be retained syntactically, and once a genuinely intended target exists they remain subject to the existing target-local fail-closed discharge checks.

## What this would earn

Only if the SPIN matrix holds:

- retained raw discharge targets reserve `RelationUnitId` in fresh practical Movement allocation;
- an unrelated writer cannot activate orphan discharge provenance merely by identity reuse;
- missing-target discharge persistence remains permitted;
- no rollback or deletion of harmless raw orphan rows is required merely to keep future allocation safe.

## What this does not earn

Observation 183 does **not** earn:

- a `DischargeId`;
- Settlement or reimbursement ontology;
- automatic discharge matching;
- discharge correction or reversal semantics;
- RelationRevision/discharge inheritance semantics;
- a global identity registry;
- a generic dangling-reference framework;
- RelationRevision persistence or writer support;
- multi-writer guarantees;
- fsync or power-loss guarantees;
- completeness cutover;
- Effect-level discharge anchoring.

## Practical correction policy note

This observation is unrelated to ordinary same-session data-entry cleanup. A simple transcription mistake discovered while the user is still correcting the just-entered record may be repaired directly by the practical editing surface. Append-only `Correction` remains for cases where the prior recorded interpretation itself has provenance worth retaining. No same-day or same-session domain primitive is introduced here.
