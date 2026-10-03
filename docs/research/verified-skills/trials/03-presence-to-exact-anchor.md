# Trial 03 — Presence-only support to exact current quantity

Status: **paired trial complete / result: BETTER**

Pinned repository revision:

```text
0e5f8177e26b6329d1b12d1401bc23ae5ae2546c
```

## Sealed task

Audit one current-balance transition:

```text
CurrentQuantityPresence
  known present / nonzero
  exact amount unknown

        |
        | later exact observation
        v

CurrentQuantityAnchor
  exact quantity known
  quantity may be nonzero or exactly zero
```

Determine the smallest justified retained and publication behavior after the
successful exact observation.

The clean baseline used the sealed task in
`docs/research/baseline-tasks/03-presence-to-exact-anchor.md` and did not read
`docs/research/verified-skills/**`.

## Skill used

`current-quantity-anchor.md`

The skill required the audit to name the exact current answer first, locate the
narrow current owner, trace retained provenance into the correction-aware current
image, inspect only the nearest correction and persistence neighbors, try
concrete falsifiers, and qualify the seam without adding machinery.

## Shared conclusion

Both clean arms independently reached the same semantic result.

For one `Locus × Measure` coordinate:

```text
presence-only support
        |
        | exact observation
        v
retire same-coordinate presence
        +
retain exact CurrentQuantityAnchor assertion
        +
retain its reflected-root cut
```

The old presence-only evidence does not coexist with the new exact anchor for the
same coordinate. `CurrentQuantityAnchorPublisher.refinePresenceForExact?`
removes exactly the newly exact coordinates while preserving unrelated presence
coordinates. If the last presence coordinate is removed, the empty presence
image also drops its stale reflected roots.

Exact zero remains an exact quantity. `Quantity` wraps an exact `Int`, the
anchor assertion has no nonzero restriction, and current-balance selection keeps
justified zero distinct from both amount-unknown presence and unsupported state.

The exact current answer remains a projection from retained anchor assertion,
its reflected-root cut, and correction-aware Actual evidence. A displayed or
otherwise convenient derived scalar does not become a second authority.

Current-balance composition refuses overlapping presence and exact support rather
than choosing an implicit winner.

Publication deliberately prefers temporary under-support to contradictory
support: when same-coordinate presence must be refined, the presence image is
saved before the exact anchor image. A failure between those writes can leave a
temporary support gap, but not a successful state containing both weaker
presence and stronger exact support. Retry can repair that conservative gap.

Stale reflected-root support, malformed authority, unresolved correction
evidence, and incompatible bounded-history support fail closed.

Existing focused tests and current production boundaries already qualify this
transition. No new Lean, Alloy, or TLA+ artifact is justified by the task.

## Clean baseline path

The clean baseline first inspected pinned directory and repository guidance
surfaces, then followed ordinary production and research ownership:

```text
pinned root / Loam / docs listings
  -> AGENTS.md
  -> docs/AI_WORKBENCH.md
  -> ordinary design / operating documents
  -> Evidence Atlas / Semantic Blueprint
  -> CurrentQuantityAnchor and CurrentQuantityPresence owners
  -> current-balance review
  -> correction / persistence mechanics
  -> focused tests and research evidence
```

The baseline reached the correct final result, but it had one materially wrong
analytical path that required backtracking.

It initially treated the ownership picture in
`CURRENT_QUANTITY_ANCHOR_PUBLICATION_OBLIGATION_DAG.md` G2-017, summarized as
`Actual -> CurrentQuantityAnchor`, as the current complete publication topology.
Pinned production source showed the narrower research document had become stale
for this question: the current publisher also owns/refines
`CurrentQuantityPresence` and coordinates with bounded-history support.
The baseline corrected the conclusion after returning to pinned production
source.

No semantic correction from a reviewer was required after that backtrack.

## Skill-arm path

After reading the sealed task and candidate skill at the pinned revision, the
skill arm followed:

```text
Evidence Atlas / Semantic Blueprint
  -> pinned Publisher directory
  -> CurrentQuantityAnchorPublisher
  -> CurrentQuantityAnchor / CurrentQuantityPresence
  -> CurrentBalanceReview / support routing
  -> correction frontier
  -> anchor / presence persistence
  -> writer ownership / sibling staging
  -> focused current-quantity and bounded-history tests
```

The skill arm had no materially wrong analytical path.

The difference came from procedure rather than extra checking. The instruction
to find the narrow current owner before reasoning from type names or historical
research summaries made the current publisher the organizing surface. The
neighbor step then exposed presence refinement, bounded-history interaction, and
failure topology directly from current source before older qualification notes
were used.

The falsifier step also kept the audit centered on the actual seam:

- exact zero must remain exact rather than become missing;
- same-coordinate presence and anchor must not survive together;
- unrelated presence must survive refinement;
- stale reflected roots must refuse;
- publication failure may create a support gap but not contradictory support.

## Paired result

```text
Result: BETTER
```

The final semantic conclusion was the same in both arms, so the improvement is
not a claim that the baseline was incorrect.

The material difference is narrower:

- clean baseline: one materially wrong ownership/topology interpretation required
  backtracking;
- skill arm: zero materially wrong analytical paths;
- both arms: same retained-support verdict, same exact-zero semantics, same
  authority boundary, same conservative publication-failure interpretation, and
  same no-new-formal-work conclusion;
- semantic regressions introduced by the skill: none;
- unnecessary new formal machinery: none.

This counts as one promotion win because the trial protocol explicitly treats a
materially incorrect path requiring backtracking as a comparison field, and the
candidate procedure avoided that path without widening the qualification burden.

Token, tool-call, and elapsed-work cost are not compared because the two runs did
not expose sufficiently comparable usage data.

## Earlier contaminated attempt

An earlier baseline attempt reached essentially the same source-derived semantic
conclusion, but it is excluded from the paired result.

The requested control path was first looked for on the wrong repository surface,
which led to default-branch discovery and exposed later path information. That
violated the pinned-evidence isolation rule. The run was therefore marked
contaminated even though substantive claims were later rechecked at the pinned
revision.

It contributes no Better / Same / Worse result and no promotion evidence.

The subsequent clean baseline used the branch-hosted sealed control task first
and remained pinned afterward.

## Experimental accounting

```text
Trial: 03
Date: 2026-10-03
Repository revision: 0e5f8177e26b6329d1b12d1401bc23ae5ae2546c
Task: Presence-only CurrentQuantity support -> exact CurrentQuantityAnchor,
      including exact zero and publication failure semantics
Skill: CurrentQuantityAnchor change audit
Baseline outcome: Clean; correct final conclusion; one materially wrong
                  ownership/topology path required backtracking from older
                  G2-017 research topology to current production ownership.
Skill outcome: Correct final conclusion; no materially wrong analytical path;
               current publisher and adjacent correction/persistence boundaries
               were selected before older research topology was interpreted.
Material difference: BETTER. The skill removed one material backtrack while
                     preserving the same scoped semantics and qualification.
Regression observed: None.
Skill mutation: None. No reusable missing step was exposed.
Disposition: Trialed
Promotion evidence: 1 win counted. This is one paired material improvement, but
                    it is insufficient for Qualified status.
```

## Skill disposition

`current-quantity-anchor.md` moves from **Candidate** to **Trialed**.

No skill mutation is justified. The existing instructions that produced the
observed improvement are already small and concrete.

Promotion to **Qualified** remains blocked by the repository rule requiring at
least three comparable trials, at least one held-out sibling task, at least two
material improvements, and no serious semantic regression.

The next useful evidence should therefore be a held-out sibling
`CurrentQuantityAnchor` task rather than another rewrite of the skill.
