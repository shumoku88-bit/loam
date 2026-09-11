# Observation 250 — Locus policy failure / recovery domain

## Question

After introducing a local LocusAdmission authority boundary, must current new-write
policy still share the same failure and recovery domain as retained Movement
evidence?

This observation does **not** choose a file topology. It separates two questions:

1. if only Locus policy storage is unavailable, must historical household reads
   become unavailable too?
2. when old Movement evidence is explicitly restored, must current operational
   Locus policy be rolled back with it?

## Current production pressure

Movement manifest v2 retains LocusAdmission as required family six. The selected
world loader therefore requires both household Movement evidence and the current
policy object to decode successfully.

Read-only boundaries including Actual, Balance, and Scheduled review currently use
that same selected-world loader. A policy-only object failure can therefore make
historical household reads unavailable even though their retained evidence is
otherwise intact.

Movement recovery also restores the complete historical manifest, including the
policy reference that happened to be selected with that Movement generation.
Consequently a later add-only Locus admission can be rolled back by restoring an
older Movement generation.

## Model

The first half compares availability contracts:

```text
coupled read    = Movement evidence healthy AND policy healthy
policy-free read = Movement evidence healthy
write admission = Movement evidence healthy AND policy healthy
```

The intended pressure is not to make writes permissive. Policy-only failure may
leave historical evidence readable while still refusing quantity-bearing writes.

The second half reuses the qualified add-only premise from Observation 249:

```text
historicalPolicy.approved ⊂ currentPolicy.approved
```

Two recovery topologies are compared:

```text
coupled recovery -> historical Movement + historical policy
split recovery   -> historical Movement + current policy
```

## Expected results

- `policyOnlyFailureLeavesEvidenceReadable`: SAT
  - there is a state where Movement evidence remains readable even though the
    coupled selected-world contract would fail because policy is unavailable.
- `PolicyOnlyFailureDoesNotPermitWrite`: no counterexample
  - separating read availability does not imply fail-open publication.
- `coupledRecoveryCanLoseCurrentPermission`: SAT
  - restoring an older coupled generation can remove a permission added later.
- `AddOnlyHistoricalAdmissionSurvivesSplitRecovery`: no counterexample
  - under the current add-only premise, anything admitted by the historical
    policy remains admitted by the current policy kept across Movement recovery.
- `SplitRecoveryPreservesCurrentPolicyAnswer`: no counterexample
  - split recovery leaves the current policy answer unchanged by construction.

## Interpretation boundary

A green bounded model is **not** permission to migrate storage immediately.

If qualified, it establishes only that current semantics do not force one shared
failure/recovery domain. Production still needs to compare at least these options:

1. retain manifest-backed policy but add a policy-free Movement read-evidence
   loader for read-only projections;
2. move LocusAdmission into independently selected authority/recovery;
3. keep current coupling if operational simplicity outweighs the availability and
   rollback costs.

Future Locus revocation changes the argument. Observation 249 already shows that a
stale older policy can over-authorize once removal is allowed, so any future
retirement/revocation semantics require synchronization to be re-qualified.

## Stop rule

Do not introduce a generic authority framework or migrate `loam-data` from this
observation alone. Graduate only the smallest production change that removes a
concrete unwanted failure/recovery coupling.
