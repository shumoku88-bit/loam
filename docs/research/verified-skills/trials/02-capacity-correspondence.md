# Trial 02 — CapacityMovement / CapacityEffective correspondence

Status: **skill arm complete / baseline pending**

Pinned repository revision:

```text
a2a4018168560cabb47a92f3e76c65b0feddb7c7
```

## Sealed task

Audit issue #700 candidate 4:

> Do `CapacityMovement` and `CapacityEffective` still require distinct retained
> meanings and/or distinct physical backing topology on the pinned revision?

Determine the smallest justified current boundary. Do not propose a generic
Capacity framework merely to reduce type or file count.

For the future baseline arm, use a fresh session/agent and do **not** read
`docs/research/verified-skills/**`. Inspect ordinary repository policy, source,
research owners, tests, and issue #700 only.

## Skill used

`correspondence-boundary.md`

The correspondence claim was split deliberately:

```text
semantic claim:
  Can CapacityEffective meaning be reconstructed from CapacityMovement alone?

topology claim:
  Must CapacityMovement and CapacityEffective have separate physical authority
  publication/storage units?
```

This avoided treating "one file" and "one meaning" as the same question.

## Evidence followed

Current source on the pinned revision shows:

- `CapacityEffective` attaches an independently retained `effectiveOn`
  coordinate to a `CapacityMovementId`;
- `CapacityEvidence` composes movement and effective memories while retaining
  them as two meanings and carrying only the cross-family completeness law;
- `CapacityAuthority` exposes one complete normalized `capacity.loam` image;
- `NormalizedCapacityPersistence` stores each movement and effective date in one
  document but reconstructs separate `CapacityMemory` and
  `CapacityEffectiveMemory` values after decoding.

Existing semantic audit evidence already provides the divergence witness needed
for the semantic question: two worlds can retain the same Capacity movement but
different effective coordinates, producing different time-window answers.
Therefore `CapacityEffective` is not derivable from movement algebra alone.

## Result

```text
semantic distinction:
  KEEP

physical authority split:
  ALREADY COMPRESSED

current shape:
  CapacityMovement
  + CapacityEffective
        |
        v
  CapacityEvidence (same-generation closure)
        |
        v
  one normalized capacity.loam authority
```

So issue #700 candidate 4 no longer supports merging the two meanings. It does
support the already-existing topology result: one atomic physical authority image
can carry both meanings without making effective time a field of
`CapacityMovement`.

No new Alloy/Lean/TLA+ artifact is justified by this trial because the semantic
divergence witness and current atomic topology are already qualified by existing
owners.

## Experimental accounting

```text
Trial: 02
Date: 2026-10-03
Repository revision: a2a4018168560cabb47a92f3e76c65b0feddb7c7
Task: #700 candidate 4, CapacityMovement + CapacityEffective retained meaning
Skill: Correspondence boundary audit
Baseline outcome: Pending, must be run in a fresh unexposed session
Skill outcome: Split semantic equivalence from physical topology; found semantic
               KEEP plus already-compressed single authority
Material difference: Pending baseline comparison
Regression observed: None
Skill mutation: None
Disposition: Trialed
Promotion evidence: 0 wins counted until baseline is completed
```

## Baseline comparison fields

When the fresh baseline is run at the pinned revision, record:

- whether it separates semantic equivalence from physical topology before making
  a merge/delete recommendation;
- first repository evidence surface selected;
- whether it finds the effective-coordinate divergence witness;
- whether it notices the current single normalized authority;
- materially wrong turns or over-broad formal work;
- final conclusion scope.

Do not compare token/tool-call counts unless both arms expose comparable usage
data.
