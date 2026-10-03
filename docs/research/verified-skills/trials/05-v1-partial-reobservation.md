# Trial 05 — Partial re-observation from a legacy v1 anchor

Status: **paired trial complete / result: SAME**

Pinned repository revision:

```text
8a73572059bc811b6e035d1912cf0e8eef06f7b8
```

## Sealed task

Audit a persisted version-1 `CurrentQuantityAnchor` image containing one shared
reflected-root cut and two coordinates:

```text
reflected roots: [E0]

debt / jpy = -70
cash / jpy =  25
```

After a later stable Event `E1` contributes `-5` to debt and `+5` to cash,
the household re-observes only:

```text
debt / jpy = -75
```

through the ordinary `CurrentQuantityAnchor` publication path.

The trial asks whether partial re-observation preserves the older cash cut,
whether current answers remain correction-aware, and how legacy v1 persistence
upgrades on the next successful write.

The baseline and skill arm were launched from separately sealed branch prompts
before either result was disclosed to the shared evaluator. Both reported
**CLEAN** isolation.

## Candidate skill

`docs/research/verified-skills/current-quantity-anchor.md`

## Shared conclusion

Both arms independently reached the same semantic result.

The v1 image decodes as one anonymous reconciliation group:

```text
group A
  reflectedRoots = [E0]
  debt / jpy = -70
  cash / jpy =  25
```

Because `E1` is not reflected by that older cut, the ordinary current read before
new reconciliation derives:

```text
debt = -70 + (-5) = -75
cash =  25 + (+5) =  30
```

When only debt is re-observed, only debt moves to the fresh current cut:

```text
group A
  reflectedRoots = [E0]
  cash / jpy = 25

group B
  reflectedRoots = [E0, E1]
  debt / jpy = -75
```

The groups are anonymous representation factoring rather than stable household
identity. Cash was not re-observed, so its retained assertion remains `25`
against the older `[E0]` cut. It therefore remains sensitive to `E1` and still
reads as `30`.

Moving cash to the fresh `[E0, E1]` cut without re-observing it would change the
cash answer from `30` to `25`, which is the decisive falsifier for the wrong
implementation. Replacing the cash scalar with a derived `30` merely to preserve
the displayed answer would instead invent an unobserved retained quantity and a
second authority path.

A successful write after loading the legacy image uses the current v2 encoder:

```text
v1 persisted image
  -> semantic one-group Evidence
  -> partial debt re-observation
  -> two-group Evidence
  -> successful complete replacement
  -> v2 persisted image
```

No separate migration operation, stable AnchorId, GroupId, revision graph, or
historical observation record is created. The wire format changes; the household
authority model does not.

Both arms also agreed that malformed persistence, duplicate live coordinate
support, support-family overlap, and stale retained roots remain fail-closed.

## Qualification conclusion

Both arms selected the same smallest missing direct qualification.

Existing `Loam/Tests/CurrentQuantityAnchor.lean` already covers the component
laws:

- shared-cut multi-coordinate anchors;
- correction-aware current delta;
- v1 one-group compatibility;
- incremental groups;
- coordinate-local re-observation;
- unrelated-coordinate support preservation;
- duplicate coordinate refusal;
- stale-root refusal;
- support-family overlap refusal.

What is not directly pinned by one existing executable scenario is their
cross-version composition:

```text
v1 shared two-coordinate group
  + later E1 affecting both coordinates
  + re-observe debt only
  + cash remains on old cut and reads 30
  + next persistence image is v2
```

Both arms therefore judged that one focused executable regression test would be
justified if this seam is to be pinned directly.

Neither arm found a reason for a new Lean theorem, Alloy model, TLA+ model,
generic migration mechanism, stable anchor identity, or support framework.

No implementation change was performed during either audit.

## Baseline path

The clean baseline first inspected:

```text
docs/EVIDENCE_ATLAS.md
docs/SEMANTIC_BLUEPRINT.md
docs/HOUSEHOLD_OPERATING_MODE.md
```

and then followed the semantic, publication, persistence, correction-frontier,
current-balance, and focused test owners.

It encountered a few 404 path probes for older guessed source locations. Those
lookups exposed no file contents and did not cause an analytical reversal.

Recorded materially wrong analytical path / backtracking:

```text
0
```

The baseline independently found:

- the `-75 / 30` pre-reconciliation answer;
- coordinate-local split into old cash cut and fresh debt cut;
- ordinary v1-read / v2-next-write compatibility;
- no second authority;
- the same focused executable regression as the smallest additional
  qualification.

## Skill-arm path

The clean skill arm followed the candidate procedure through:

```text
Evidence Atlas / Semantic Blueprint
  -> current semantic owner
  -> publisher
  -> persistence
  -> correction frontier
  -> executable test
  -> publication research evidence
  -> existing model evidence
```

Recorded materially wrong analytical path / backtracking:

```text
0
```

The procedure made the provenance split and the concrete cash falsifier explicit,
and it kept the audit away from generic migration or revision-history machinery.

However, the baseline independently reached the same semantic answer, the same
failure boundaries, and the same qualification recommendation without candidate
skill access.

The skill arm inspected additional research/model surfaces, but tool/token/elapsed
cost was not comparable enough to treat that broader evidence set as either an
improvement or a regression.

## Paired result

```text
Result: SAME
```

There is no material difference that earns a promotion win.

Both clean arms:

- selected the correct current owners;
- preserved the unobserved cash cut;
- derived the same debt and cash current quantities;
- distinguished semantic authority from v1/v2 wire representation;
- rejected stable group/revision identity;
- identified the same decisive falsifier;
- selected the same focused executable regression test;
- rejected unnecessary new formal machinery;
- reported zero materially wrong analytical backtracks.

The skill appears non-disruptive on this held-out sibling, but Trial 05 does not
show a material improvement over the clean baseline.

## Experimental accounting

```text
Trial: 05
Date: 2026-10-03
Repository revision: 8a73572059bc811b6e035d1912cf0e8eef06f7b8
Task: Legacy v1 multi-coordinate CurrentQuantityAnchor -> partial exact
      re-observation of one coordinate -> v2 current image
Skill: CurrentQuantityAnchor change audit
Baseline outcome: CLEAN; correct scoped semantics; 0 material backtracks;
                  selected one focused executable regression as the smallest
                  additional qualification
Skill outcome: CLEAN; correct scoped semantics; 0 material backtracks;
               selected the same focused executable regression; candidate
               procedure made provenance/falsifier routing explicit
Material difference: SAME
Regression observed: None
Skill mutation: None
Protocol mutation: None; pre-run two-arm isolation succeeded
Disposition: Trialed
Promotion evidence: 0 wins counted from Trial 05
```

## Skill disposition after Trial 05

`current-quantity-anchor.md` remains **Trialed**.

Counted evidence for this skill is now:

```text
Trial 03   clean paired   BETTER    1 win
Trial 04   contaminated   UNSCORED  0 wins
Trial 05   clean paired   SAME      0 wins
```

Trial 05 supplies a valid held-out sibling trial and no semantic regression, but
the promotion rule is still unmet: the skill has only one material improvement
and only two scored comparable paired trials.

No skill mutation is justified because Trial 05 exposed no reusable failure in
the candidate procedure.
