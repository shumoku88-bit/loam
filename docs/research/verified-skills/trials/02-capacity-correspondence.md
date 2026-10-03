# Trial 02 — CapacityMovement / CapacityEffective correspondence

Status: **paired trial complete / result: same**

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
Baseline outcome: Clean rerun independently reached the same scoped conclusion:
                  semantic KEEP, physical topology ALREADY COMPRESSED, no new
                  formal work required, and no materially wrong analytical path.
Skill outcome: Split semantic equivalence from physical topology; found semantic
               KEEP plus already-compressed single authority.
Material difference: SAME. Both arms found the same retained meanings, the same
                     single-authority topology, the same divergence class, and
                     the same no-new-formal-work conclusion. The baseline
                     inspected more repository surfaces, but tool/token cost was
                     not comparable enough to count that as a material win.
Regression observed: None.
Skill mutation: None. Trial 02 exposes no missing reusable step in the skill.
Protocol mutation: The earlier contaminated attempt already produced the
                   pinned-file-only baseline rule; the clean rerun validates that
                   repaired control protocol.
Disposition: Trialed
Promotion evidence: 0 wins counted; this paired trial is SAME, not a material
                    skill improvement.
```

## Contaminated baseline attempt

The first fresh-session baseline attempt is retained only as an experimental
failure record.

Its source-derived conclusion independently converged on:

```text
semantic meaning:
  KEEP

physical topology:
  ALREADY COMPRESSED
```

It also found the same production-shaped divergence class: identical Capacity
movement evidence with different effective coordinates changes a time-window
answer.

However, before that source audit, two control leaks occurred:

1. commit metadata retrieval exposed diff text from the forbidden
   `docs/research/verified-skills/**` area;
2. issue-comment retrieval exposed discussion created after the pinned revision.

Because the agent saw later / forbidden text, this run cannot establish
independence even though the final reasoning was reconstructed from pinned
production source. It contributes no promotion win, no "same" result, and no
wrong-turn / cost comparison.

The clean rerun must use the revised baseline card and the pinned-evidence rule.

## Clean baseline rerun

The repaired control completed cleanly at the pinned revision.

The baseline did not read `docs/research/verified-skills/**`, commit metadata,
commit diffs, issue / PR discussion, or default-branch search snippets as
repository evidence. After the sealed task, repository claims were grounded only
in files explicitly fetched at the pinned revision.

Its conclusion independently matched the skill arm:

```text
semantic meaning:
  KEEP

physical topology:
  ALREADY COMPRESSED

new formal work:
  NOT REQUIRED
```

It also found the same decisive distinction: identical Capacity movement content
with a different effective coordinate can change a windowed / historical answer,
while effective evidence alone cannot reconstruct movement Measure, coordinates,
or signed quantities.

The baseline reported no materially wrong analytical path. One non-material
retrieval retry occurred when the sealed control task was requested at the pinned
revision even though that task file did not yet exist there; the 404 exposed no
repository evidence and the task was then read from the current sealed control
input as intended.

## Paired result

```text
Result: SAME
```

Both arms reached the same scoped boundary and selected existing evidence rather
than inventing new formal work.

The correspondence skill may have made the semantic-vs-physical split more
explicit earlier, while the clean baseline inspected a broader set of ordinary
repository surfaces before reaching the same answer. Because tool-call, token,
and elapsed-work data are not comparable, that routing difference is not counted
as a material improvement.

Therefore Trial 02 contributes:

- one clean paired trial;
- zero promotion wins;
- zero semantic regressions;
- no skill mutation.

This is evidence that the skill is at least non-disruptive on this task, not yet
evidence that it improves agent performance.

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
