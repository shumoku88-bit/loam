# Observation 251 — Recomposed Movement recovery

## Question

Observation 250 established that current Locus write policy does not have to share
the same recovery domain as retained Movement household evidence. What is the
smallest concrete recovery law that preserves that result without adding a new
policy authority or file?

The candidate studied here is:

```text
requested recovery candidate
  -> Event
  -> ActualValidity
  -> EventDescription
  -> RelationUnit
  -> RelationDischarge

current selected generation
  -> LocusAdmission policy

recovered selection
  = candidate five-family evidence + current policy
```

This is a selection/recomposition law only. It does not choose a new storage
format and does not make the five household evidence families independently
recoverable.

## Production pressure after #704

Production now has `loadSelectedEvidence?`, so read-only household projections no
longer require the selected LocusAdmission object. The remaining recovery path is
still coupled: selecting an older recovery manifest selects its historical policy
reference too.

That means an explicit Movement recovery can still undo a later add-only Locus
permission even though the recovered household evidence does not require that
policy rollback.

## Model

The five retained household families are modeled explicitly. A recovery selection
is valid only when every family image comes from the requested candidate while its
policy comes from the currently selected generation.

```text
for every household family F:
  recovered[F] = candidate[F]

recovered.policy = current.policy
```

The model also adds one fail-closed condition:

```text
current policy unavailable
  -> recomposed recovery unavailable
```

There is deliberately no rule that falls back to the candidate's historical
policy. Such a fallback would make recovery succeed by changing the operational
write policy precisely when the current policy cannot be validated.

## Expected results

- `recomposedRecoveryExists`: SAT
  - a selected generation can be assembled from historical five-family evidence
    plus current policy without inventing another semantic family.
- `RecomposedRecoveryRestoresEveryCandidateEvidenceFamily`: no counterexample
  - recovery cannot accidentally retain a current household family.
- `RecomposedRecoveryPreservesCurrentPolicy`: no counterexample
  - evidence recovery does not change the operational Locus policy answer.
- `MissingCurrentPolicyRefusesRecomposition`: no counterexample
  - unavailable current policy keeps recovery fail-closed rather than silently
    choosing historical policy.
- `historicalPolicyFallbackWouldMaskCurrentPolicyFailure`: SAT
  - a candidate policy can be available while current policy is unavailable, so
    fallback would materially weaken the contract.
- `CandidateAdmissionSurvivesRecomposedRecovery`: no counterexample
  - under today's add-only policy law, anything admitted by the candidate policy
    remains admitted after recomposition with current policy.
- `CurrentAdmissionAnswerPreserved`: no counterexample
  - current write-policy answers are invariant under evidence recovery.
- `coupledHistoricalRecoveryCanLoseLaterPermission`: SAT
  - exact historical-manifest recovery retains the rollback pressure found in
    Observation 250.

## Production shape suggested if qualified

A production implementation should prefer a small change inside
`MovementManifestAuthority` rather than a new authority topology:

1. decode the requested recovery manifest;
2. validate its five household evidence references;
3. decode CURRENT and validate only its selected LocusAdmission reference for the
   policy-preservation step;
4. synthesize one v2 manifest containing candidate evidence refs plus current
   policy ref;
5. stage and atomically select that recomposed manifest;
6. post-validate the complete selected world.

The requested recovery manifest remains immutable historical evidence. The newly
selected CURRENT manifest is a recomposition, so its digest is not necessarily the
requested candidate digest.

That last point means the existing recovery receipt name `selectedDigest` must be
re-audited before implementation. The caller may have requested one historical
manifest digest while the actually selected recomposed manifest has another.

## Boundaries and stop rule

Do not from this observation:

- move LocusAdmission into a standalone file;
- split the five household evidence families into independent recovery domains;
- add generic recovery machinery;
- silently recover with historical policy when current policy is unavailable;
- claim safety for future policy revocation semantics.

Revocation changes the monotonicity premise and must be re-qualified separately.
Graduate only the minimum production change needed to preserve current policy
across Movement evidence recovery.
